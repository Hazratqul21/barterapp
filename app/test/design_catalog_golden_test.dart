import 'dart:io';

import 'package:barter_app/core/design/design_catalog_page.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshots of the design catalog, so a token change is a reviewed image
/// diff instead of a surprise on a real screen.
///
/// Regenerate after an intended change:
///   flutter test --update-goldens test/design_catalog_golden_test.dart
void main() {
  setUpAll(() async {
    // Real glyphs, not test boxes: the point is to see the typography.
    final manrope = FontLoader('Manrope')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Manrope-Variable.ttf').readAsBytesSync(),
          ),
        ),
      );
    await manrope.load();

    // Anti-aliasing differs by a few pixels between machines; a real token
    // change moves far more than this.
    final previous = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${previous.basedir}design_catalog_golden_test.dart'),
    );
  });

  for (final (name, dark, scale) in [
    ('light', false, 1.0),
    ('dark', true, 1.0),
    ('light_text2x', false, 2.0),
  ]) {
    testWidgets('design catalog — $name', (tester) async {
      tester.view.physicalSize = Size(390, scale > 1 ? 3400 : 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: tester.view.physicalSize,
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: const DesignCatalogPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'no overflow at $name');
      await expectLater(
        find.byType(DesignCatalogPage),
        matchesGoldenFile('goldens/design_catalog_$name.png'),
      );
    });
  }
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  static const _maxDiff = 0.005; // 0.5% of pixels

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
