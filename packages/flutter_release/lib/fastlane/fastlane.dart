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
  environment['FASTLANE_SKIP_UPDATE_CHECK'] = '1';
  environment['FASTLANE_DISABLE_OUTPUT_FORMAT'] = '1';
  environment['FASTLANE_HIDE_CHANGELOG'] = '1';
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

Future<void> installFastlanePlugin(
  String pluginName, {
  String? workingDirectory,
}) async {
  final gemFile = File('$workingDirectory/Gemfile');
  if (!(await gemFile.exists() &&
      (await gemFile.readAsString()).contains('plugins_path'))) {
    // Need to create a fastlane directory before working with plugins and the project.
    await Directory('$workingDirectory/fastlane').create(recursive: true);

    // Needed to support plugins
    final gemFileContent = '''
source "https://rubygems.org"
gem "fastlane"
plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
''';
    await gemFile.writeAsString(gemFileContent);
  }

  final pluginFile = File('$workingDirectory/fastlane/Pluginfile');
  if (await pluginFile.exists() &&
      (await pluginFile.readAsString())
          .contains('fastlane-plugin-$pluginName')) {
    // Plugin already installed
    return;
  }

  // Install plugin to resolve the application id
  // Must run in sudo mode because of https://github.com/rubygems/rubygems/issues/6272#issuecomment-1381683835
  await runProcess(
    'sudo',
    ['fastlane', 'add_plugin', pluginName],
    workingDirectory: workingDirectory,
    runInShell: true,
    printCall: true,
  );
}
