import 'dart:isolate';

/// Utility function to get the URI of a file in the package.
/// The [filePath] should be relative to the `lib` directory of the package.
Future<Uri?> getPackageFileUri(String filePath) async {
  final uri = Uri.tryParse('package:flutter_release/$filePath');
  if (uri == null) return null;
  return await Isolate.resolvePackageUri(uri);
}
