import 'dart:convert';
import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/build.dart';
import 'package:flutter_release/fastlane/fastlane.dart';
import 'package:flutter_release/publish.dart';
import 'package:flutter_release/tool_installation.dart';

/// Build the app for Android.
class AndroidPlatformBuild extends PlatformBuild {
  static final _androidDirectory = 'android';
  static final _keyStoreFile = 'keystore.jks';

  final String? keyStoreFileBase64;
  final String? keyStorePassword;
  final String? keyAlias;
  final String? keyPassword;

  AndroidPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
    this.keyStoreFileBase64,
    this.keyStorePassword,
    this.keyAlias,
    String? keyPassword,
  }) : keyPassword = keyPassword ?? keyStorePassword;

  /// Build the artifact for Android. It creates a .apk installer.
  Future<String> _buildAndroidApk() async {
    final filePath = await flutterBuild.build(buildCmd: 'apk');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'android', extension: 'apk');
    final file =
        File(filePath ?? 'build/app/outputs/flutter-apk/app-release.apk');
    await file.rename(artifactPath);
    return artifactPath;
  }

  /// Build the artifact for Android. It creates a .aab installer.
  Future<String> _buildAndroidAab() async {
    final filePath = await flutterBuild.build(buildCmd: 'appbundle');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'android', extension: 'aab');
    final file =
        File(filePath ?? 'build/app/outputs/bundle/release/app-release.aab');
    await file.rename(artifactPath);
    return artifactPath;
  }

  @override
  Future<String> build() async {
    if (keyStoreFileBase64 != null &&
        keyStorePassword != null &&
        keyAlias != null &&
        keyPassword != null) {
      // Check if key signing is prepared
      final buildGradleFile = File('$_androidDirectory/app/build.gradle');
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
    }

    final buildMetadata =
        flutterBuild.buildVersion.build.map((b) => b.toString()).join('.');
    if (int.tryParse(buildMetadata) == null) {
      if (buildMetadata.isNotEmpty) {
        print(
            'Non integer values for build metadata are not supported on Android. Omitting "$buildMetadata".');
      }
      flutterBuild.buildVersion =
          flutterBuild.buildVersion.copyWith(build: null);
    }

    return switch (buildType) {
      BuildType.aab => _buildAndroidAab(),
      BuildType.apk => _buildAndroidApk(),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for Android!'),
    };
  }
}

/// Distribute your app on the Google Play store.
class AndroidGooglePlayDistributor extends PublishDistributor {
  static final _androidDirectory = 'android';
  static final _fastlaneDirectory = '$_androidDirectory/fastlane';
  static final _fastlaneSecretsJsonFile = 'fastlane-secrets.json';

  final String fastlaneSecretsJsonBase64;

  AndroidGooglePlayDistributor({
    required super.flutterPublish,
    required super.platformBuild,
    required this.fastlaneSecretsJsonBase64,
  }) : super(distributorType: PublishDistributorType.androidGooglePlay);

  @override
  Future<void> publish() async {
    print('Install dependencies...');
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

    // Save Google play store credentials file
    final fastlaneSecretsJsonFile =
        File('$_androidDirectory/$_fastlaneSecretsJsonFile');
    await fastlaneSecretsJsonFile
        .writeAsBytes(base64.decode(fastlaneSecretsJsonBase64));

    await installFastlanePlugin('get_application_id_flavor',
        workingDirectory: _androidDirectory);

    final packageName = await runFastlaneProcess(
      [
        'run',
        'get_application_id_flavor',
        if (platformBuild.flutterBuild.flavor != null)
          'flavor:${platformBuild.flutterBuild.flavor}',
      ],
      printCall: true,
      workingDirectory: _androidDirectory,
    );
    if (packageName == null) throw Exception('Application Id not found');

    final fastlaneAppfile = '''
json_key_file("${fastlaneSecretsJsonFile.absolute.path}")
package_name("$packageName")
    ''';
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
        print(
          'Use "$versionCode" as next version code (fetched from Google Play).',
        );

        platformBuild.flutterBuild.buildVersion =
            platformBuild.flutterBuild.buildVersion.copyWith(
          build: versionCode.toString(),
        );
      }
    }

    print('Build application...');

    final outputPath = await platformBuild.build();
    print('Build artifact path: $outputPath');
    final outputFile = File(outputPath);

    if (flutterPublish.isDryRun) {
      print('Did NOT publish: Remove `--dry-run` flag for publishing.');
    } else {
      print('Publish...');
      await runProcess(
        'fastlane',
        [
          'supply',
          '--aab',
          outputFile.absolute.path,
          '--track',
          track,
          '--release_status',
          switch (flutterPublish.stage) {
            PublishStage.production => 'draft',
            PublishStage.beta => 'draft',
            PublishStage.alpha => 'draft',
            PublishStage.internal => 'completed',
            _ => 'draft',
          },
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
