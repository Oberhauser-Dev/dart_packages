import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/flutter_release.dart';
import 'package:flutter_release/tool_installation.dart';
import 'package:flutter_to_debian/flutter_to_debian.dart';
import 'package:path/path.dart' as path;

/// Build the app for Linux.
class LinuxPlatformBuild extends PlatformBuild {
  LinuxPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
  });

  /// Build the artifact for Linux.
  @override
  Future<String> build() async {
    final cpuArchitecture = getCpuArchitecture();

    return switch (buildType) {
      BuildType.linux => _buildLinux(arch: cpuArchitecture),
      BuildType.debian => _buildDebian(arch: cpuArchitecture),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for Linux!'),
    };
  }

  /// Build the artifact for Linux. It creates a .tar.gz archive.
  Future<String> _buildLinux({required String arch}) async {
    if (flutterBuild.installDeps) {
      await runProcess('sudo', ['apt-get', 'update'], runInShell: true);

      await ensureInstalled('clang');
      await ensureInstalled('cmake');
      await ensureInstalled('ninja-build');
      await ensureInstalled('pkg-config');
      await ensureInstalled('libgtk-3-dev');
      await ensureInstalled('liblzma-dev');
    }

    var filePath = await flutterBuild.build(buildCmd: 'linux');
    if (filePath != null) {
      filePath = path.dirname(filePath);
    }

    final artifactPath = flutterBuild.getArtifactPath(
      platform: 'linux',
      arch: arch,
      extension: 'tar.gz',
    );
    final flutterArch = getFlutterCpuArchitecture(arch);
    await runProcess(
      'tar',
      [
        '-czf',
        artifactPath,
        '-C',
        filePath ?? 'build/linux/$flutterArch/release/bundle',
        '.', // Cannot use asterisk with `-C` option, as it's evaluated by shell
      ],
    );

    return artifactPath;
  }

  /// Build the artifact for Debian. It creates a .deb installer.
  Future<String> _buildDebian({required String arch}) async {
    await _buildLinux(arch: arch);

    final flutterArch = getFlutterCpuArchitecture(arch);
    final pathToFile = await FlutterToDebian.runBuild(
        version: flutterBuild.buildVersion.canonicalizedVersion,
        arch: flutterArch);

    final artifactPath = flutterBuild.getArtifactPath(
        platform: 'linux', arch: arch, extension: 'deb');
    final file = File(pathToFile);
    await file.rename(artifactPath);
    return artifactPath;
  }
}
