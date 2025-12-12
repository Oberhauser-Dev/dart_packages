import 'dart:io';

import 'package:flutter_release/cli/command.dart';

void main(List<String> arguments) async {
  exitCode = 0;
  final commandRunner = FlutterReleaseCommandRunner();
  await commandRunner.run(arguments);
}
