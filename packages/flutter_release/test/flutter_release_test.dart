import 'package:flutter_release/flutter_release.dart';
import 'package:test/test.dart';

void main() {
  test('release', () {
    final release = FlutterBuild(appName: 'test-app', appVersion: 'v0.0.2');
    expect(release.appVersion, 'v0.0.2');
  });

  test('build output path', () {
    final apkLog =
        '✓ Built build/app/outputs/flutter-apk/app-release.apk (18.7MB)';
    final windowsLog =
        r'`âˆš Built build\windows\x64\runner\Release\example.exe';
    final linuxLog = '✓ Built build/linux/x64/release/bundle/example';
    final webLog = '✓ Built build/web';
    final macOsLog =
        '✓ Built build/macos/Build/Products/Release/example with space.app (46.1MB)';
    final iosLog = '✓ Built build/ios/iphoneos/Runner.app (51.9MB)';

    expect(FlutterBuild.parseFlutterBuildResult(apkLog),
        'build/app/outputs/flutter-apk/app-release.apk');
    expect(FlutterBuild.parseFlutterBuildResult(windowsLog),
        r'build\windows\x64\runner\Release\example.exe');
    expect(FlutterBuild.parseFlutterBuildResult(linuxLog),
        'build/linux/x64/release/bundle/example');
    expect(FlutterBuild.parseFlutterBuildResult(webLog), 'build/web');
    expect(FlutterBuild.parseFlutterBuildResult(macOsLog),
        'build/macos/Build/Products/Release/example with space.app');
    expect(FlutterBuild.parseFlutterBuildResult(iosLog),
        'build/ios/iphoneos/Runner.app');

    expect(
        FlutterBuild.parseFlutterBuildResult(
            'asdf build/ios/iphoneos/Runner.app (51.9MB)'),
        null);
  });
}
