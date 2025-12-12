import 'dart:io';

import 'package:dart_release/cli/command.dart';

void main(List<String> arguments) async {
  exitCode = 0;
  final commandRunner = DartReleaseCommandRunner();
  await commandRunner.run(arguments);
}
