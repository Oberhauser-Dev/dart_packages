import 'dart:io';

/// Get current CPU architecture
/// See: https://github.com/dart-lang/sdk/blob/661d4a6aed561d6d76ee7b7a90e26e6315ccd8aa/pkg/smith/lib/configuration.dart#L785
CpuArchitecture getCpuArchitecture() {
  String cpu;
  if (Platform.isWindows) {
    cpu = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'unknown';
  } else {
    var info = Process.runSync('uname', ['-m']);
    cpu = info.stdout.toString().replaceAll('\n', '').trim();
  }
  switch (cpu.toLowerCase()) {
    case 'x86' || 'i386' || '386' || 'i686' || 'x32' || 'amd32' || 'ia32':
      return CpuArchitecture.amd32;
    case 'x64' || 'x86_64' || 'x86-64' || 'amd64':
      return CpuArchitecture.amd64;
    case 'arm' || 'armv7l':
      return CpuArchitecture.arm32;
    case 'arm64' || 'arm64e' || 'aarch64':
      return CpuArchitecture.arm64;
    case "riscv32":
      return CpuArchitecture.riscv32;
    case "riscv64":
      return CpuArchitecture.riscv64;
  }
  throw UnimplementedError('Cpu architecture $cpu is not supported by Dart.');
}

enum CpuArchitecture {
  amd32,
  amd64,
  arm32,
  arm64,
  riscv32,
  riscv64,
}
