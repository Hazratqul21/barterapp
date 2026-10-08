import 'dart:io';

import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/deal_timeline.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Offer _offer(String status, {bool me = false, bool peer = false}) =>
    Offer.fromJson({
      'id': 'o',
      'status': status,
      'cash_delta_minor': 0,
      'currency': 'UZS',
      'created_at': '2026-10-06T09:00:00Z',
      'is_mine': true,
      'counterparty': {'id': 'p', 'name': 'Aziz', 'is_verified': true},
      'wanted': _card('w'),
      'offered': [_card('m')],
      'confirmed_by_me': me,
      'confirmed_by_peer': peer,
    });

Map<String, dynamic> _card(String id) => {
  'id': id,
  'tag': 'electronics',
  'title': 'T',
  'image_alt': '',
  'wants_summary': '',
  'value': {'minor': 100, 'currency': 'UZS'},
  'cash_ok': true,
  'is_premium': false,
  'posted_at': '2026-10-06T09:00:00Z',
  'owner': {'id': 'o', 'name': 'O', 'is_verified': false},
};

final _states = <(String, Offer)>[
  ('accepted', _offer('accepted')),
  ('accepted, I confirmed', _offer('accepted', me: true)),
  ('completed', _offer('completed', me: true, peer: true)),
  ('disputed', _offer('disputed')),
  ('refunded', _offer('refunded')),
  ('expired', _offer('expired')),
];

Future<void> _pump(WidgetTester tester, {bool dark = false}) async {
  tester.view.physicalSize = const Size(390, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      locale: const Locale('uz'),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        backgroundColor: dark ? AppTheme.dark().colorScheme.surface : null,
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final (name, offer) in _states) ...[
              Text(name),
              const SizedBox(height: 6),
              DealTimeline(offer: offer),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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

  for (final dark in [false, true]) {
    testWidgets('timeline states (${dark ? 'dark' : 'light'})', (tester) async {
      await _pump(tester, dark: dark);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(ListView),
        matchesGoldenFile(
          'goldens/deal_timeline_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }

  testWidgets('a screen reader hears the step, not four dots', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(
      find.bySemanticsLabel('Bitim: 3/4-qadam, Topshirildi'),
      findsOneWidget,
      reason: 'accepted + my confirmation = handed-over step',
    );
    expect(
      find.bySemanticsLabel('Bitim: 4/4-qadam, Yakunlandi'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
