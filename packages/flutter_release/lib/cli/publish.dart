import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_release/cli/build.dart';
import 'package:dart_release/dart_release.dart';
import 'package:flutter_release/flutter_release.dart';

import 'build.dart';

// Publish
const commandPublish = 'publish';
const argPublishStage = 'stage';
const argDryRun = 'dry-run';
const argReleaseStatus = 'release-status';

// Publish: Google Play
const commandAndroidGooglePlay = 'android-google-play';
const argFastlaneSecretsJsonBase64 = 'fastlane-secrets-json-base64';

// Publish: iOS App Store
const commandIosAppStore = 'ios-app-store';
const argIosAppleUsername = 'apple-username';
const argIosApiKeyId = 'api-key-id';
const argIosApiIssuerId = 'api-issuer-id';
const argIosApiPrivateKeyBase64 = 'api-private-key-base64';
const argIosContentProviderId = 'content-provider-id';
const argIosTeamId = 'team-id';
const argIosTeamEnterprise = 'team-enterprise';
const argIosDistributionPrivateKeyBase64 = 'distribution-private-key-base64';
const argIosDistributionCertificateBase64 = 'distribution-cert-base64';
const argIosUpdateProvisioning = 'update-provisioning';
const argXcodeScheme = 'xcode-scheme';

// Publish: Web Server
const commandWebServer = 'web-server';
const argWebServerHost = 'host';
const argWebServerPath = 'path';
const argWebServerPort = 'ssh-port';
const argWebSshUser = 'ssh-user';
const argWebSshPrivateKeyBase64 = 'ssh-private-key-base64';
const argWebSshPrivateKeyPassphrase = 'ssh-private-key-passphrase';

// Publish: Microsoft Store
const commandWindowsMsStore = 'windows-ms-store';
const argMsStoreTenantId = 'tenant-id';
const argMsStoreClientId = 'client-id';
const argMsStoreClientSecret = 'client-secret';
const argMsStoreSellerId = 'seller-id';
const argMsStoreProductId = 'product-id';
const argMsStoreFlightId = 'flight-id';
const argMsStoreRolloutPercentage = 'rollout-percentage';
const argMsStorePackage = 'package';

class PublishCommand extends Command {
  @override
  final name = commandPublish;
  @override
  final description = 'Publish the app with the specified distributor.';

  PublishCommand() {
    addSubcommand(PublishAndroidGooglePlayCommand());
    addSubcommand(PublishIosAppStoreCommand());
    addSubcommand(PublishWindowsMsStoreCommand());
    addSubcommand(PublishWebServerCommand());
  }
}

abstract class CommonPublishCommand extends Command {
  CommonPublishCommand() {
    addFlutterReleaseBuildArgs(argParser);
    argParser.addOption(argPublishStage);
    argParser.addFlag(argDryRun);
  }

  PublishDistributor getPublishDistributor({
    required ArgResults results,
    required FlutterPublish flutterPublish,
    required FlutterBuild flutterBuild,
  });

  @override
  FutureOr? run() async {
    final results = argResults;
    if (results == null) throw ArgumentError('No arguments provided');

    final stageStr = results[argPublishStage] as String?;
    final isDryRun = results[argDryRun] as bool?;

    final flutterPublish = FlutterPublish(
      isDryRun: isDryRun,
      stage: stageStr == null ? null : PublishStage.values.byName(stageStr),
    );

    final flutterBuild = FlutterBuild.parse(
      appName: results[argAppName] as String?,
      appVersion: results[argAppVersion] as String?,
      buildVersion: results[argBuildVersion] as String?,
      buildMetadata: results[argBuildMetadata] as String?,
      buildPreRelease: results[argBuildPreRelease] as String?,
      buildArgs: results[argBuildArg] as List<String>,
      mainPath: results[argMainPath] as String?,
      flavor: results[argFlavor] as String?,
      flutterSdkPath: results[argFlutterSdkPath] as String?,
    );

    final publishDistributor = getPublishDistributor(
      results: results,
      flutterPublish: flutterPublish,
      flutterBuild: flutterBuild,
    );
    await publishDistributor.publish();
    if (isDryRun ?? false) {
      stdout.writeln(
          'Dry run for ${publishDistributor.distributorType.name} was successful!');
    } else {
      stdout.writeln(
          'Publishing to ${publishDistributor.distributorType.name} was successful!');
    }
  }
}

class PublishAndroidGooglePlayCommand extends CommonPublishCommand {
  @override
  final name = commandAndroidGooglePlay;
  @override
  final description = 'Publish the app on Google Play.';

  PublishAndroidGooglePlayCommand() {
    AndroidBuildCommand.addAndroidBuildArgs(argParser);
    argParser.addOption(argFastlaneSecretsJsonBase64, mandatory: true);
    argParser.addOption(argReleaseStatus);
  }

  @override
  PublishDistributor getPublishDistributor({
    required ArgResults results,
    required FlutterPublish flutterPublish,
    required FlutterBuild flutterBuild,
  }) {
    final platformBuild = AndroidPlatformBuild(
      buildType: BuildType.aab,
      flutterBuild: flutterBuild,
      keyStoreFileBase64: results[argKeyStoreFileBase64] as String?,
      keyStorePassword: results[argKeyStorePassword] as String?,
      keyAlias: results[argKeyAlias] as String?,
      keyPassword: results[argKeyPassword] as String?,
    );
    final releaseStatusStr = results[argReleaseStatus] as String?;

    return AndroidGooglePlayDistributor(
      flutterPublish: flutterPublish,
      platformBuild: platformBuild,
      fastlaneSecretsJsonBase64:
          results[argFastlaneSecretsJsonBase64] as String,
      releaseStatus: releaseStatusStr == null
          ? ReleaseStatus.draft
          : ReleaseStatus.values.byName(releaseStatusStr),
    );
  }
}

class PublishIosAppStoreCommand extends CommonPublishCommand {
  @override
  final name = commandIosAppStore;
  @override
  final description = 'Publish the app on iOS App Store.';

  PublishIosAppStoreCommand() {
    argParser
      ..addOption(argIosAppleUsername, mandatory: true, help: 'aka `apple_id`')
      ..addOption(argIosApiKeyId, mandatory: true)
      ..addOption(argIosApiIssuerId, mandatory: true)
      ..addOption(argIosApiPrivateKeyBase64, mandatory: true)
      ..addOption(
        argIosContentProviderId,
        mandatory: true,
        help: 'aka `itc_team_id`, see: '
            'https://appstoreconnect.apple.com/WebObjects/iTunesConnect.woa/ra/user/detail',
      )
      ..addOption(argIosTeamId, mandatory: true, help: 'aka `team_id`')
      ..addFlag(argIosTeamEnterprise, help: 'aka `in_house`')
      ..addOption(argIosDistributionPrivateKeyBase64, mandatory: true)
      ..addOption(argIosDistributionCertificateBase64, mandatory: true)
      ..addOption(argIosUpdateProvisioning,
          help:
              'fetch all provisioning profiles and try to match them with the bundle ids')
      ..addOption(argXcodeScheme,
          help: 'Scheme in XCode to build the project (useful for flavors). '
              'By default it will use the "Runner" scheme.');
  }

  @override
  PublishDistributor getPublishDistributor({
    required ArgResults results,
    required FlutterPublish flutterPublish,
    required FlutterBuild flutterBuild,
  }) {
    final platformBuild = IosPlatformBuild(
      buildType: BuildType.ipa,
      flutterBuild: flutterBuild,
    );

    return IosAppStoreDistributor(
      flutterPublish: flutterPublish,
      platformBuild: platformBuild,
      appleUsername: results[argIosAppleUsername] as String,
      apiKeyId: results[argIosApiKeyId] as String,
      apiIssuerId: results[argIosApiIssuerId] as String,
      apiPrivateKeyBase64: results[argIosApiPrivateKeyBase64] as String,
      contentProviderId: results[argIosContentProviderId] as String,
      teamId: results[argIosTeamId] as String,
      isTeamEnterprise: results[argIosTeamEnterprise] as bool?,
      distributionPrivateKeyBase64:
          results[argIosDistributionPrivateKeyBase64] as String,
      distributionCertificateBase64:
          results[argIosDistributionCertificateBase64] as String,
      updateProvisioning:
          bool.parse(results[argIosUpdateProvisioning] ?? 'false'),
      xcodeScheme: results[argXcodeScheme] as String?,
    );
  }
}

class PublishWindowsMsStoreCommand extends CommonPublishCommand {
  @override
  final name = commandWindowsMsStore;
  @override
  final description = 'Publish the app on Microsoft Store.';

  PublishWindowsMsStoreCommand() {
    argParser
      ..addOption(argMsStoreTenantId, mandatory: true)
      ..addOption(argMsStoreClientId, mandatory: true)
      ..addOption(
        argMsStoreClientSecret,
        mandatory: true,
        help: 'The key of the Microsoft Entra application in Partner Center.',
      )
      ..addOption(argMsStoreSellerId, mandatory: true)
      ..addOption(
        argMsStoreProductId,
        mandatory: true,
        help:
            'The Store id (e.g. 9N...), see Partner Center > Product identity.',
      )
      ..addMultiOption(
        argMsStorePackage,
        help: 'The MSIX packages (e.g. one per architecture) built via '
            '`build msix --store`. Multiple packages are published as bundle. '
            'Takes the packages of the app version in the release folder by default.',
      )
      ..addOption(
        argMsStoreFlightId,
        help: 'The package flight, publishes to the public by default.',
      )
      ..addOption(
        argMsStoreRolloutPercentage,
        help: 'The rollout percentage of the package (0-100).',
      )
      ..addOption(
        argReleaseStatus,
        allowed: WindowsReleaseStatus.values.map((s) => s.name),
        defaultsTo: WindowsReleaseStatus.draft.name,
        help: 'The status of the submission, '
            '"${WindowsReleaseStatus.completed.name}" submits it for certification.',
      );
  }

  @override
  PublishDistributor getPublishDistributor({
    required ArgResults results,
    required FlutterPublish flutterPublish,
    required FlutterBuild flutterBuild,
  }) {
    // Not built, only used for the app version.
    final platformBuild = WindowsPlatformBuild(
      buildType: BuildType.msix,
      flutterBuild: flutterBuild,
      isStore: true,
    );
    final rolloutPercentageStr =
        results[argMsStoreRolloutPercentage] as String?;

    return WindowsMsStoreDistributor(
      flutterPublish: flutterPublish,
      platformBuild: platformBuild,
      tenantId: results[argMsStoreTenantId] as String,
      clientId: results[argMsStoreClientId] as String,
      clientSecret: results[argMsStoreClientSecret] as String,
      sellerId: results[argMsStoreSellerId] as String,
      productId: results[argMsStoreProductId] as String,
      packages: results[argMsStorePackage] as List<String>,
      flightId: results[argMsStoreFlightId] as String?,
      packageRolloutPercentage: rolloutPercentageStr == null
          ? null
          : double.parse(rolloutPercentageStr),
      releaseStatus: WindowsReleaseStatus.values
          .byName(results[argReleaseStatus] as String),
    );
  }
}

class PublishWebServerCommand extends CommonPublishCommand {
  @override
  final name = commandWebServer;
  @override
  final description = 'Publish the app on a Web server.';

  PublishWebServerCommand() {
    argParser
      ..addOption(argWebServerHost, mandatory: true)
      ..addOption(argWebServerPort)
      ..addOption(argWebServerPath, mandatory: true)
      ..addOption(argWebSshUser, mandatory: true)
      ..addOption(argWebSshPrivateKeyBase64, mandatory: true);
    // ..addOption(argWebSshPrivateKeyPassphrase); Passphrase currently not supported
  }

  @override
  PublishDistributor getPublishDistributor({
    required ArgResults results,
    required FlutterPublish flutterPublish,
    required FlutterBuild flutterBuild,
  }) {
    final platformBuild = WebPlatformBuild(
      buildType: BuildType.web,
      flutterBuild: flutterBuild,
    );

    return WebServerDistributor(
      flutterPublish: flutterPublish,
      platformBuild: platformBuild,
      webServerPath: results[argWebServerPath] as String,
      serverConnection: WebServerConnection(
        host: results[argWebServerHost] as String,
        port: int.tryParse(results[argWebServerPort] ?? ''),
        sshUser: results[argWebSshUser] as String,
        sshPrivateKeyBase64: results[argWebSshPrivateKeyBase64] as String,
        // sshPrivateKeyPassphrase: results[argWebSshPrivateKeyPassphrase] as String?,
      ),
    );
  }
}
