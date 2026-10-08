import 'dart:io';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:barter_app/features/trade/presentation/matches_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F01 on the client: mutual matches say so, reasons are translated, and
/// codes the app does not know yet are skipped rather than shown raw.
Map<String, dynamic> _card(String id, String tag, String title) => {
  'id': id,
  'tag': tag,
  'title': title,
  'image_url': null,
  'image_alt': title,
  'wants_summary': 'x',
  'value': {'minor': 900000000, 'currency': 'UZS'},
  'cash_ok': false,
  'is_premium': false,
  'is_favorite': false,
  'posted_at': '2026-10-06T09:00:00Z',
  'owner': {'id': 'o$id', 'name': 'Aziz', 'is_verified': true},
};

TradeMatch _match({required bool mutual, List<String> codes = const []}) =>
    TradeMatch.fromJson({
      'id': mutual ? 'm1' : 'm2',
      'score': mutual ? 90 : 73,
      'reason': 'Qiymatlar yaqin — toza almashinuv chiqadi.',
      'mutual': mutual,
      'reason_codes': codes,
      'rules_version': 'f01-v1',
      'mine': _card('a', 'electronics', 'Noutbuk'),
      'theirs': _card('b', 'agri', 'Guruch'),
      'owner': {'id': 'ob', 'name': 'Aziz', 'is_verified': true},
    });

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

  test('older servers without the new fields still parse', () {
    final m = TradeMatch.fromJson({
      'id': 'x',
      'score': 70,
      'reason': 'r',
      'mine': _card('a', 'electronics', 'A'),
      'theirs': _card('b', 'agri', 'B'),
      'owner': {'id': 'o', 'name': 'O', 'is_verified': false},
    });
    expect(m.mutual, isFalse);
    expect(m.reasonCodes, isEmpty);
  });

  testWidgets('mutual match: banner, hint and translated reasons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    final prefs = await SharedPreferences.getInstance();
    final matches = [
      _match(
        mutual: true,
        codes: ['mutual', 'named_category', 'nearby', 'some_future_code'],
      ),
      _match(mutual: false, codes: ['value_close']),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          matchesProvider.overrideWith((ref) async => matches),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const MatchesPage()),
            ],
          ),
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('O‘zaro moslik'), findsOneWidget);
    expect(find.textContaining('U ham sizning narsangizni'), findsOneWidget);
    expect(find.text('Siz izlagan toifa'), findsOneWidget);
    expect(find.text('Yaqin atrofda'), findsOneWidget);
    expect(find.text('Qiymatlar yaqin'), findsOneWidget);
    expect(find.textContaining('some_future_code'), findsNothing);
    await expectLater(
      find.byType(MatchesPage),
      matchesGoldenFile('goldens/matches_mutual.png'),
    );
  });
}
