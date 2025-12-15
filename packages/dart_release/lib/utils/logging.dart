import 'dart:io';

import 'package:logging/logging.dart';

void setupLogging(bool isVerbose) {
  if (isVerbose) {
    Logger.root.level = Level.ALL;
  }
  Logger.root.onRecord.listen((record) {
    final errorStr = record.error != null ? ': ${record.error}' : '';
    final stackTraceStr =
        record.stackTrace != null ? '\n${record.stackTrace}' : '';
    final res =
        '[${record.level.name}] ${record.time}: ${record.message}$errorStr$stackTraceStr\n';
    if (record.level >= Level.SEVERE) {
      stderr.write(res);
    } else {
      stdout.write(res);
    }
  });
}
