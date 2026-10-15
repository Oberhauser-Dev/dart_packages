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

  /// Whether to build the MSIX installer for the Microsoft Store.
  ///
  /// The installer is not signed, as the Microsoft Store signs it on submission.
  final bool isStore;

  /// The publisher of the MSIX installer (e.g. `CN=...`), overrides the `publisher` of the `msix_config`.
  ///
  /// Required for the Microsoft Store. When signing, it must match the subject of the certificate.
  final String? publisher;

  /// The identity name of the MSIX installer, overrides the `identity_name` of the `msix_config`.
  ///
  /// Required for the Microsoft Store.
  final String? identityName;

  /// The display name of the publisher, overrides the `publisher_display_name` of the `msix_config`.
  ///
  /// Required for the Microsoft Store.
  final String? publisherDisplayName;

  const WindowsPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
    this.certificateFileBase64,
    this.certificatePassword,
    this.isStore = false,
    this.publisher,
    this.identityName,
    this.publisherDisplayName,
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
  /// For the Microsoft Store ([isStore]), the installer is not signed at all.
  Future<String?> _buildMsix({required CpuArchitecture arch}) async {
    final filePath = await flutterBuild.build(buildCmd: 'windows');
    if (filePath == null) return null;

    final artifactPath = flutterBuild.getArtifactPath(
      platform: isStore ? 'windows-store' : 'windows',
      arch: arch,
      extension: 'msix',
    );

    File? certificateFile;
    if (isStore) {
      if (certificateFileBase64 != null) {
        _logger.warning(
            'Ignore certificate, as the Microsoft Store signs the installer.');
      }
    } else if (certificateFileBase64 != null) {
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
        if (isStore) '--store',
        if (publisher != null) ...['--publisher', publisher!],
        if (identityName != null) ...['--identity-name', identityName!],
        if (publisherDisplayName != null) ...[
          '--publisher-display-name',
          publisherDisplayName!,
        ],
        if (certificateFile != null) ...[
          '--certificate-path',
          certificateFile.path,
        ],
        if (certificateFile != null && certificatePassword != null) ...[
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
