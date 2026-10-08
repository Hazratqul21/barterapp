import 'dart:io';

import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/feed/presentation/listing_card_tile.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The feed card v2 in a phone-width grid: two columns, swap chip, price.
///
///   flutter test --update-goldens test/listing_card_golden_test.dart
ListingCard _card(
  String id,
  ListingTag tag,
  String title,
  String wants,
  int som, {
  bool verified = false,
  double? km,
}) => ListingCard(
  id: id,
  tag: tag,
  title: title,
  imageAlt: title,
  wantsSummary: wants,
  value: Money(minor: som * 100, currency: 'UZS'),
  cashOk: true,
  isPremium: false,
  postedAt: DateTime.utc(2026, 10, 6, 9),
  distanceKm: km,
  owner: TraderBrief(id: 'o$id', name: 'Aziz', isVerified: verified),
);

final _cards = [
  _card(
    '1',
    ListingTag.electronics,
    'MacBook Pro 14 M3, 16 GB',
    'Telefon yoki planshet',
    18500000,
    verified: true,
    km: 2.4,
  ),
  _card(
    '2',
    ListingTag.agri,
    '2 tonna guruch, Lazer navi',
    'Nasos',
    14000000,
    km: 38,
  ),
  _card(
    '3',
    ListingTag.machinery,
    'MTZ-80 traktor, 2015-yil, yaxshi holatda',
    'Yengil mashina',
    95000000,
  ),
  _card(
    '4',
    ListingTag.construction,
    'G‘isht 5000 dona',
    '',
    4200000,
    verified: true,
  ),
];

void main() {
  setUpAll(() async {
    final manrope = FontLoader('Manrope')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Manrope-Variable.ttf').readAsBytesSync(),
          ),
        ),
      );
    await manrope.load();
  });

  for (final (name, dark, scale) in [
    ('light', false, 1.0),
    ('dark', true, 1.0),
    ('light_text1.6', false, 1.6),
  ]) {
    testWidgets('listing card grid — $name', (tester) async {
      tester.view.physicalSize = Size(390, scale > 1 ? 2700 : 760);
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
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: ListingGrid.delegate(
                      constraints.maxWidth - 40,
                      MediaQuery.textScalerOf(context),
                    ),
                    itemCount: _cards.length,
                    itemBuilder: (context, i) =>
                        ListingCardTile(listing: _cards[i], onTap: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'no overflow at $name');
      // The barter half is always present — an empty wish reads "any offer".
      expect(find.byType(SwapChip), findsNWidgets(4));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/listing_card_grid_$name.png'),
      );
    });
  }
}
