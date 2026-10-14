import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/common.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Design v3, stage 3: the swap plays when a deal is agreed on screen — and
/// only then. Opening an old deal, or reduce-motion, plays nothing.
Widget _sides({required bool agreed, bool reduce = false}) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  locale: const Locale('uz'),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: TradeSides(
            giveLabel: 'Guruch',
            takeLabel: 'Nasos',
            agreed: agreed,
          ),
        ),
      ),
    ),
  ),
);

double _arrowTurn(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(of: find.byType(Icon), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getRotation()
    .entry(1, 0)
    .abs();

void main() {
  testWidgets('agreeing on screen turns the arrows over', (tester) async {
    await tester.pumpWidget(_sides(agreed: false));
    expect(_arrowTurn(tester), lessThan(0.001));

    await tester.pumpWidget(_sides(agreed: true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arrowTurn(tester), greaterThan(0.1), reason: 'mid-swap');

    await tester.pumpAndSettle();
    expect(_arrowTurn(tester), lessThan(0.001), reason: 'settles level');
  });

  testWidgets('an already agreed deal does not replay the swap', (
    tester,
  ) async {
    await tester.pumpWidget(_sides(agreed: true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arrowTurn(tester), lessThan(0.001));
  });

  testWidgets('reduce-motion: agreed, but nothing moves', (tester) async {
    await tester.pumpWidget(_sides(agreed: false, reduce: true));
    await tester.pumpWidget(_sides(agreed: true, reduce: true));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_arrowTurn(tester), lessThan(0.001));
  });
}
