import 'dart:convert';
import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/build.dart';
import 'package:flutter_release/fastlane/fastlane.dart';
import 'package:flutter_release/publish.dart';
import 'package:flutter_release/util/package_util.dart';
import 'package:flutter_release/util/tool_installation.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Android');

/// Build the app for Android.
class AndroidPlatformBuild extends PlatformBuild {
  static final _androidDirectory = 'android';
  static final _keyStoreFile = 'keystore.jks';

  final String? keyStoreFileBase64;
  final String? keyStorePassword;
  final String? keyAlias;
  final String? keyPassword;

  const AndroidPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
    this.keyStoreFileBase64,
    this.keyStorePassword,
    this.keyAlias,
    String? keyPassword,
  }) : keyPassword = keyPassword ?? keyStorePassword;

  /// Build the artifact for Android. It creates a .apk installer.
  static Future<String?> _buildAndroidApk(FlutterBuild flutterBuild) async {
    final filePath = await flutterBuild.build(buildCmd: 'apk');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'android', extension: 'apk');
    if (filePath == null) return null;
    final file = File(filePath);
    await file.rename(artifactPath);
    return artifactPath;
  }

  /// Build the artifact for Android. It creates a .aab installer.
  static Future<String?> _buildAndroidAab(FlutterBuild flutterBuild) async {
    final filePath = await flutterBuild.build(buildCmd: 'appbundle');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'android', extension: 'aab');
    if (filePath == null) return null;
    final file = File(filePath);
    await file.rename(artifactPath);
    return artifactPath;
  }

  @override
  Future<String?> build() async {
    if (keyStoreFileBase64 != null &&
        keyStorePassword != null &&
        keyAlias != null &&
        keyPassword != null) {
      _logger.fine(
          'Prepare Signing credentials in file "$_androidDirectory/key.properties"');

      // Check if key signing is configured in build.gradle
      var buildGradleFile = File('$_androidDirectory/app/build.gradle.kts');
      if (!(await buildGradleFile.exists())) {
        buildGradleFile = File('$_androidDirectory/app/build.gradle');
      }
      final buildGradleFileContents = await buildGradleFile.readAsString();
      if (!(buildGradleFileContents.contains('key.properties') &&
          buildGradleFileContents.contains('keyAlias') &&
          buildGradleFileContents.contains('keyPassword') &&
          buildGradleFileContents.contains('storeFile') &&
          buildGradleFileContents.contains('storePassword'))) {
        throw Exception(
          'Signing is not configured for Android, please follow the instructions:\n'
          'https://docs.flutter.dev/deployment/android#configure-signing-in-gradle',
        );
      }

      // Save keystore file
      final keyStoreFile = File('$_androidDirectory/$_keyStoreFile');
      await keyStoreFile.writeAsBytes(base64.decode(keyStoreFileBase64!));

      final signingKeys = '''
storePassword=$keyStorePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=${keyStoreFile.absolute.path}
    ''';
      await File('$_androidDirectory/key.properties')
          .writeAsString(signingKeys);
    } else {
      _logger.fine('Skip signing.');
    }

    FlutterBuild flutterBuild = this.flutterBuild;
    final buildMetadata =
        flutterBuild.buildVersion.build.map((b) => b.toString()).join('.');
    if (int.tryParse(buildMetadata) == null) {
      if (buildMetadata.isNotEmpty) {
        _logger.warning(
            'Non integer values for build metadata are not supported on Android. Omitting "$buildMetadata".');
      }
      flutterBuild = flutterBuild.copyWith(
          buildVersion: flutterBuild.buildVersion.copyWith(build: null));
    }

    return switch (buildType) {
      BuildType.aab => _buildAndroidAab(flutterBuild),
      BuildType.apk => _buildAndroidApk(flutterBuild),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for Android!'),
    };
  }

  AndroidPlatformBuild copyWith({
    BuildType? buildType,
    FlutterBuild? flutterBuild,
    String? keyStoreFileBase64,
    String? keyStorePassword,
    String? keyAlias,
    String? keyPassword,
  }) {
    return AndroidPlatformBuild(
      buildType: buildType ?? this.buildType,
      flutterBuild: flutterBuild ?? this.flutterBuild,
      keyStoreFileBase64: keyStoreFileBase64 ?? this.keyStoreFileBase64,
      keyStorePassword: keyStorePassword ?? this.keyStorePassword,
      keyAlias: keyAlias ?? this.keyAlias,
      keyPassword: keyPassword ?? this.keyPassword,
    );
  }
}

/// Distribute your app on the Google Play store.
class AndroidGooglePlayDistributor
    extends PublishDistributor<AndroidPlatformBuild> {
  static final _androidDirectory = 'android';
  static final _fastlaneDirectory = '$_androidDirectory/fastlane';
  static final _fastlaneSecretsJsonFile = 'fastlane-secrets.json';

  final String fastlaneSecretsJsonBase64;
  final ReleaseStatus releaseStatus;

  AndroidGooglePlayDistributor({
    required super.flutterPublish,
    required super.platformBuild,
    required this.fastlaneSecretsJsonBase64,
    this.releaseStatus = ReleaseStatus.draft,
  }) : super(distributorType: PublishDistributorType.androidGooglePlay);

  @override
  Future<void> publish() async {
    AndroidPlatformBuild platformBuild = this.platformBuild;

    _logger.info('Install dependencies...');
    if (!await isInstalled('fastlane')) {
      await ensureInstalled('ruby');
      await ensureInstalled('ruby-dev');
      await ensureInstalled(
        'fastlane',
        installCommands: ['sudo', 'gem', 'install'],
      );
    }

    await ensureInstalled(
      'bundler',
      installCommands: ['sudo', 'gem', 'install'],
    );

    /// Prepare gradlew executable:
    final configPlatformBuild = platformBuild.copyWith(
      // Only apk supports `config-only` flag
      buildType: BuildType.apk,
      flutterBuild: platformBuild.flutterBuild.copyWith(buildArgs: [
        ...platformBuild.flutterBuild.buildArgs,
        '--config-only'
      ]),
    );
    await configPlatformBuild.build();

    final getApplicationIdScript =
        await getPackageFileUri('gradle/get_android_app_id.gradle');
    // On Unix the executable path must be marked relative!
    final gradlew = Platform.isWindows ? 'gradlew.bat' : './gradlew';
    final result = await runProcess(
      gradlew,
      [
        '-q',
        '--init-script',
        getApplicationIdScript!.path,
        ':app:printApplicationId',
        if (platformBuild.flutterBuild.flavor != null)
          '-Pflavor=${platformBuild.flutterBuild.flavor}',
      ],
      workingDirectory: _androidDirectory,
      printCall: true,
    );

    final packageName = result.stdout.toString().trim();
    if (packageName.isEmpty) throw Exception('Application Id not found');
    _logger.info('Used Application Id: $packageName');

    // Save Google play store credentials file
    final fastlaneSecretsJsonFile =
        File('$_androidDirectory/$_fastlaneSecretsJsonFile');
    await fastlaneSecretsJsonFile
        .writeAsBytes(base64.decode(fastlaneSecretsJsonBase64));

    final fastlaneAppfile = '''
json_key_file("${fastlaneSecretsJsonFile.absolute.path}")
package_name("$packageName")
    ''';
    await Directory(_fastlaneDirectory).create(recursive: true);
    await File('$_fastlaneDirectory/Appfile').writeAsString(fastlaneAppfile);

    // Check if play store credentials are valid
    await runProcess(
      'fastlane',
      [
        'run',
        'validate_play_store_json_key',
        // 'json_key:${fastlaneSecretsJsonFile.absolute.path}',
      ],
      workingDirectory: _androidDirectory,
      runInShell: true,
    );

    final track = switch (flutterPublish.stage) {
      PublishStage.production => 'production',
      PublishStage.beta => 'beta',
      PublishStage.alpha => 'alpha',
      _ => 'internal',
    };

    if (platformBuild.flutterBuild.buildVersion.build.isEmpty) {
      var versionCode = await _getLastVersionCodeFromGooglePlay(track);
      if (versionCode != null) {
        // Increase versionCode by 1, if available:
        versionCode++;
        _logger.info(
          'Use "$versionCode" as next version code (fetched from Google Play).',
        );

        platformBuild = platformBuild.copyWith(
            flutterBuild: platformBuild.flutterBuild.copyWith(
                buildVersion: platformBuild.flutterBuild.buildVersion.copyWith(
          build: versionCode.toString(),
        )));
      }
    }

    _logger.info('Build application...');

    final outputPath = await platformBuild.build();
    if (outputPath == null) {
      _logger.severe('Failed to build the app for Android!');
      return;
    }

    _logger.info('Build artifact path: $outputPath');
    final outputFile = File(outputPath);

    if (flutterPublish.isDryRun) {
      _logger.info('Did NOT publish: Remove `--dry-run` flag for publishing.');
    } else {
      _logger.info('Publish...');
      await runProcess(
        'fastlane',
        [
          'supply',
          '--aab',
          outputFile.absolute.path,
          '--track',
          track,
          '--release_status',
          releaseStatus.name,
        ],
        workingDirectory: _androidDirectory,
        printCall: true,
        runInShell: true,
      );
    }
  }

  Future<int?> _getLastVersionCodeFromGooglePlay(String track) async {
    final versionCodesStr = await runFastlaneProcess(
      [
        'run',
        'google_play_track_version_codes',
        // 'package_name: app_identifier',
        'track:$track',
      ],
      workingDirectory: _androidDirectory,
    );

    // Get latest version code
    if (versionCodesStr == null) return null;
    final json = jsonDecode(versionCodesStr);
    return json[0] as int?;
  }
}

enum ReleaseStatus {
  completed,
  draft,
  halted,
  inProgress,
}
