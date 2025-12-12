import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_release/utils/logging.dart';

import 'build.dart';
import 'deploy.dart';

const verboseFlagArg = 'verbose';

class DartReleaseCommandRunner extends CommandRunner<void> {
  DartReleaseCommandRunner()
      : super('dart_release',
            'A command line tool to build, release and deploy Dart applications.') {
    argParser.addFlag(
      verboseFlagArg,
      negatable: false,
      help: 'Noisy logging, including all shell commands executed.',
    );
    addCommand(BuildCommand());
    addCommand(DeployCommand());
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) {
    final isVerbose = topLevelResults[verboseFlagArg] as bool? ?? false;
    setupLogging(isVerbose);
    return super.runCommand(topLevelResults);
  }
}
