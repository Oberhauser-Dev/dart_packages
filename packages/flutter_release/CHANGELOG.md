## 0.3.1+2

 - **FIX**: Automatically use completed state on internal publish stage.

## 0.3.1+1

 - **FIX**: Increase retries for xcodebuild showBuildSettings.

## 0.3.1

 - **FIX**: Improved mechanism to detect bundle id on iOS (closes [#26](https://github.com/Oberhauser-dev/dart_packages/issues/26)).
 - **FEAT**: Auto increment build number on iOS if not provided (closes [#27](https://github.com/Oberhauser-dev/dart_packages/issues/27)).

## 0.3.0

> Note: This release has breaking changes.

 - **FIX**: Update package manager before installing.
 - **BREAKING** **FEAT**: Explicit flavor support.

## 0.2.9+1

 - **REFACTOR**: Print build artifact path.
 - **FIX**: Allow space in built output.
 - **FIX**: Allow overriding build version on Android/iOS.

## 0.2.9

 - **FEAT**: Read build output from execution result.
 - **FEAT**: Ensure installation of programs.
 - **DOCS**: Add key password for android.

## 0.2.8

 - **FIX**: Always clean fastlane keychain.
 - **FIX**: Parse fastlane results correctly.
 - **FEAT**: Run fastlane command asynchronously.
 - **FEAT**: Only print build metadata when necessary.
 - **FEAT**: Run flutter command asynchronously.
 - **DOCS**: Adapt README.md.

## 0.2.7+2

 - Update a dependency to the latest release.

## 0.2.7+1

 - **FIX**: Omit build-metadata on Android/iOS if not a number ([#19](https://github.com/Oberhauser-dev/dart_packages/issues/19)).

## 0.2.7

 - **FEAT**: Support build metadata and pre-release ([#17](https://github.com/Oberhauser-dev/dart_packages/issues/17)).

## 0.2.6

 - **FIX**: Parse iosUpdateProvisioning string as bool ([#15](https://github.com/Oberhauser-dev/dart_packages/issues/15)).
 - **FIX**: Parse versions starting with 'v' ([#13](https://github.com/Oberhauser-dev/dart_packages/issues/13)).
 - **FEAT**: Support flavors/schemes on ios ([#12](https://github.com/Oberhauser-dev/dart_packages/issues/12)).

## 0.2.5

 - **CI**: Publish from GitHub CI.

## 0.2.4

 - **CI**: Publish from GitHub CI.

## 0.2.3

 - **CI**: Publish from GitHub CI.

## 0.2.2

 - **FEAT**: Use ssh controller.

## 0.2.1

 - **FEAT**: Auto detect arch.

## 0.2.0

 - Add dart_release as dependency

 - **REFACTOR**: Make FlutterPublish independent of FlutterBuild.
 - **REFACTOR**: Split implementations per platform.
 - **DOCS**: Adapt supported features.

## 0.1.4 - 2024-04-22

- Fix upload by using API key json path

## 0.1.3 - 2024-04-18

- Support Publishing to Apple's iOS App Store

## 0.1.2 - 2024-04-05

- Support Publishing to a web server

## 0.1.1 - 2024-03-30

- Create missing fastlane directory
- Update documentation

## 0.1.0 - 2024-03-30

- Restructure package
- Enable signing during build

## 0.0.7 - 2024-03-29

- Make build arguments work

## 0.0.6 - 2024-03-29

- Option to Publish to Google Play Store

## 0.0.5 - 2023-12-05

- Add `arch` param to support architectures for linux and windows
- Use flutter_to_debian as direct dependency

## 0.0.4 - 2023-07-06

- Compress macOS app folder
- Add docs

## 0.0.3 - 2023-06-09

- Update flutter_to_debian package
- Make Platform name lowercase in output package

## 0.0.2 - 2023-06-08

- Add executable in pubspec.yaml
- Update Readme
- Add example
- Add docs

## 0.0.1 - 2023-06-08

- Initial version.
