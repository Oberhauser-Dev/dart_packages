import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:dart_release/utils.dart';
import 'package:flutter_release/build.dart';
import 'package:flutter_release/fastlane/fastlane.dart';
import 'package:flutter_release/publish.dart';
import 'package:flutter_release/tool_installation.dart';

const apiKeyJsonFileName = 'ApiAuth.json';

Future<String> generateApiKeyJson({
  required String apiPrivateKeyBase64,
  required String apiKeyId,
  required String apiIssuerId,
  bool isTeamEnterprise = false,
  required String workingDirectory,
}) async {
  final apiKeyJsonContent = '''
{
  "key_id": "$apiKeyId",
  "issuer_id": "$apiIssuerId",
  "key": "$apiPrivateKeyBase64",
  "in_house": $isTeamEnterprise,
  "duration": 1200,
  "is_key_content_base64": true
}
  ''';
  final apiKeyJsonFile = File('$workingDirectory/$apiKeyJsonFileName');
  await apiKeyJsonFile.writeAsString(apiKeyJsonContent);

  return apiKeyJsonFile.absolute.path;
}

class IosSigningPrepare {
  static final _iosDirectory = 'ios';
  static final _fastlaneDirectory = '$_iosDirectory/fastlane';

  IosSigningPrepare();

  Future<void> prepare() async {
    await ensureInstalled('fastlane');

    if (!(await File('$_fastlaneDirectory/Appfile').exists())) {
      await runProcess(
        'fastlane',
        [
          'release',
        ],
        workingDirectory: _iosDirectory,
      );
      print('Created fastlane config in `ios` directory.');
    }

    final iosDir = Directory(_iosDirectory);
    final entities = await iosDir.list().toList();

    // Handle APIs private key file
    FileSystemEntity? apiPrivateKeyFile = entities.singleWhereOrNull((file) {
      final fileName = file.uri.pathSegments.last;
      return fileName.startsWith('AuthKey_') && fileName.endsWith('.p8');
    });

    if (apiPrivateKeyFile == null) {
      throw 'Please generate an App Store connect API Team key and copy it into the `ios` folder, see https://appstoreconnect.apple.com/access/integrations/api .';
    }

    print(
        'Enter your personal apple ID / username (apple_id, exported as IOS_APPLE_USERNAME):');
    final appleUsername = readInput();

    final apiPrivateKeyFileName = apiPrivateKeyFile.uri.pathSegments.last;
    final apiKeyId = apiPrivateKeyFileName.substring(
        'AuthKey_'.length, apiPrivateKeyFileName.indexOf('.p8'));
    print(
        'The API Key id is (api-key-id, exported as IOS_API_KEY_ID):\n$apiKeyId\n');

    print(
        'Enter the issuer id of the API key (api-issuer-id, exported as IOS_API_ISSUER_ID):');
    final apiIssuerId = readInput();

    print('Is the team enterprise y/n (team-enterprise, default:"n"):');
    final teamEnterpriseStr = readInput();
    var isTeamEnterprise = false;
    if (teamEnterpriseStr.toLowerCase().startsWith('y')) {
      isTeamEnterprise = true;
    }

    final apiPrivateKeyBase64 =
        base64Encode(await File.fromUri(apiPrivateKeyFile.uri).readAsBytes());

    final absoluteApiKeyJsonPath = await generateApiKeyJson(
      apiPrivateKeyBase64: apiPrivateKeyBase64,
      apiKeyId: apiKeyId,
      apiIssuerId: apiIssuerId,
      isTeamEnterprise: isTeamEnterprise,
      workingDirectory: _iosDirectory,
    );

    print(
        'Enter your content provider id (team_id, exported as IOS_TEAM_ID), see https://developer.apple.com/account#MembershipDetailsCard:');
    final teamId = readInput();

    print(
        'Enter your content provider id (itc_team_id, exported as IOS_CONTENT_PROVIDER_ID), see https://appstoreconnect.apple.com/WebObjects/iTunesConnect.woa/ra/user/detail:');
    final contentProviderId = readInput();

    print(
        'Base64 Private Key for App Store connect API (api-private-key-base64, exported as IOS_API_PRIVATE_KEY):\n');
    print('$apiPrivateKeyBase64\n');

    final (p12PrivateKeyBase64, certBase64) = await createCertificate(
        isDevelopment: false, apiKeyJsonPath: absoluteApiKeyJsonPath);

    print('Example command to publish the iOS app via flutter_release:\n');

    var exampleCommand = '''
export \\
    IOS_DISTRIBUTION_PRIVATE_KEY=$p12PrivateKeyBase64 \\
    IOS_DISTRIBUTION_CERT=$certBase64 \\
    IOS_APPLE_USERNAME=$appleUsername \\
    IOS_API_KEY_ID=$apiKeyId \\
    IOS_API_ISSUER_ID=$apiIssuerId \\
    IOS_API_PRIVATE_KEY=$apiPrivateKeyBase64 \\
    IOS_CONTENT_PROVIDER_ID=$contentProviderId \\
    IOS_TEAM_ID=$teamId\n\n
    ''';

    exampleCommand += r'''
flutter_release publish ios-app-store \
  --dry-run \
  --app-name my_app \ # Optional
  --app-version v0.0.1-alpha.1 \ # Optional
  --stage internal \
  --apple-username=$IOS_APPLE_USERNAME \
  --api-key-id=$IOS_API_KEY_ID \
  --api-issuer-id=$IOS_API_ISSUER_ID \
  --api-private-key-base64=$IOS_API_PRIVATE_KEY \
  --content-provider-id=$IOS_CONTENT_PROVIDER_ID \
  --team-id=$IOS_TEAM_ID \
  --distribution-private-key-base64=$IOS_DISTRIBUTION_PRIVATE_KEY \
  --distribution-cert-base64=$IOS_DISTRIBUTION_CERT''';
    if (isTeamEnterprise) {
      exampleCommand += ' --team-enterprise';
    }
    print(exampleCommand);
  }

  FileSystemEntity? _getLatestFileByExtension(
      List<FileSystemEntity> entities, String extension) {
    return entities
        .where((file) => file.uri.pathSegments.last.endsWith(extension))
        .toList()
        .sorted(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified))
        .firstOrNull;
  }

  Future<(String, String)> createCertificate({
    required bool isDevelopment,
    String? apiKeyJsonPath,
    bool force = false,
  }) async {
    final iosDir = Directory(_iosDirectory);
    final entities = await iosDir.list().toList();

    final apiKeyJsonFile =
        File(apiKeyJsonPath ?? '$_iosDirectory/$apiKeyJsonFileName');
    if (!await apiKeyJsonFile.exists()) {
      throw Exception('API Key JSON file not found at ${apiKeyJsonFile.path}.\n'
          'Please provide one e.g. by calling `prepare` or `publish`.');
    }

    FileSystemEntity? privateKeyFile =
        _getLatestFileByExtension(entities, '.p12');
    FileSystemEntity? certFile = _getLatestFileByExtension(entities, '.cer');
    if (force || privateKeyFile == null || certFile == null) {
      // Download and install a new certificate
      await runFastlaneProcess(
        [
          'cert', // get_certificates
          if (isDevelopment) '--development',
          '--force',
          '--api_key_path',
          apiKeyJsonFile.absolute.path,
        ],
        workingDirectory: _iosDirectory,
        printCall: true,
      );

      final entities = await iosDir.list().toList();
      privateKeyFile = _getLatestFileByExtension(entities, '.p12')!;
      certFile = _getLatestFileByExtension(entities, '.cer')!;
    }

    final certType = isDevelopment ? 'Development' : 'Distribution';

    final p12PrivateKeyBase64 =
        base64Encode(await File.fromUri(privateKeyFile.uri).readAsBytes());
    print(
        'Base64 Private Key for $certType (${certType.toLowerCase()}-private-key-base64, exported as IOS_${certType.toUpperCase()}_PRIVATE_KEY):\n');
    print('$p12PrivateKeyBase64\n');

    final certBase64 =
        base64Encode(await File.fromUri(certFile.uri).readAsBytes());
    print(
        'Base64 Certificate for $certType (${certType.toLowerCase()}-cert-base64, exported as IOS_${certType.toUpperCase()}_CERT):\n');
    print('$certBase64\n');

    return (p12PrivateKeyBase64, certBase64);
  }
}

/// Build the app for iOS.
class IosPlatformBuild extends PlatformBuild {
  IosPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
  });

  /// Build the artifact for iOS App Store. It creates a .ipa bundle.
  Future<String> _buildIosApp() async {
    // TODO: Signing without App Store not feasible at the moment
    final filePath = await flutterBuild.build(buildCmd: 'ios');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'ios', extension: 'zip');
    await runProcess(
      'ditto',
      [
        '-c',
        '-k',
        '--sequesterRsrc',
        '--keepParent',
        filePath ?? 'build/ios/iphoneos/Runner.app',
        artifactPath,
      ],
    );

    return artifactPath;
  }

  /// Build the artifact for iOS App Store. It creates a .ipa bundle.
  Future<String> _buildIosIpa() async {
    // Ipa build will fail resolving the provisioning profile, this is done later by fastlane.
    final filePath = await flutterBuild.build(buildCmd: 'ipa');

    // Does not create ipa at this point
    // final artifactPath =
    //     flutterBuild.getArtifactPath(platform: 'ios', extension: 'ipa');
    // final file = File('build/app/outputs/flutter-apk/app-release.apk');
    // await file.rename(artifactPath);
    return filePath ?? '';
  }

  /// Build the artifact for iOS. Not supported as it requires signing.
  @override
  Future<String> build() async {
    final buildMetadata =
        flutterBuild.buildVersion.build.map((b) => b.toString()).join('.');
    if (int.tryParse(buildMetadata) == null) {
      if (buildMetadata.isNotEmpty) {
        print(
            'Non integer values for build metadata are not supported on iOS. Omitting "$buildMetadata".');
      }
      flutterBuild.buildVersion =
          flutterBuild.buildVersion.copyWith(build: null);
    }

    return switch (buildType) {
      BuildType.ios => _buildIosApp(),
      BuildType.ipa => _buildIosIpa(),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for iOS!'),
    };
  }
}

/// Distribute your app on the iOS App store.
class IosAppStoreDistributor extends PublishDistributor {
  static final _iosDirectory = 'ios';
  static final _fastlaneDirectory = '$_iosDirectory/fastlane';

  final String appleUsername;
  final String apiKeyId;
  final String apiIssuerId;
  final String apiPrivateKeyBase64;
  final String contentProviderId;
  final String teamId;
  final bool isTeamEnterprise;
  final String distributionPrivateKeyBase64;
  final bool updateProvisioning;
  final String xcodeScheme;
  final _isDevelopment = false;

  /// This may can be removed once getting certificates is implemented in fastlane
  /// https://developer.apple.com/documentation/appstoreconnectapi/list_and_download_certificates
  final String distributionCertificateBase64;

  IosAppStoreDistributor({
    required super.flutterPublish,
    required super.platformBuild,
    required this.appleUsername,
    required this.apiKeyId,
    required this.apiIssuerId,
    required this.apiPrivateKeyBase64,
    required this.contentProviderId,
    required this.teamId,
    required bool? isTeamEnterprise,
    required this.distributionPrivateKeyBase64,
    required this.distributionCertificateBase64,
    required bool? updateProvisioning,
    String? xcodeScheme,
  })  : isTeamEnterprise = isTeamEnterprise ?? false,
        updateProvisioning = updateProvisioning ?? false,
        xcodeScheme =
            xcodeScheme ?? platformBuild.flutterBuild.flavor ?? 'Runner',
        super(distributorType: PublishDistributorType.iosAppStore);

  @override
  Future<void> publish() async {
    print('Install dependencies...');

    final isProduction = flutterPublish.stage == PublishStage.production;

    await ensureInstalled('fastlane');

    // Create tmp keychain to be able to run non interactively,
    // see https://github.com/fastlane/fastlane/blob/df12128496a9a0ad349f8cf8efe6f9288612f2cb/fastlane/lib/fastlane/actions/setup_ci.rb#L37
    final fastlaneKeychainName = 'fastlane_tmp_keychain';
    final resultStr = await runFastlaneProcess(
      [
        'run',
        'is_ci',
      ],
      workingDirectory: _iosDirectory,
    );
    final isCi = bool.parse(resultStr ?? 'false');
    if (isCi) {
      await runProcess(
        'fastlane',
        [
          'run',
          'setup_ci',
        ],
        workingDirectory: _iosDirectory,
      );
    } else {
      print('Not on CI: Create keychain "$fastlaneKeychainName" manually.');
      await runProcess(
        'fastlane',
        [
          'run',
          'create_keychain',
          'name:$fastlaneKeychainName',
          'default_keychain:true',
          'unlock:true',
          'timeout:3600',
          'lock_when_sleeps:true',
          'password:',
        ],
        workingDirectory: _iosDirectory,
      );
    }

    // Determine app bundle id
    await installFastlanePlugin('get_product_bundle_id',
        workingDirectory: _iosDirectory);

    String buildConfiguration = _isDevelopment ? 'Debug' : 'Release';
    if (xcodeScheme != 'Runner') {
      buildConfiguration += '-$xcodeScheme';
    }
    final bundleId = await runFastlaneProcess(
      [
        'run',
        'get_product_bundle_id',
        'project_filepath:Runner.xcodeproj',
        'target:Runner',
        'scheme:$xcodeScheme',
        'build_configuration:$buildConfiguration',
      ],
      printCall: true,
      workingDirectory: _iosDirectory,
    );
    if (bundleId == null) throw Exception('Bundle Id not found');

    print('Use app bundle id: $bundleId');

    final fastlaneAppfile = '''
app_identifier("$bundleId")
apple_id("$appleUsername")
itc_team_id("$contentProviderId")
team_id("$teamId")
    ''';
    await Directory(_fastlaneDirectory).create(recursive: true);
    await File('$_fastlaneDirectory/Appfile').writeAsString(fastlaneAppfile);

    final apiKeyJsonPath = await generateApiKeyJson(
      apiPrivateKeyBase64: apiPrivateKeyBase64,
      apiKeyId: apiKeyId,
      apiIssuerId: apiIssuerId,
      isTeamEnterprise: isTeamEnterprise,
      workingDirectory: _iosDirectory,
    );

    Future<void> installCertificates({bool isDevelopment = false}) async {
      final signingIdentity = isDevelopment ? 'Development' : 'Distribution';

      final codeSigningIdentity =
          'iPhone ${isDevelopment ? 'Developer' : 'Distribution'}';
      // Disable automatic code signing
      await runProcess(
        'fastlane',
        [
          'run',
          'update_code_signing_settings',
          'use_automatic_signing:false',
          'path:Runner.xcodeproj',
          'code_sign_identity:$codeSigningIdentity',
          'sdk:iphoneos*',
        ],
        workingDirectory: _iosDirectory,
      );

      final p12PrivateKeyBytes =
          base64Decode(isDevelopment ? '' : distributionPrivateKeyBase64);
      final distributionPrivateKeyFile =
          File('$_iosDirectory/$signingIdentity.p12');
      await distributionPrivateKeyFile.writeAsBytes(p12PrivateKeyBytes);

      // Import private key
      await runProcess(
        'fastlane',
        [
          'run',
          'import_certificate',
          'certificate_path:$signingIdentity.p12',
          'keychain_name:$fastlaneKeychainName',
        ],
        workingDirectory: _iosDirectory,
      );

      final certBytes =
          base64Decode(isDevelopment ? '' : distributionCertificateBase64);
      final certFile = File('$_iosDirectory/$signingIdentity.cer');
      await certFile.writeAsBytes(certBytes);

      // Import certificate
      await runProcess(
        'fastlane',
        [
          'run',
          'import_certificate',
          'certificate_path:$signingIdentity.cer',
          'keychain_name:$fastlaneKeychainName',
        ],
        workingDirectory: _iosDirectory,
      );

      // Download provisioning profile
      await runProcess(
        'fastlane',
        [
          'sigh',
          'download_all',
          if (isDevelopment) '--development',
          // get_provisioning_profile
          //'filename:$signingIdentity.mobileprovision', // only works for newly created profiles
          '--api_key_path',
          apiKeyJsonPath,
        ],
        workingDirectory: _iosDirectory,
      );

      final iosDir = Directory(_iosDirectory);
      final entities = await iosDir.list().toList();
      Iterable<FileSystemEntity> provisioningProfilePaths =
          entities.where((file) {
        final fileName = file.uri.pathSegments.last;
        return fileName.endsWith('.mobileprovision');
      });

      for (var provisioningProfilePath in provisioningProfilePaths) {
        final filePath = provisioningProfilePath.uri.pathSegments.last;
        final fileName = filePath.replaceAll('.mobileprovision', '');
        final provisionParams = fileName.split('_');
        final provisionIsDevelopment = provisionParams[0] != 'AppStore';
        if (provisionIsDevelopment != isDevelopment) continue;
        final provisionBundleId =
            provisionParams[provisionParams.length > 2 ? 2 : 1];

        // Install provisioning profile
        await runProcess(
          'fastlane',
          [
            'run',
            'install_provisioning_profile',
            'path:$filePath',
          ],
          workingDirectory: _iosDirectory,
        );

        if (!updateProvisioning) continue;

        // Update provisioning profile
        // Need to get the target (product) name of the bundle ids in order to update the provisioning profiles.
        // As there's no easy way to do this in fastlane, a script handles this.
        final getBundleIdFromProductRubyUri = Uri.parse(
            'package:flutter_release/fastlane/get_bundle_id_product.rb');
        final getBundleIdFromProductRubyFile =
            await Isolate.resolvePackageUri(getBundleIdFromProductRubyUri);
        var result = await runProcess(
          'ruby',
          [
            getBundleIdFromProductRubyFile!.path,
            'Runner.xcodeproj',
            provisionBundleId,
            buildConfiguration,
          ],
          workingDirectory: _iosDirectory,
        );
        final target = result.stdout.trim();
        print('Target "$target" has bundle id "$provisionBundleId"');

        result = await runProcess(
          'fastlane',
          [
            'run',
            'update_project_provisioning',
            'xcodeproj:Runner.xcodeproj',
            // 'build_configuration:${isDevelopment ? '/Debug|Profile/gm' : 'Release'}',
            // 'build_configuration:${isDevelopment ? 'Debug' : 'Release'}',
            'target_filter:${target.replaceAll('.', '\\.')}',
            'profile:$filePath',
            'code_signing_identity:$codeSigningIdentity',
          ],
          workingDirectory: _iosDirectory,
        );
        print('Updating provisioning profile $filePath ($provisionBundleId)');
        print(result.stdout);
      }
    }

    // await installCertificates(isDevelopment: true);
    await installCertificates(isDevelopment: _isDevelopment);

    await runProcess(
      'fastlane',
      [
        'run',
        'update_project_team',
        'path:Runner.xcodeproj',
        'teamid:$teamId',
      ],
      workingDirectory: _iosDirectory,
    );

    if (!isProduction) {
      final buildVersion = platformBuild.flutterBuild.buildVersion;
      // Remove semver preRelease suffix
      // See: https://github.com/flutter/flutter/issues/27589
      if (buildVersion.isPreRelease) {
        platformBuild.flutterBuild.buildVersion =
            platformBuild.flutterBuild.buildVersion.copyWith(pre: null);
        print(
          'Build version was truncated from $buildVersion to '
          '${platformBuild.flutterBuild.buildVersion} as required by app store',
        );
      }
    }

    if (platformBuild.flutterBuild.buildVersion.build.isEmpty) {
      var versionCode = await _getLastVersionCodeFromAppStoreConnect(
        isProduction: isProduction,
        apiKeyJsonPath: apiKeyJsonPath,
      );
      if (versionCode != null) {
        // Increase versionCode by 1, if available:
        versionCode++;
        print(
          'Use "$versionCode" as next version code (fetched from App Store Connect).',
        );

        platformBuild.flutterBuild.buildVersion =
            platformBuild.flutterBuild.buildVersion.copyWith(
          build: versionCode.toString(),
        );
      }
    }

    print('Build application...');

    // Build xcarchive only
    final outputPath = await platformBuild.build();
    print('Build artifact path: $outputPath');

    print('Build via flutter command finished. '
        'This usually fails using the provisioning profiles.\n'
        'Therefore the app is now build again with fastlane. '
        'See: https://docs.flutter.dev/deployment/cd, '
        'and https://github.com/flutter/flutter/issues/106612');

    // Build signed ipa
    // https://docs.flutter.dev/deployment/cd
    // https://github.com/flutter/flutter/issues/106612

    print('Using XCode scheme "$xcodeScheme" to build the project.');

    await runAsyncProcess(
      printCall: true,
      'fastlane',
      [
        'run',
        'build_app',
        'scheme:$xcodeScheme',
        'skip_build_archive:true',
        'archive_path:../build/ios/archive/Runner.xcarchive',
      ],
      environment: {'FASTLANE_XCODEBUILD_SETTINGS_RETRIES': '15'},
      workingDirectory: _iosDirectory,
    );

    if (flutterPublish.isDryRun) {
      print('Did NOT publish: Remove `--dry-run` flag for publishing.');
    } else {
      print('Publish...');
      if (!isProduction) {
        await runProcess(
          'fastlane',
          // upload_to_testflight
          ['pilot', 'upload', '--api_key_path', apiKeyJsonPath],
          workingDirectory: _iosDirectory,
          printCall: true,
        );
      } else {
        await runProcess(
          'fastlane',
          ['upload_to_app_store', '--api_key_path', apiKeyJsonPath],
          workingDirectory: _iosDirectory,
          printCall: true,
        );
      }
    }
    // Clean up
    await runProcess(
      'fastlane',
      [
        'run',
        'delete_keychain',
        'name:$fastlaneKeychainName',
      ],
      workingDirectory: _iosDirectory,
    );
  }

  Future<int?> _getLastVersionCodeFromAppStoreConnect({
    required bool isProduction,
    required String apiKeyJsonPath,
  }) async {
    final versionCodesStr = await runFastlaneProcess(
      [
        'run',
        'app_store_build_number',
        'live:$isProduction',
        'api_key_path:$apiKeyJsonPath',
      ],
      workingDirectory: _iosDirectory,
    );

    // Get latest version code
    if (versionCodesStr == null) return null;
    return int.tryParse(versionCodesStr);
  }
}
