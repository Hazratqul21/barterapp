import 'dart:io';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/onboarding/presentation/splash_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brand v3: olive ground, gold wordmark and the tagline, matching the native
/// launch screen that comes before it.
void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Manrope-Variable.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });

  testWidgets('splash shows the gold mark on olive', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SplashPage()),
              GoRoute(path: '/intro', builder: (_, _) => const SizedBox()),
              GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final element = tester.element(find.byType(SplashPage));
      await precacheImage(
        const AssetImage('assets/brand/mab-wordmark-gold.png'),
        element,
      );
    });
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Almashing. Ishoning.'), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/brand/mab-wordmark-gold.png')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(SplashPage),
      matchesGoldenFile('goldens/splash.png'),
    );
    // Let the route timer fire so the test ends clean.
    await tester.pump(const Duration(seconds: 1));
  });
}
