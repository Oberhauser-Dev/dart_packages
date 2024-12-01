import 'package:dart_release/utils.dart';
import 'package:flutter_release/flutter_release.dart';
import 'package:path/path.dart' as path;

/// Build the app for Windows.
class WindowsPlatformBuild extends PlatformBuild {
  WindowsPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
  });

  /// Build the artifact for Windows. It creates a .zip archive.
  @override
  Future<String> build() async {
    var filePath = await flutterBuild.build(buildCmd: 'windows');
    final cpuArchitecture = getCpuArchitecture();
    final flutterArch = getFlutterCpuArchitecture(cpuArchitecture);

    if (filePath != null) {
      filePath = '${path.dirname(filePath)}\\*';
    } else {
      filePath = 'build\\windows\\$flutterArch\\runner\\Release\\*';
    }

    final artifactPath = flutterBuild.getArtifactPath(
      platform: 'windows',
      arch: cpuArchitecture,
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
}
