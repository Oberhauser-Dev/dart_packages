import 'dart:io';

import 'package:dart_release/utils/process.dart';

Future<void> ensureInstalled(
  String processName, {
  List<String>? installCommands,
}) async {
  if (!await isInstalled(processName)) {
    installCommands ??= _defaultInstallCommands;
    installCommands.add(processName);
    final executable = installCommands.first;
    await runProcess(
      printCall: true,
      executable,
      installCommands.length > 1 ? installCommands.sublist(1) : [],
      runInShell: true,
    );
  }
}

Future<bool> isInstalled(String processName) async {
  try {
    await runProcess(
      'which',
      [processName],
      runInShell: true,
    );
    return true;
  } catch (_) {
    return false;
  }
}

List<String> get _defaultInstallCommands {
  if (Platform.isMacOS) {
    return ['brew', 'install'];
  }
  if (Platform.isLinux) {
    return ['sudo', 'apt-get', 'install', '-y'];
  }
  throw UnimplementedError(
      'Windows is not supported providing a default package manager yet.');
}
