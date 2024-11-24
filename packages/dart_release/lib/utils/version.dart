import 'package:pub_semver/pub_semver.dart';

Version resolveVersion({
  required Version? pubspecVersion,
  required String? appVersion,
  required String? buildVersion,
  required String? buildPreRelease,
  required String? buildMetadata,
}) {
  Version version;
  if ((appVersion == null || appVersion.isEmpty) &&
      (buildVersion == null || buildVersion.isEmpty)) {
    version = pubspecVersion ?? Version(0, 0, 1);
  } else if (buildVersion != null && buildVersion.isNotEmpty) {
    version = Version.parse(buildVersion);
  } else {
    version = Version.parse(appVersion!.replaceFirst('v', ''));
  }

  if (buildPreRelease != null) {
    version = version.copyWith(pre: buildPreRelease);
  }

  if (buildMetadata != null) {
    version = version.copyWith(build: buildMetadata);
  }
  return version;
}

// Used to work around: https://github.com/dart-lang/language/issues/2232
const _undefined = 'undefined';

extension VersionExt on Version {
  Version copyWith({
    int? major,
    int? minor,
    int? patch,
    String? pre = _undefined,
    String? build = _undefined,
  }) {
    return Version(
      major ?? this.major,
      minor ?? this.minor,
      patch ?? this.patch,
      pre: pre == _undefined
          ? (preRelease.isNotEmpty
              ? preRelease.map((p) => p.toString()).join('.')
              : null)
          : pre,
      build: build == _undefined
          ? (this.build.isNotEmpty
              ? this.build.map((b) => b.toString()).join('.')
              : null)
          : build,
    );
  }
}
