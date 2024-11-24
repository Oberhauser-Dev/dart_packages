import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:dart_release/utils.dart';
import 'package:flutter_release/build.dart';
import 'package:flutter_release/publish.dart';
import 'package:pub_semver/pub_semver.dart';

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
  final apiKeyJsonFile = File('$workingDirectory/ApiAuth.json');
  await apiKeyJsonFile.writeAsString(apiKeyJsonContent);

  return apiKeyJsonFile.absolute.path;
}

class IosSigningPrepare {
  static final _iosDirectory = 'ios';
  static final _fastlaneDirectory = '$_iosDirectory/fastlane';

  IosSigningPrepare();

  Future<void> prepare() async {
    await brewInstallFastlane();

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

    final apiKeyJsonPath = await generateApiKeyJson(
      apiPrivateKeyBase64: apiPrivateKeyBase64,
      apiKeyId: apiKeyId,
      apiIssuerId: apiIssuerId,
      isTeamEnterprise: isTeamEnterprise,
      workingDirectory: _iosDirectory,
    );

    Future<void> handleCertificate({required bool isDevelopment}) async {
      FileSystemEntity? privateKeyFile = entities.firstWhereOrNull(
          (file) => file.uri.pathSegments.last.endsWith('.p12'));
      FileSystemEntity? certFile = entities.firstWhereOrNull(
          (file) => file.uri.pathSegments.last.endsWith('.cer'));
      if (privateKeyFile == null || certFile == null) {
        // Download and install a new certificate
        await runProcess(
          'fastlane',
          [
            'cert', // get_certificates
            'development:${isDevelopment ? 'true' : 'false'}',
            'force:true',
            '--api_key_path',
            apiKeyJsonPath,
          ],
          workingDirectory: _iosDirectory,
        );

        final entities = await iosDir.list().toList();
        privateKeyFile = entities
            .firstWhere((file) => file.uri.pathSegments.last.endsWith('.p12'));
        certFile = entities
            .firstWhere((file) => file.uri.pathSegments.last.endsWith('.cer'));
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

      await runProcess(
        'export',
        [
          'IOS_${certType.toUpperCase()}_PRIVATE_KEY=$p12PrivateKeyBase64',
          'IOS_${certType.toUpperCase()}_CERT=$certBase64',
        ],
      );
    }

    print(
        'Enter your content provider id (team_id, exported as IOS_TEAM_ID), see https://developer.apple.com/account#MembershipDetailsCard:');
    final teamId = readInput();

    print(
        'Enter your content provider id (itc_team_id, exported as IOS_CONTENT_PROVIDER_ID), see https://appstoreconnect.apple.com/WebObjects/iTunesConnect.woa/ra/user/detail:');
    final contentProviderId = readInput();

    print(
        'Base64 Private Key for App Store connect API (api-private-key-base64, exported as IOS_API_PRIVATE_KEY):\n');
    print('$apiPrivateKeyBase64\n');

    await handleCertificate(isDevelopment: false);

    await runProcess(
      'export',
      [
        'IOS_APPLE_USERNAME=$appleUsername',
        'IOS_API_KEY_ID=$apiKeyId',
        'IOS_API_ISSUER_ID=$apiIssuerId',
        'IOS_API_PRIVATE_KEY=$apiPrivateKeyBase64',
        'IOS_CONTENT_PROVIDER_ID=$contentProviderId',
        'IOS_TEAM_ID=$teamId',
      ],
    );

    var exampleCommand = r'''
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
    await flutterBuild.build(buildCmd: 'ios');

    final artifactPath =
        flutterBuild.getArtifactPath(platform: 'ios', extension: 'zip');
    await runProcess(
      'ditto',
      [
        '-c',
        '-k',
        '--sequesterRsrc',
        '--keepParent',
        'build/ios/iphoneos/Runner.app',
        artifactPath,
      ],
    );

    return artifactPath;
  }

  /// Build the artifact for iOS App Store. It creates a .ipa bundle.
  Future<String> _buildIosIpa() async {
    // Ipa build will fail resolving the provisioning profile, this is done later by fastlane.
    await flutterBuild.build(buildCmd: 'ipa');

    // Does not create ipa at this point
    // final artifactPath =
    //     flutterBuild.getArtifactPath(platform: 'ios', extension: 'ipa');
    // final file = File('build/app/outputs/flutter-apk/app-release.apk');
    // await file.rename(artifactPath);
    return '';
  }

  /// Build the artifact for iOS. Not supported as it requires signing.
  @override
  Future<String> build() async {
    final buildMetadata =
        flutterBuild.buildVersion.build.map((b) => b.toString()).join('.');
    if (int.tryParse(buildMetadata) == null) {
      print(
          'Non integer values for build metadata are not supported on iOS. Omitting "$buildMetadata".');
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
        xcodeScheme = xcodeScheme ?? 'Runner',
        super(distributorType: PublishDistributorType.iosAppStore);

  @override
  Future<void> publish() async {
    print('Install dependencies...');

    final isProduction = flutterPublish.stage == PublishStage.production;

    await brewInstallFastlane();

    // Create tmp keychain to be able to run non interactively,
    // see https://github.com/fastlane/fastlane/blob/df12128496a9a0ad349f8cf8efe6f9288612f2cb/fastlane/lib/fastlane/actions/setup_ci.rb#L37
    final fastlaneKeychainName = 'fastlane_tmp_keychain';
    var result = await runProcess(
      'fastlane',
      [
        'run',
        'is_ci',
      ],
      workingDirectory: _iosDirectory,
    );
    final isCi = result.exitCode > 0;
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
    final iosAppInfoFile =
        File('$_iosDirectory/Runner.xcodeproj/project.pbxproj');
    final iosAppInfoFileContents = await iosAppInfoFile.readAsString();
    final regex = RegExp(r'(?<=PRODUCT_BUNDLE_IDENTIFIER)(.*)(?=;\n)');
    final match = regex.firstMatch(iosAppInfoFileContents);
    if (match == null) throw Exception('Bundle Id not found');
    var bundleId = match.group(0);
    if (bundleId == null) throw Exception('Bundle Id not found');
    bundleId =
        bundleId.replaceFirst('=', '').replaceAll('.RunnerTests', '').trim();
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
        result = await runProcess(
          'ruby',
          [
            getBundleIdFromProductRubyFile!.path,
            'Runner.xcodeproj',
            provisionBundleId,
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
    await installCertificates(isDevelopment: false);

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

    print('Build application...');

    if (!isProduction) {
      final buildVersion = platformBuild.flutterBuild.buildVersion;
      // Remove semver suffix
      // See: https://github.com/flutter/flutter/issues/27589
      if (buildVersion.isPreRelease || buildVersion.build.isNotEmpty) {
        platformBuild.flutterBuild.buildVersion =
            Version(buildVersion.major, buildVersion.minor, buildVersion.patch);
        print(
          'Build version was truncated from $buildVersion to '
          '${platformBuild.flutterBuild.buildVersion} as required by app store',
        );
      }
    }

    // Build xcarchive only
    await platformBuild.build();

    print('Build via flutter command finished. '
        'This usually fails using the provisioning profiles.\n'
        'Therefore the app is now build again with fastlane. '
        'See: https://docs.flutter.dev/deployment/cd, '
        'and https://github.com/flutter/flutter/issues/106612');

    // Build signed ipa
    // https://docs.flutter.dev/deployment/cd
    // https://github.com/flutter/flutter/issues/106612

    print('Using XCode scheme "$xcodeScheme" to build the project.');

    await runProcess(
      printCall: true,
      'fastlane',
      [
        'run',
        'build_app',
        'scheme:$xcodeScheme',
        'skip_build_archive:true',
        'archive_path:../build/ios/archive/Runner.xcarchive',
      ],
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
    if (isCi) {
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
  }
}

Future<void> brewInstallFastlane() async {
  try {
    await runProcess(
      'which',
      ['fastlane'],
    );
  } catch (_) {
    await runProcess(
      'brew',
      ['install', 'fastlane'],
    );
  }
}
