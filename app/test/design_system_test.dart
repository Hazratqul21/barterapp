import 'dart:io';
import 'dart:math' as math;

import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/theme/motion.dart';
import 'package:barter_app/core/theme/tokens.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('contrast (WCAG AA)', () {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      final s = theme.colorScheme;
      final p = theme.extension<BarterPalette>()!;
      final ink = theme.textTheme.bodyMedium!.color!;
      final name = brightness.name;

      // Body text: 4.5:1 on every surface it sits on.
      final text = <String, (Color, Color)>{
        'ink on canvas': (ink, p.canvas),
        'ink on card': (ink, s.surfaceContainerLow),
        'inkSoft on canvas': (p.inkSoft, p.canvas),
        'inkSoft on card': (p.inkSoft, s.surfaceContainerLow),
        'inkFaint on canvas': (p.inkFaint, p.canvas),
        'give on canvas': (p.give, p.canvas),
        'take on canvas': (p.take, p.canvas),
        'onPrimary on primary': (s.onPrimary, s.primary),
        'onPrimaryContainer on primaryContainer': (
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
      };
      text.forEach((label, pair) {
        test('$name: $label ≥ 4.5', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });

      // Large/bold text and icons (price, category marks): 3:1.
      final large = <String, (Color, Color)>{
        'money on canvas': (p.money, p.canvas),
        for (final tag in ListingTag.values)
          'category ${tag.name} on its tint': (
            brightness == Brightness.light
                ? CategoryStyle.of(tag).color
                : CategoryStyle.of(tag).dark.color,
            brightness == Brightness.light
                ? CategoryStyle.of(tag).tint
                : CategoryStyle.of(tag).dark.tint,
          ),
      };
      large.forEach((label, pair) {
        test('$name: $label ≥ 3', () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(3));
        });
      });
    }
  });

  test('no hard-coded colours outside the theme', () {
    // Colours live in core/theme (and the hand-drawn marks in core/art). A
    // stray `Color(0x…)` in a screen is how a palette drifts apart.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/core/theme/') ||
          path.startsWith('lib/core/art/') ||
          path.startsWith('lib/l10n/')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('Color(0x')) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  group('motion springs', () {
    for (final (name, spec) in [
      ('fast', Motion.fast),
      ('standard', Motion.standard),
      ('slow', Motion.slow),
      ('bouncy', Motion.bouncy),
    ]) {
      test('$name starts at 0, lands on 1, settles in its duration', () {
        final curve = spec.curve;
        expect(curve.transform(0), 0);
        expect(curve.transform(1), 1);
        expect((curve.transform(0.98) - 1).abs(), lessThan(0.02));
      });
    }

    test('only bouncy overshoots', () {
      double peak(MotionSpec m) => [
        for (var i = 0; i <= 100; i++) m.curve.transform(i / 100),
      ].reduce(math.max);
      expect(peak(Motion.fast), lessThanOrEqualTo(1.001));
      expect(peak(Motion.standard), lessThanOrEqualTo(1.001));
      expect(peak(Motion.slow), lessThanOrEqualTo(1.001));
      expect(peak(Motion.bouncy), greaterThan(1.02));
    });
  });
}
