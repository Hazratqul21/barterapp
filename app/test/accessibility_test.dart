import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/core/widgets/common.dart';
import 'package:barter_app/features/feed/presentation/listing_card_tile.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter's own accessibility guidelines, run against the feed card grid in
/// both themes: every tap target ≥ 48px, every target labelled, text
/// contrast AA. Plus what a screen reader actually says for a card.
final _card = ListingCard(
  id: '1',
  tag: ListingTag.electronics,
  title: 'MacBook Pro 14',
  imageAlt: 'Noutbuk',
  wantsSummary: 'Telefon',
  value: const Money(minor: 1850000000, currency: 'UZS'),
  cashOk: true,
  isPremium: false,
  postedAt: DateTime.utc(2026, 10, 6),
  distanceKm: 2.4,
  owner: const TraderBrief(id: 'o', name: 'Aziz', isVerified: true),
);

Future<void> _pumpGrid(WidgetTester tester, {required bool dark}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
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
        body: LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: ListingGrid.delegate(
              constraints.maxWidth - 40,
              MediaQuery.textScalerOf(context),
            ),
            itemCount: 4,
            itemBuilder: (_, _) => ListingCardTile(
              listing: _card,
              onTap: () {},
              onFavorite: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final dark in [false, true]) {
    final name = dark ? 'dark' : 'light';
    testWidgets(
      'feed cards meet tap-target, label and contrast rules ($name)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpGrid(tester, dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );
  }

  testWidgets('a card reads as one sentence; the heart stays its own button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpGrid(tester, dark: false);

    final card = tester.getSemantics(find.byType(ListingCardTile).first);
    expect(card.label, contains('MacBook Pro 14'));
    expect(card.label, contains(RegExp(r'18\s500\s000')));
    expect(card.label, contains('Evaziga oladi: Telefon'));
    expect(card.label, contains('Hujjatlari tasdiqlangan'));
    expect(
      find.bySemanticsLabel('Saqlash'),
      findsNWidgets(4),
      reason: 'heart is a separate, labelled control on each card',
    );
    handle.dispose();
  });

  test('photos decode at display size, in 200px steps, capped at 2000', () {
    expect(RemoteImage.decodeWidthFor(170, 3), 600);
    expect(RemoteImage.decodeWidthFor(170, 2), 400);
    expect(RemoteImage.decodeWidthFor(50, 1), 200);
    expect(RemoteImage.decodeWidthFor(1200, 3), 2000);
  });
}
