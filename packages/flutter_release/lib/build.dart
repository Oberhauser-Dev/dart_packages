import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

/// Class which holds the necessary attributes to perform a build on various
/// platforms for the specified [buildType].
class FlutterBuild {
  late final String appName;
  late final String appVersion;
  late Version buildVersion;
  late int buildNumber;
  List<String> buildArgs;
  final String? mainPath;
  final String releaseFolder;
  final bool installDeps;
  final String flutterSdkPath;

  FlutterBuild({
    String? appName,
    String? appVersion,
    String? buildVersion,
    int? buildNumber,
    this.mainPath,
    this.buildArgs = const [],
    this.installDeps = true,
    String? releaseFolder,
    String? flutterSdkPath,
  })  : flutterSdkPath = flutterSdkPath ?? 'flutter',
        releaseFolder = releaseFolder ?? 'build/releases' {
    final pubspecStr = File('pubspec.yaml').readAsStringSync();
    final pubspec = Pubspec.parse(pubspecStr);
    if (appVersion == null && buildVersion == null) {
      this.buildVersion = pubspec.version ?? Version(0, 0, 1);
      this.appVersion = 'v${this.buildVersion.canonicalizedVersion}';
    } else if (buildVersion != null) {
      this.buildVersion = Version.parse(buildVersion);
      this.appVersion = 'v${this.buildVersion.canonicalizedVersion}';
    } else {
      this.buildVersion = Version.parse(appVersion!);
      this.appVersion = appVersion;
    }

    if (buildNumber == null) {
      this.buildNumber =
          this.buildVersion.build.whereType<int>().firstOrNull ?? 0;
    } else {
      this.buildNumber = buildNumber;
    }

    if (appName == null) {
      this.appName = pubspec.name;
    } else {
      this.appName = appName;
    }
  }

  /// Build the flutter binaries for the platform given in [buildCmd].
  Future<void> build({required String buildCmd}) async {
    await Directory(releaseFolder).create(recursive: true);
    await runProcess(
      flutterSdkPath,
      [
        'build',
        buildCmd,
        '--build-name',
        buildVersion.canonicalizedVersion,
        '--build-number',
        buildNumber.toString(),
        ...buildArgs,
        if (mainPath != null) ...[
          '-t',
          mainPath!,
        ]
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
