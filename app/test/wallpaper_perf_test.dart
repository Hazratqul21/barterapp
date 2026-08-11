import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/backgrounds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The wallpaper sits under every screen and drifts on a fifteen-second loop,
/// so what it costs the tree above it is a performance question rather than a
/// cosmetic one.
///
/// The cost is **paint**, not build. Returning the same child widget from an
/// animated builder is free — Flutter short-circuits on an identical instance
/// — so counting rebuilds proves nothing and an earlier version of this file
/// counted them anyway. What actually hurt was layers: the blooms, the tile
/// lattice and the whole app shared one, so a bloom moving a pixel marked that
/// layer dirty and every frame repainted the lattice's hundreds of stroked
/// paths and the app's own painting along with it.
///
/// So this counts paints, and it is checked to fail when the boundary is
/// removed.
void main() {
  testWidgets('drifting does not repaint the app above it', (tester) async {
    var paints = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AuroraBackground(
          child: CustomPaint(
            painter: _CountingPainter(() => paints++),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(paints, greaterThan(0), reason: 'painted once to begin with');
    final afterFirstFrame = paints;

    // Five seconds of drift, a frame at a time.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      paints,
      afterFirstFrame,
      reason:
          'the wallpaper drifted for five seconds and dragged the app through '
          '${paints - afterFirstFrame} extra repaints',
    );
  });
}

/// Counts every time the layer it lives in is painted.
///
/// `shouldRepaint` is false, so it never asks to be repainted on its own
/// account. Any further call therefore means something else dirtied the layer
/// it shares — which is exactly the condition under test.
class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(_CountingPainter old) => false;
}
