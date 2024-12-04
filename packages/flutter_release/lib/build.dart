import 'dart:convert';
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
  List<String> buildArgs;
  final String? mainPath;
  final String releaseFolder;
  final bool installDeps;
  final String flutterSdkPath;

  FlutterBuild({
    String? appName,
    String? appVersion,
    String? buildVersion,
    String? buildPreRelease,
    String? buildMetadata,
    this.mainPath,
    this.buildArgs = const [],
    this.installDeps = true,
    String? releaseFolder,
    String? flutterSdkPath,
  })  : flutterSdkPath = flutterSdkPath ?? 'flutter',
        releaseFolder = releaseFolder ?? 'build/releases' {
    final pubspecStr = File('pubspec.yaml').readAsStringSync();
    final pubspec = Pubspec.parse(pubspecStr);

    this.buildVersion = resolveVersion(
      pubspecVersion: pubspec.version,
      appVersion: appVersion,
      buildVersion: buildVersion,
      buildPreRelease: buildPreRelease,
      buildMetadata: buildMetadata,
    );

    if (appVersion != null) {
      this.appVersion = appVersion;
    } else {
      this.appVersion = 'v${this.buildVersion.canonicalizedVersion}';
    }

    if (appName == null) {
      this.appName = pubspec.name;
    } else {
      this.appName = appName;
    }
  }

  /// Build the flutter binaries for the platform given in [buildCmd].
  Future<String?> build({required String buildCmd}) async {
    await Directory(releaseFolder).create(recursive: true);
    var buildName =
        '${buildVersion.major}.${buildVersion.minor}.${buildVersion.patch}';
    if (buildVersion.preRelease.isNotEmpty) {
      buildName +=
          '-${buildVersion.preRelease.map((p) => p.toString()).join('.')}';
    }
    String? buildNumber;
    if (buildVersion.build.isNotEmpty) {
      buildNumber = buildVersion.build.map((p) => p.toString()).join('.');
    }
    final result = await runProcess(
      flutterSdkPath,
      [
        'build',
        buildCmd,
        '--build-name',
        buildName,
        if (buildNumber != null) ...[
          '--build-number',
          buildNumber,
        ],
        ...buildArgs,
        if (mainPath != null) ...[
          '-t',
          mainPath!,
        ],
        // Try to avoid verbose mode "-v", otherwise the result string "✓ Built xxx" cannot be found.
      ],
      printCall: true,
      // Must run in shell to correctly resolve paths on Windows
      runInShell: true,
    );
    final filePath = parseFlutterBuildResult(result.stdout);
    print('Flutter output: $filePath');
    return filePath;
  }

  static String? parseFlutterBuildResult(String output) {
    const splitter = LineSplitter();
    final lines = splitter.convert(output);

    final regExp = RegExp(r'Built\s+([^\n()]+)');
    final match = regExp.firstMatch(lines.last);
    if (match == null) {
      return null;
    }

    return match.group(1)?.trim();
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
