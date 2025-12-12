import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_release/utils/logging.dart';

import 'build.dart';
import 'prepare.dart';
import 'publish.dart';

const verboseFlagArg = 'verbose';

class FlutterReleaseCommandRunner extends CommandRunner<void> {
  FlutterReleaseCommandRunner()
      : super('flutter_release',
            'A command line tool to build, release and publish Flutter applications.') {
    argParser.addFlag(
      verboseFlagArg,
      negatable: false,
      help: 'Noisy logging, including all shell commands executed.',
    );
    addCommand(BuildCommand());
    addCommand(PublishCommand());
    addCommand(PrepareCommand());
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) {
    final isVerbose = topLevelResults[verboseFlagArg] as bool? ?? false;
    setupLogging(isVerbose);
    return super.runCommand(topLevelResults);
  }
}
