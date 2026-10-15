import 'dart:convert';
import 'dart:io';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/flutter_release.dart';
import 'package:logging/logging.dart';
import 'package:msix/msix.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('WindowsPlatformBuild');

/// Build the app for Windows.
class WindowsPlatformBuild extends PlatformBuild {
  /// The base64 encoded certificate (.pfx) to sign the MSIX installer.
  final String? certificateFileBase64;

  /// The password of the certificate.
  final String? certificatePassword;

  const WindowsPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
    this.certificateFileBase64,
    this.certificatePassword,
  });

  /// Build the artifact for Windows.
  @override
  Future<String?> build() async {
    final cpuArchitecture = getCpuArchitecture();

    return switch (buildType) {
      BuildType.windows => _buildWindows(arch: cpuArchitecture),
      BuildType.msix => _buildMsix(arch: cpuArchitecture),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for Windows!'),
    };
  }

  /// Build the artifact for Windows. It creates a .zip archive.
  Future<String?> _buildWindows({required CpuArchitecture arch}) async {
    var filePath = await flutterBuild.build(buildCmd: 'windows');
    if (filePath == null) return null;
    filePath = '${path.dirname(filePath)}\\*';

    final artifactPath = flutterBuild.getArtifactPath(
      platform: 'windows',
      arch: arch,
      extension: 'zip',
    );
    await runProcess(
      'powershell',
      [
        'Compress-Archive',
        '-Force',
        '-Path',
        filePath,
        '-DestinationPath',
        artifactPath.replaceAll('/', '\\'),
      ],
    );

    return artifactPath;
  }

  /// Build the artifact for Windows. It creates a .msix installer.
  ///
  /// The package is configured via `msix_config` in the `pubspec.yaml`, see https://pub.dev/packages/msix.
  /// Without a certificate, the installer is signed with the test certificate of the msix package.
  Future<String?> _buildMsix({required CpuArchitecture arch}) async {
    final filePath = await flutterBuild.build(buildCmd: 'windows');
    if (filePath == null) return null;

    final artifactPath = flutterBuild.getArtifactPath(
      platform: 'windows',
      arch: arch,
      extension: 'msix',
    );

    File? certificateFile;
    if (certificateFileBase64 != null) {
      _logger.fine('Prepare signing certificate');
      final tempDir = await Directory.systemTemp.createTemp('flutter_release');
      certificateFile = File(path.join(tempDir.path, 'certificate.pfx'));
      await certificateFile.writeAsBytes(base64.decode(certificateFileBase64!));
    } else {
      _logger.fine('Skip signing with own certificate.');
    }

    // MSIX only supports versions in the format `a.b.c.d`.
    final version = flutterBuild.buildVersion;
    try {
      await Msix([
        '--build-windows',
        'false',
        '--version',
        '${version.major}.${version.minor}.${version.patch}.0',
        '--architecture',
        getFlutterCpuArchitecture(arch),
        '--output-path',
        path.absolute(path.dirname(artifactPath)),
        '--output-name',
        path.basenameWithoutExtension(artifactPath),
        // Never modify the certificate store of the build machine.
        '--install-certificate',
        'false',
        if (certificateFile != null) ...[
          '--certificate-path',
          certificateFile.path,
        ],
        if (certificatePassword != null) ...[
          '--certificate-password',
          certificatePassword!,
        ],
      ]).create();
      // The msix package does not terminate its last output with a newline,
      // but the artifact path must be printed on its own line.
      stdout.writeln();
    } finally {
      await certificateFile?.parent.delete(recursive: true);
    }

    return artifactPath;
  }
}
