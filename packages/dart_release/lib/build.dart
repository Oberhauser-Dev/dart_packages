import 'dart:io';

import 'package:dart_release/utils/platform.dart';
import 'package:dart_release/utils/process.dart';
import 'package:dart_release/utils/version.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

/// Class which holds the necessary attributes to perform a build on various
/// platforms for the specified [buildType].
class DartBuild {
  late final String appName;
  late final String appVersion;
  final String mainPath;
  List<String> buildArgs;
  final String releaseFolder;
  late final String buildFolder;
  late final String executableName;
  late final CpuArchitecture _arch;
  final List<String> includedPaths;
  final String dartSdkPath;

  DartBuild({
    String? appName,
    required this.mainPath,
    String? appVersion,
    String? buildPreRelease,
    String? buildMetadata,
    this.buildArgs = const [],
    String? releaseFolder,
    List<String>? includedPaths,
    String? buildFolder,
    String? executableName,
    String? dartSdkPath,
  })  : dartSdkPath = dartSdkPath ?? 'dart',
        releaseFolder = releaseFolder ?? 'build/releases',
        includedPaths = includedPaths ?? [] {
    _arch = getCpuArchitecture();
    final pubspecStr = File('pubspec.yaml').readAsStringSync();
    final pubspec = Pubspec.parse(pubspecStr);

    final buildVersion = resolveVersion(
      pubspecVersion: pubspec.version,
      appVersion: appVersion,
      buildVersion: null,
      buildPreRelease: buildPreRelease,
      buildMetadata: buildMetadata,
    );

    if (appVersion != null) {
      this.appVersion = appVersion;
    } else {
      this.appVersion = 'v${buildVersion.canonicalizedVersion}';
    }

    if (appName == null) {
      this.appName = pubspec.name;
    } else {
      this.appName = appName;
    }
    if (executableName == null) {
      String execName = this.appName.replaceAll('_', '-');
      if (Platform.isWindows) {
        execName += '.exe';
      }
      this.executableName = execName;
    } else {
      this.executableName = executableName;
    }
    if (buildFolder == null) {
      this.buildFolder = 'bin';
    } else {
      this.buildFolder = buildFolder;
    }
  }

  /// Build the dart binaries for the platform given in [buildCmd].
  Future<String> build() async {
    await Directory(buildFolder).create(recursive: true);
    final executable = '$buildFolder/$executableName';
    await runProcess(
      dartSdkPath,
      [
        'compile',
        'exe',
        mainPath,
        '-o',
        executable,
        ...buildArgs,
      ],
      printCall: true,
      // Must run in shell to correctly resolve paths on Windows
      runInShell: true,
    );
    return executable;
  }

  Future<String> bundle() async {
    await Directory(releaseFolder).create(recursive: true);
    final executablePath = await build();
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return await _bundleBash(executablePath: executablePath);
    } else {
      throw UnsupportedError(
          'Platform ${Platform.operatingSystem} is not supported yet! We are open for contributions!');
    }
  }

  Future<String> _bundleBash({required String executablePath}) async {
    await runBash(
      'chmod',
      [
        '+x',
        executablePath,
      ],
      printCall: true,
    );

    final artifactPath = getArtifactPath(extension: 'tar.gz');
    await runBash(
      'tar',
      [
        '-czf',
        artifactPath,
        executablePath,
        ...includedPaths,
      ],
      printCall: true,
    );
    return artifactPath;
  }

  /// Get the output path, where the artifact should be placed.
  String getArtifactPath({required String extension}) {
    final packageName =
        '$appName-$appVersion-${Platform.operatingSystem}-${_arch.name}';
    return '$releaseFolder/$packageName.$extension';
  }
}
