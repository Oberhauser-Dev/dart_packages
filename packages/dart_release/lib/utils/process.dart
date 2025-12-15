import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';

final _runProcessLogger = Logger('runProcess');

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
  _runProcessLogger.log(printCall ? Level.INFO : Level.FINE,
      '$executable ${arguments.join(' ')}');
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

  final stdOut = result.stdout;
  if (stdOut is String && stdOut.isNotEmpty) _runProcessLogger.finer(stdOut);

  final stdErr = result.stderr;
  if (stdErr is String && stdErr.isNotEmpty) _runProcessLogger.severe(stdErr);

  if (result.exitCode != 0) throw Exception(result.stderr.toString());
  return result;
}

final _runAsyncProcessLogger = Logger('runAsyncProcess');

Future<ProcessResult> runAsyncProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  bool printCall = false,
}) async {
  _runAsyncProcessLogger.log(printCall ? Level.INFO : Level.FINE,
      '$executable ${arguments.join(' ')}');
  final result = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
  );

  final List<String> stdOutLines = [];
  result.stdout.forEach((line) {
    final stdOutLine = utf8.decode(line);
    if (stdOutLine.isEmpty) return;
    stdOutLines.add(stdOutLine);
    _runAsyncProcessLogger.fine(stdOutLine);
  });

  final List<String> stdErrLines = [];
  result.stderr.forEach((line) {
    final stdErrLine = utf8.decode(line);
    if (stdErrLine.isEmpty) return;
    stdErrLines.add(stdErrLine);
    _runAsyncProcessLogger.severe(stdErrLine);
  });

  final resultCode = await result.exitCode;
  if (resultCode != 0) {
    throw Exception('Process "$executable" failed. See log above.');
  }
  return ProcessResult(
    result.pid,
    resultCode,
    stdOutLines.join('\n'),
    stdErrLines.isEmpty ? Uint8List(0) : stdErrLines.join('\n'),
  );
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
  _runAsyncProcessLogger.log(printCall ? Level.INFO : Level.FINE,
      '$executable ${arguments.join(' ')}');
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

  final stdOut = result.stdout;
  if (stdOut is String && stdOut.isNotEmpty) _runProcessLogger.finer(stdOut);

  final stdErr = result.stderr;
  if (stdErr is String && stdErr.isNotEmpty) _runProcessLogger.severe(stdErr);

  if (result.exitCode != 0) throw Exception(result.stderr.toString());
  return result;
}
