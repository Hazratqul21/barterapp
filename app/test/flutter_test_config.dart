import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in this directory.
///
/// Golden images are compared with a small tolerance: anti-aliasing differs
/// by a few pixels between machines (a laptop and the CI runner), while a
/// real design change moves far more than 0.5% of an image.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Load actual icon glyphs as well as text fonts for meaningful screenshots.
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(previous.basedir);
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(Uri basedir) : super(basedir.resolve('_.dart'));

  static const _maxDiff = 0.005;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _maxDiff) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
