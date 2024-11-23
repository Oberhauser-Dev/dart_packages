import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:dart_release/dart_release.dart';

// Common
const argAppName = 'app-name';
const argAppVersion = 'app-version';
const argBuildMetadata = 'build-metadata';
const argBuildPreRelease = 'build-pre-release';
const argBuildArg = 'build-arg';
const argMainPath = 'main-path';
const argIncludePath = 'include-path';
const argBuildFolder = 'build-folder';
const argExecName = 'exec-name';
const argReleaseFolder = 'release-folder';
const argDartSdkPath = 'dart-sdk-path';

// Build
const commandBuild = 'build';

class BuildCommand extends Command {
  @override
  final name = commandBuild;
  @override
  final description = 'Build the app in the specified format.';

  BuildCommand() {
    addDartReleaseBuildArgs(argParser);
  }

  @override
  FutureOr? run() async {
    final results = argResults;
    if (results == null) throw ArgumentError('No arguments provided');
    final dartBuild = DartBuild(
      appName: results[argAppName] as String?,
      appVersion: results[argAppVersion] as String?,
      buildMetadata: results[argBuildMetadata] as String?,
      buildPreRelease: results[argBuildPreRelease] as String?,
      buildArgs: results[argBuildArg] as List<String>,
      mainPath: results[argMainPath] as String,
      includedPaths: results[argIncludePath] as List<String>,
      buildFolder: results[argBuildFolder] as String?,
      executableName: results[argExecName] as String?,
      releaseFolder: results[argReleaseFolder] as String?,
      dartSdkPath: results[argDartSdkPath] as String?,
    );
    stdout.writeln(await dartBuild.bundle());
  }
}

void addDartReleaseBuildArgs(ArgParser parser) {
  parser
    ..addOption(argAppName, abbr: 'n')
    ..addOption(argAppVersion, abbr: 'v')
    ..addOption(argBuildMetadata, abbr: 'b')
    ..addOption(argBuildPreRelease)
    ..addOption(argMainPath, abbr: 'm', mandatory: true)
    ..addMultiOption(argIncludePath, abbr: 'i')
    ..addMultiOption(argBuildArg, abbr: 'o')
    ..addOption(argBuildFolder)
    ..addOption(argExecName)
    ..addOption(argReleaseFolder)
    ..addOption(argDartSdkPath);
}
