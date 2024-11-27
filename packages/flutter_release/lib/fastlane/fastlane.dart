import 'dart:convert';
import 'dart:io';

import 'package:dart_release/utils/process.dart';

String? parseFastlaneResult(String output) {
  const splitter = LineSplitter();
  final lines = splitter.convert(output);
  final resultSearchStr = 'Result:';
  final indexOfResult = lines.last.indexOf(resultSearchStr);
  if (indexOfResult < 0) return null;
  return lines.last.substring(indexOfResult + resultSearchStr.length).trim();
}

Future<String?> runFastlaneProcess(
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  bool printCall = false,
}) async {
  environment ??= {};
  // https://docs.fastlane.tools/advanced/fastlane/
  environment['FASTLANE_DISABLE_COLORS'] = '1';
  environment['FASTLANE_SKIP_ACTION_SUMMARY'] = '1';
  final result = await runProcess(
    'fastlane',
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    stderrEncoding: stderrEncoding,
    stdoutEncoding: stdoutEncoding,
    printCall: printCall,
  );
  return parseFastlaneResult(result.stdout);
}
