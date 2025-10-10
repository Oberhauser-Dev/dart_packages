import 'package:dart_release/utils.dart';

export 'android.dart';
export 'ios.dart';
export 'linux.dart';
export 'macos.dart';
export 'web.dart';
export 'windows.dart';

String getFlutterCpuArchitecture(CpuArchitecture arch) {
  return switch (arch) {
    CpuArchitecture.amd64 => 'x64',
    CpuArchitecture.arm64 => 'arm64',
    _ => throw UnimplementedError(
        'Cpu architecture $arch is not supported by Flutter. '
        'See https://github.com/flutter/flutter/issues/75823 for more information.',
      ),
  };
}
