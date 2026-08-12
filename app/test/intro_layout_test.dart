import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/features/onboarding/presentation/intro_page.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The intro is the first screen anyone sees, and it has to survive a short
/// viewport: a small phone held sideways, a split-screen window, a browser with
/// the dev tools open. It did not — the drawing is a fixed 260×200 and the
/// column overflowed by 15 pixels at 302, painting the app's very first
/// impression with yellow and black stripes.
Future<void> _pumpIntro(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const IntroPage(),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('the intro fits a short viewport', (tester) async {
    // The size that produced the overflow, plus the chrome above the pager.
    await _pumpIntro(tester, const Size(560, 420));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the intro fits a small phone', (tester) async {
    // An iPhone SE, which is still a live device in this market.
    await _pumpIntro(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the intro fits a phone held sideways', (tester) async {
    await _pumpIntro(tester, const Size(740, 360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the drawing keeps full size when there is room', (tester) async {
    await _pumpIntro(tester, const Size(430, 932));

    // `scaleDown` must not shrink what already fits, or every ordinary phone
    // would get a smaller picture to buy safety on a rare one.
    final art = tester.getSize(find.byType(CustomPaint).first);
    expect(art.height, greaterThanOrEqualTo(190));
  });
}
