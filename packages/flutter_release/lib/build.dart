import 'dart:io';

import 'package:dart_release/utils.dart';

/// Class which holds the necessary attributes to perform a build on various
/// platforms for the specified [buildType].
class FlutterBuild {
  final String appName;
  final String appVersion;
  String buildVersion;
  int buildNumber;
  List<String> buildArgs;
  final String releaseFolder;
  final bool installDeps;

  FlutterBuild({
    required this.appName,
    String? appVersion,
    String? buildVersion,
    int? buildNumber,
    this.buildArgs = const [],
    this.installDeps = true,
    String? releaseFolder,
  })  : appVersion = appVersion ?? 'v0.0.1',
        buildVersion =
            buildVersion ?? (appVersion ?? 'v0.0.1').replaceFirst('v', ''),
        buildNumber = buildNumber ?? 0,
        releaseFolder = releaseFolder ?? 'build/releases';

  /// Build the flutter binaries for the platform given in [buildCmd].
  Future<void> build({required String buildCmd}) async {
    await Directory(releaseFolder).create(recursive: true);
    await runProcess(
      'flutter',
      [
        'build',
        buildCmd,
        '--build-name',
        buildVersion,
        '--build-number',
        buildNumber.toString(),
        ...buildArgs,
      ],
      printCall: true,
      // Must run in shell to correctly resolve paths on Windows
      runInShell: true,
    );
  }

  /// Get the output path, where the artifact should be placed.
  String getArtifactPath({
    required String platform,
    required String extension,
    String? arch,
  }) {
    return '$releaseFolder/$appName-$appVersion-$platform${arch != null ? '-$arch' : ''}.$extension';
  }
}

/// Enumerates the types of builds.
enum BuildType {
  /// Build APK for Android.
  apk,

  /// Build app bundle for Android.
  aab,

  /// Build for Web.
  web,

  /// Build for iOS.
  ios,

  /// Build app store bundle for iOS.
  ipa,

  /// Build binary for macOS.
  macos,

  /// Build binary for Windows.
  windows,

  /// Build binary for Linux.
  linux,

  /// Build deb for Debian.
  debian,
}

/// The platform where you want your app to be build for.
abstract class PlatformBuild {
  final BuildType buildType;
  final FlutterBuild flutterBuild;

  PlatformBuild({
    required this.buildType,
    required this.flutterBuild,
  });

  /// Release the app for the given platform release type.
  /// Returns the absolute output path.
  Future<String> build();
}
