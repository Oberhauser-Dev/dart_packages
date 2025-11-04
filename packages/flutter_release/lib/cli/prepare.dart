import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:flutter_release/flutter_release.dart';

const commandPrepare = 'prepare';

class PrepareCommand extends Command {
  @override
  final name = commandPrepare;
  @override
  final description = 'Prepare the app locally.';

  PrepareCommand() {
    addSubcommand(IosPrepareCommand());
  }
}

class IosPrepareCommand extends Command {
  @override
  String name = 'ios';
  @override
  String description = 'Prepare the ios app on the local machine.';

  IosPrepareCommand() {
    addSubcommand(IosPrepareCreateCertificateCommand());
  }

  @override
  FutureOr? run() async {
    final results = argResults;
    if (results == null) throw ArgumentError('No arguments provided');

    await IosSigningPrepare().prepare();
  }
}

const argDevelopment = 'development';

class IosPrepareCreateCertificateCommand extends Command {
  @override
  String name = 'cert';
  @override
  String description = 'Prepare the ios certificate on the local machine.';

  IosPrepareCreateCertificateCommand() {
    argParser.addFlag(argDevelopment);
  }

  @override
  FutureOr? run() async {
    final results = argResults;
    if (results == null) throw ArgumentError('No arguments provided');

    final isDevelopmentCertificate =
        (results[argDevelopment] as bool?) ?? false;

    final (p12PrivateKeyBase64, certBase64) = await IosSigningPrepare()
        .createCertificate(
            isDevelopment: isDevelopmentCertificate, force: true);

    print('Example command to set the environment variables:\n');

    final certType = isDevelopmentCertificate ? 'DEVELOPMENT' : 'DISTRIBUTION';
    final exampleCommand = '''
export \\
    IOS_${certType}_PRIVATE_KEY=$p12PrivateKeyBase64 \\
    IOS_${certType}_CERT=$certBase64\n
    ''';

    print(exampleCommand);
  }
}
