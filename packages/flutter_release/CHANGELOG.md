## 0.3.5+2

 - **FIX**(ios): Support building IPA directly. ([b68ea8d5](https://github.com/Oberhauser-Dev/dart_packages/commit/b68ea8d5fb9cd021a1b9640a783dee6e53b98da1))

## 0.3.5+1

 - **FIX**: Warn if version code cannot be parsed from App Store. ([f79a5fec](https://github.com/Oberhauser-Dev/dart_packages/commit/f79a5fec511f549c1c228c6a0a246cbe8240a9d6))
 - **FIX**: Match correct line for build archive. ([3646713d](https://github.com/Oberhauser-Dev/dart_packages/commit/3646713dc37b26a4acb7bc695ce0d727b916d06c))
 - **DOCS**: Fix comment on ios archive. ([7223db1f](https://github.com/Oberhauser-Dev/dart_packages/commit/7223db1f55af36ee8ebf7887ae0738d8d7cb7a05))

## 0.3.5

 - **FEAT**: Migrate to logging package. ([4e62b03a](https://github.com/Oberhauser-Dev/dart_packages/commit/4e62b03ae081c275cf0617399a0716304e181735))
 - **FEAT**: Execute flutter build asynchronously. ([6194c289](https://github.com/Oberhauser-Dev/dart_packages/commit/6194c289710cfff646488219c18f6b48ec5b6268))
 - **FEAT**: Support verbose logging. ([35637b81](https://github.com/Oberhauser-Dev/dart_packages/commit/35637b814b7caa2a92e0b559298ac10d99ed124c))

## 0.3.4

 - **PERF**: Add skip_waiting_for_build_processing to iOS upload (closes [#48](https://github.com/Oberhauser-Dev/dart_packages/issues/48)). ([c36f970e](https://github.com/Oberhauser-Dev/dart_packages/commit/c36f970e4b10f454ac9a85aa240ae2ced97f65c4))
 - **FEAT**: Support Kotlin gradle files. ([cfa76c96](https://github.com/Oberhauser-Dev/dart_packages/commit/cfa76c96762f68d4391a54e8ada888ff1b307ed7))
 - **FEAT**: Renew ios certificate ([#46](https://github.com/Oberhauser-Dev/dart_packages/issues/46)). ([c576e394](https://github.com/Oberhauser-Dev/dart_packages/commit/c576e39480ccc18d414fda8bd33b6e413eb629d3))
 - **DOCS**: Add option `release-status` to README. ([a32c7458](https://github.com/Oberhauser-Dev/dart_packages/commit/a32c7458e13e7b777359377cb3e3f2bfd991ecd5))

## 0.3.3

 - **FEAT**: Support more Cpu architectures. ([b50543c5](https://github.com/Oberhauser-Dev/dart_packages/commit/b50543c5677cd64fba3def6fc342ee4096653c29))

## 0.3.2

 - **FEAT**: Android Release status.

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
