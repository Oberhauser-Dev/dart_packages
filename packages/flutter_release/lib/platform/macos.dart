import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/build.dart';

/// Build the app for MacOS.
class MacOsPlatformBuild extends PlatformBuild {
  MacOsPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
  });

  /// Build the artifact for macOS. It creates a .zip archive.
  @override
  Future<String> build() async {
    var filePath = await flutterBuild.build(buildCmd: 'macos');
    if (filePath == null) {
      // The App's build file/folder name (*.app) is not equal to [appName], so must read the actual file name.
      // Must be read out after build!
      final appNameFile = File('./macos/Flutter/ephemeral/.app_filename');
      final dotAppName = (await appNameFile.readAsString()).trim();
      filePath = 'build/macos/Build/Products/Release/$dotAppName';
    }

    final cpuArchitecture = getCpuArchitecture();
    final artifactPath = flutterBuild.getArtifactPath(
        platform: 'macos', arch: cpuArchitecture, extension: 'zip');
    await runProcess(
      'ditto',
      [
        '-c',
        '-k',
        '--sequesterRsrc',
        '--keepParent',
        filePath,
        artifactPath,
      ],
    );

    return artifactPath;
  }
}
