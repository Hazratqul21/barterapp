import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/motion_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

double _scaleOf(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(PopOnActivate),
          matching: find.byType(Transform),
        )
        .first,
  );
  // The x scale itself: getMaxScaleOnAxis would report the untouched z axis.
  return transform.transform.entry(0, 0);
}

void main() {
  testWidgets('the heart pops once when it turns on, then rests at 1', (
    tester,
  ) async {
    Widget heart(bool on) => _app(
      PopOnActivate(active: on, child: const Icon(Icons.favorite)),
    );
    await tester.pumpWidget(heart(false));
    expect(_scaleOf(tester), 1);

    await tester.pumpWidget(heart(true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scaleOf(tester), isNot(1), reason: 'mid-pop');

    await tester.pumpAndSettle();
    expect(_scaleOf(tester), 1);

    // Turning off is not an event — no pop.
    await tester.pumpWidget(heart(false));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scaleOf(tester), 1);
  });

  testWidgets('reduce motion: no pop, no sparks', (tester) async {
    Widget heart(bool on) => _app(
      BurstOnActivate(
        active: on,
        color: Colors.red,
        child: PopOnActivate(active: on, child: const Icon(Icons.favorite)),
      ),
      reduce: true,
    );
    await tester.pumpWidget(heart(false));
    await tester.pumpWidget(heart(true));
    await tester.pump(const Duration(milliseconds: 60));
    expect(_scaleOf(tester), 1);
    expect(
      find.descendant(
        of: find.byType(BurstOnActivate),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('confetti plays once and clears itself away', (tester) async {
    await tester.pumpWidget(
      _app(const SizedBox(width: 300, height: 600, child: Celebration())),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('reduce motion: no confetti, the check is drawn at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            SizedBox(width: 300, height: 300, child: Celebration()),
            AnimatedCheck(color: Colors.green, onColor: Colors.white),
          ],
        ),
        reduce: true,
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(Celebration),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    // Nothing left to animate.
    expect(tester.hasRunningAnimations, isFalse);
  });
}
