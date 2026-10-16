import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_release/utils.dart';
import 'package:flutter_release/flutter_release.dart';
import 'package:logging/logging.dart';
import 'package:msix/msix.dart';
import 'package:path/path.dart' as path;

final _logger = Logger('WindowsPlatformBuild');

/// Build the app for Windows.
class WindowsPlatformBuild extends PlatformBuild {
  /// The base64 encoded certificate (.pfx) to sign the MSIX installer.
  final String? certificateFileBase64;

  /// The password of the certificate.
  final String? certificatePassword;

  /// Whether to build the MSIX installer for the Microsoft Store.
  ///
  /// The installer is not signed, as the Microsoft Store signs it on submission.
  final bool isStore;

  /// The publisher of the MSIX installer (e.g. `CN=...`), overrides the `publisher` of the `msix_config`.
  ///
  /// Required for the Microsoft Store. When signing, it must match the subject of the certificate.
  final String? publisher;

  /// The identity name of the MSIX installer, overrides the `identity_name` of the `msix_config`.
  ///
  /// Required for the Microsoft Store.
  final String? identityName;

  /// The display name of the publisher, overrides the `publisher_display_name` of the `msix_config`.
  ///
  /// Required for the Microsoft Store.
  final String? publisherDisplayName;

  const WindowsPlatformBuild({
    required super.buildType,
    required super.flutterBuild,
    this.certificateFileBase64,
    this.certificatePassword,
    this.isStore = false,
    this.publisher,
    this.identityName,
    this.publisherDisplayName,
  });

  /// Build the artifact for Windows.
  @override
  Future<String?> build() async {
    final cpuArchitecture = getCpuArchitecture();

    return switch (buildType) {
      BuildType.windows => _buildWindows(arch: cpuArchitecture),
      BuildType.msix => _buildMsix(arch: cpuArchitecture),
      _ => throw UnsupportedError(
          'BuildType $buildType is not available for Windows!'),
    };
  }

  /// Build the artifact for Windows. It creates a .zip archive.
  Future<String?> _buildWindows({required CpuArchitecture arch}) async {
    var filePath = await flutterBuild.build(buildCmd: 'windows');
    if (filePath == null) return null;
    filePath = '${path.dirname(filePath)}\\*';

    final artifactPath = flutterBuild.getArtifactPath(
      platform: 'windows',
      arch: arch,
      extension: 'zip',
    );
    await runProcess(
      'powershell',
      [
        'Compress-Archive',
        '-Force',
        '-Path',
        filePath,
        '-DestinationPath',
        artifactPath.replaceAll('/', '\\'),
      ],
    );

    return artifactPath;
  }

  /// Build the artifact for Windows. It creates a .msix installer.
  ///
  /// The package is configured via `msix_config` in the `pubspec.yaml`, see https://pub.dev/packages/msix.
  /// Without a certificate, the installer is signed with the test certificate of the msix package.
  /// For the Microsoft Store ([isStore]), the installer is not signed at all.
  Future<String?> _buildMsix({required CpuArchitecture arch}) async {
    final filePath = await flutterBuild.build(buildCmd: 'windows');
    if (filePath == null) return null;

    final artifactPath = flutterBuild.getArtifactPath(
      platform: isStore ? 'windows-store' : 'windows',
      arch: arch,
      extension: 'msix',
    );

    File? certificateFile;
    if (isStore) {
      if (certificateFileBase64 != null) {
        _logger.warning(
            'Ignore certificate, as the Microsoft Store signs the installer.');
      }
    } else if (certificateFileBase64 != null) {
      _logger.fine('Prepare signing certificate');
      final tempDir = await Directory.systemTemp.createTemp('flutter_release');
      certificateFile = File(path.join(tempDir.path, 'certificate.pfx'));
      await certificateFile.writeAsBytes(base64.decode(certificateFileBase64!));
    } else {
      _logger.fine('Skip signing with own certificate.');
    }

    // MSIX only supports versions in the format `a.b.c.d`.
    final version = flutterBuild.buildVersion;
    try {
      await Msix([
        '--build-windows',
        'false',
        '--version',
        '${version.major}.${version.minor}.${version.patch}.0',
        '--architecture',
        getFlutterCpuArchitecture(arch),
        '--output-path',
        path.absolute(path.dirname(artifactPath)),
        '--output-name',
        path.basenameWithoutExtension(artifactPath),
        // Never modify the certificate store of the build machine.
        '--install-certificate',
        'false',
        if (isStore) '--store',
        if (publisher != null) ...['--publisher', publisher!],
        if (identityName != null) ...['--identity-name', identityName!],
        if (publisherDisplayName != null) ...[
          '--publisher-display-name',
          publisherDisplayName!,
        ],
        if (certificateFile != null) ...[
          '--certificate-path',
          certificateFile.path,
        ],
        if (certificateFile != null && certificatePassword != null) ...[
          '--certificate-password',
          certificatePassword!,
        ],
      ]).create();
      // The msix package does not terminate its last output with a newline,
      // but the artifact path must be printed on its own line.
      stdout.writeln();
    } finally {
      await certificateFile?.parent.delete(recursive: true);
    }

    return artifactPath;
  }
}

/// Publish the app in the Microsoft Store via the [Microsoft Store Developer CLI](https://github.com/microsoft/msstore-cli).
///
/// It does not build the app, but publishes the [packages] built via `build msix --store`.
/// The app must have been submitted manually once before.
/// The `msstore` executable must be installed, e.g. via [microsoft-store-apppublisher](https://github.com/microsoft/microsoft-store-apppublisher).
class WindowsMsStoreDistributor
    extends PublishDistributor<WindowsPlatformBuild> {
  /// The Microsoft Entra tenant id associated with the Partner Center account.
  final String tenantId;

  /// The client id of the Microsoft Entra application.
  final String clientId;

  /// The client secret of the Microsoft Entra application, called key in Partner Center.
  final String clientSecret;

  /// The seller id of the Partner Center account.
  final String sellerId;

  /// The Store id of the app (e.g. `9N...`), see Partner Center > Product identity.
  final String productId;

  /// The id of the package flight, publishes to the public if null.
  final String? flightId;

  /// The rollout percentage of the package (0-100).
  final double? packageRolloutPercentage;

  /// The status of the submission.
  final WindowsReleaseStatus releaseStatus;

  /// The MSIX packages (e.g. one per architecture) built via `build msix --store`.
  ///
  /// If empty, the packages of the app version are taken from the release folder.
  /// Multiple packages are published within one bundle.
  final List<String> packages;

  WindowsMsStoreDistributor({
    required super.flutterPublish,
    required super.platformBuild,
    required this.tenantId,
    required this.clientId,
    required this.clientSecret,
    required this.sellerId,
    required this.productId,
    this.packages = const [],
    this.flightId,
    this.packageRolloutPercentage,
    this.releaseStatus = WindowsReleaseStatus.draft,
  }) : super(distributorType: PublishDistributorType.windowsMsStore);

  @override
  Future<void> publish() async {
    final packages =
        this.packages.isNotEmpty ? this.packages : await _findPackages();
    for (final package in packages) {
      if (!await File(package).exists()) {
        throw ArgumentError('MSIX package not found: $package');
      }
    }
    final stage = flutterPublish.stage;
    if (flightId == null && stage != null && stage != PublishStage.production) {
      _logger.warning('Stage "${stage.name}" is ignored, '
          'as no flight id is provided. Publish to the public.');
    }

    try {
      await runProcess('msstore', ['--version'], runInShell: true);
    } catch (_) {
      throw Exception(
          'The Microsoft Store Developer CLI (msstore) is not installed, '
          'see https://apps.microsoft.com/detail/9p53pc5s0phj');
    }

    _logger.info('Configure Microsoft Store credentials...');
    await runProcess(
      'msstore',
      [
        'reconfigure',
        '--tenantId',
        tenantId,
        '--sellerId',
        sellerId,
        '--clientId',
        clientId,
        '--clientSecret',
        clientSecret,
      ],
      runInShell: true,
    );
    // Check the credentials and the product id.
    await runProcess('msstore', ['apps', 'get', productId], runInShell: true);
    await _checkArchitectures(packages);

    Directory? bundleDir;
    try {
      var packagePath = packages.first;
      if (packages.length > 1) {
        bundleDir = await Directory.systemTemp.createTemp('flutter_release');
        // Remove the architecture suffix of the package name.
        final archNames = CpuArchitecture.values.map((a) => a.name).join('|');
        final bundleName = path
            .basenameWithoutExtension(packages.first)
            .replaceFirst(RegExp('-($archNames)\$'), '');
        packagePath = await _bundle(
          packages: packages,
          bundleDir: bundleDir,
          outputPath:
              path.join(path.dirname(packages.first), '$bundleName.msixbundle'),
        );
        _logger.info('Bundle artifact path: $packagePath');
      }

      if (flutterPublish.isDryRun) {
        _logger
            .info('Did NOT publish: Remove `--dry-run` flag for publishing.');
        return;
      }

      _logger.info('Upload...');
      // Always keep the submission as draft first, to remove the previous packages.
      await runAsyncProcess(
        'msstore',
        [
          'publish',
          path.absolute(packagePath),
          '--appId',
          productId,
          if (flightId != null) ...['--flightId', flightId!],
          if (packageRolloutPercentage != null) ...[
            '--packageRolloutPercentage',
            packageRolloutPercentage.toString(),
          ],
          '--noCommit',
        ],
        printCall: true,
        runInShell: true,
      );
      await _removePreviousPackages(path.basename(packagePath));

      if (releaseStatus == WindowsReleaseStatus.completed) {
        _logger.info('Submit for certification...');
        await runAsyncProcess(
          'msstore',
          [..._submissionCommand, 'publish', ..._submissionIds],
          printCall: true,
        );
      }
    } finally {
      await bundleDir?.delete(recursive: true);
    }
  }

  /// The msstore command for the submission of the app or of the package flight.
  List<String> get _submissionCommand =>
      flightId == null ? ['submission'] : ['flights', 'submission'];

  List<String> get _submissionIds =>
      [productId, if (flightId != null) flightId!];

  String get _packagesKey =>
      flightId == null ? 'ApplicationPackages' : 'FlightPackages';

  /// Get the pending submission, or the last published one if there is none.
  Future<Map<String, dynamic>> _getSubmission() async {
    final result = await runProcess(
        'msstore', [..._submissionCommand, 'get', ..._submissionIds]);
    return jsonDecode(result.stdout as String) as Map<String, dynamic>;
  }

  /// Fail, if an architecture of the current submission is missing in the [packages].
  ///
  /// Otherwise, the architecture would be removed from the Store.
  Future<void> _checkArchitectures(List<String> packages) async {
    // The architecture names used by the Microsoft Store.
    const storeArchNames = {
      CpuArchitecture.amd32: 'x86',
      CpuArchitecture.amd64: 'x64',
      CpuArchitecture.arm32: 'arm',
      CpuArchitecture.arm64: 'arm64',
    };
    final archNames = CpuArchitecture.values.map((a) => a.name).join('|');
    final packageArchRegex = RegExp('-($archNames)\\.msix\$');
    final packageArchs = <String>{};
    for (final package in packages) {
      final match = packageArchRegex.firstMatch(path.basename(package));
      final storeArchName = match == null
          ? null
          : storeArchNames[CpuArchitecture.values.byName(match.group(1)!)];
      if (storeArchName == null) {
        _logger.warning('Skip architecture check, '
            'as the architecture of $package is unknown.');
        return;
      }
      packageArchs.add(storeArchName);
    }

    final storePackages =
        ((await _getSubmission())[_packagesKey] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .where((p) => p['FileStatus'] != 'PendingDelete');
    final storeArchs = <String>{};
    for (final storePackage in storePackages) {
      // Bundles may list multiple architectures.
      final archs = (storePackage['Architecture'] as String? ?? '')
          .split(',')
          .map((a) => a.trim().toLowerCase())
          .where((a) => a.isNotEmpty);
      if (archs.isEmpty || archs.any((a) => !storeArchNames.containsValue(a))) {
        _logger.warning('Skip architecture check, as the architecture '
            '"${storePackage['Architecture']}" of ${storePackage['FileName']} '
            'in the Store is unknown.');
        return;
      }
      storeArchs.addAll(archs);
    }

    final missingArchs = storeArchs.difference(packageArchs);
    if (missingArchs.isNotEmpty) {
      throw ArgumentError('The Store contains packages for the architectures '
          '${missingArchs.join(', ')}, which are missing in the packages. '
          'Add their packages, or remove the architectures in Partner Center first.');
    }
  }

  /// Mark all packages of the draft except [packageName] for deletion.
  ///
  /// msstore only replaces one package of the same file extension,
  /// so packages of other architectures or a previous `.msix` (if a bundle is uploaded) would remain.
  Future<void> _removePreviousPackages(String packageName) async {
    final submission = await _getSubmission();
    final storePackages =
        (submission[_packagesKey] as List? ?? []).cast<Map<String, dynamic>>();
    if (!storePackages.any((p) => p['FileName'] == packageName)) {
      throw Exception('Uploaded package $packageName not found in the draft.');
    }

    final previousPackages = storePackages.where(
        (p) => p['FileName'] != packageName && p['FileStatus'] == 'Uploaded');
    if (previousPackages.isEmpty) return;
    for (final previousPackage in previousPackages) {
      _logger.info('Remove previous package ${previousPackage['FileName']}');
      previousPackage['FileStatus'] = 'PendingDelete';
    }

    // Pass the submission as file, as it may exceed the command line length.
    final tempDir = await Directory.systemTemp.createTemp('flutter_release');
    try {
      final submissionFile = File(path.join(tempDir.path, 'submission.json'));
      await submissionFile.writeAsString(jsonEncode(submission));
      await runProcess('msstore', [
        ..._submissionCommand,
        'update',
        ..._submissionIds,
        submissionFile.path,
      ]);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// Find the packages of the app version in the release folder, one per architecture.
  ///
  /// Packages of other versions are ignored, so they can stay in the release folder.
  Future<List<String>> _findPackages() async {
    final flutterBuild = platformBuild.flutterBuild;
    final releaseDir = Directory(flutterBuild.releaseFolder);
    final archNames = CpuArchitecture.values.map((a) => a.name).join('|');
    final packageRegex = RegExp('^${RegExp.escape(flutterBuild.appName)}-(.+)'
        '-windows-store-($archNames)\\.msix\$');

    final packages = <String>[];
    final otherVersions = <String>{};
    if (await releaseDir.exists()) {
      await for (final file in releaseDir.list()) {
        if (file is! File) continue;
        final match = packageRegex.firstMatch(path.basename(file.path));
        if (match == null) continue;
        if (match.group(1) == flutterBuild.appVersion) {
          packages.add(file.path);
        } else {
          otherVersions.add(match.group(1)!);
        }
      }
    }
    if (packages.isEmpty) {
      throw ArgumentError(
          'No MSIX package of version ${flutterBuild.appVersion} found in '
          '${flutterBuild.releaseFolder}, build it via `build msix --store`'
          '${otherVersions.isEmpty ? '' : ' or set the version via '
              '`--app-version` (found: ${otherVersions.join(', ')})'}.');
    }
    packages.sort();
    _logger.info('Found packages: ${packages.join(', ')}');
    return packages;
  }

  /// Bundle the MSIX [packages] into a single `.msixbundle`.
  Future<String> _bundle({
    required List<String> packages,
    required Directory bundleDir,
    required String outputPath,
  }) async {
    for (final package in packages) {
      await File(package)
          .copy(path.join(bundleDir.path, path.basename(package)));
    }

    // The msix package ships the MSIX Toolkit.
    final makeAppxUri = await Isolate.resolvePackageUri(
        Uri.parse('package:msix/assets/MSIX-Toolkit/Redist.x64/MakeAppx.exe'));
    if (makeAppxUri == null) throw Exception('MakeAppx.exe not found.');

    // Use the app version as bundle version.
    final version = platformBuild.flutterBuild.buildVersion;
    await runProcess(
      makeAppxUri.toFilePath(),
      [
        'bundle',
        '/d',
        bundleDir.path,
        '/p',
        path.absolute(outputPath),
        '/bv',
        '${version.major}.${version.minor}.${version.patch}.0',
        '/o',
      ],
      printCall: true,
    );
    return outputPath;
  }
}

/// The status of a Microsoft Store submission.
enum WindowsReleaseStatus {
  /// Submitted for certification, published afterwards (depending on the publish settings in Partner Center).
  completed,

  /// Kept as draft in Partner Center.
  draft,
}
