import 'dart:convert';
import 'dart:io';

Future<ProcessResult> runProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool printCall = false,
}) async {
  if (printCall) {
    print('$executable ${arguments.join(' ')}');
  }
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    stdoutEncoding: stdoutEncoding,
    stderrEncoding: stderrEncoding,
  );
  if (result.exitCode != 0) throw Exception(result.stderr.toString());
  return result;
}

Future<Process> runAsyncProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  bool printCall = false,
}) async {
  if (printCall) {
    print('$executable ${arguments.join(' ')}');
  }
  final result = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
  );
  stdout.addStream(result.stdout);
  stderr.addStream(result.stderr);
  if (await result.exitCode != 0) {
    throw Exception('Process "$executable" failed. See log above.');
  }
  return result;
}

Future<ProcessResult> runBash(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool printCall = false,
}) async {
  if (printCall) {
    print('$executable ${arguments.join(' ')}');
  }
  final result = await Process.run(
    'bash',
    ['-c', '$executable ${arguments.join(' ')}'],
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    // Needed to work on windows
    runInShell: true,
    stdoutEncoding: stdoutEncoding,
    stderrEncoding: stderrEncoding,
  );
  if (result.exitCode != 0) throw Exception(result.stderr.toString());
  return result;
}
