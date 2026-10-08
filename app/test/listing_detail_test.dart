import 'dart:io';

import 'package:barter_app/core/analytics/analytics_service.dart';
import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/feed/data/listing_repository.dart';
import 'package:barter_app/features/feed/presentation/listing_card_tile.dart';
import 'package:barter_app/features/listing/presentation/listing_detail_page.dart';
import 'package:barter_app/features/listing/presentation/photo_viewer.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QuietAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

ListingDetail _listing({int photos = 3}) => ListingDetail(
  id: 'l1',
  tag: ListingTag.electronics,
  title: 'MacBook Pro 14 M3, 16 GB',
  imageAlt: 'Noutbuk',
  wantsSummary: 'Telefon',
  value: const Money(minor: 1850000000, currency: 'UZS'),
  cashOk: true,
  isPremium: false,
  postedAt: DateTime.utc(2026, 10, 6),
  owner: const TraderBrief(
    id: 'o1',
    name: 'Aziz Karimov',
    isVerified: true,
    rating: 4.8,
    deals: 12,
  ),
  description: 'Ideal holatda, quti va zaryadlovchi bilan.',
  category: 'Noutbuk',
  condition: 'Yangidek',
  quantity: '1 dona',
  // Empty URLs render the local placeholder — no network in tests.
  gallery: List.filled(photos, ''),
  wants: const ['iPhone 15 Pro', 'planshet'],
);

Future<void> _pump(WidgetTester tester, ListingDetail listing) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsServiceProvider.overrideWithValue(_QuietAnalytics()),
        listingDetailProvider.overrideWith((ref, id) async => listing),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const ListingDetailPage(listingId: 'l1'),
            ),
          ],
        ),
        debugShowCheckedModeBanner: false,
        // Same root surface as main.dart.
        builder: (context, child) => ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: child,
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

  testWidgets('swipe moves the counter; tap opens the viewer on that photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _listing());

    expect(find.text('1 / 3'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    // Full screen, same photo.
    expect(find.byType(PhotoCounter), findsNWidgets(2));
    expect(find.text('2 / 3'), findsNWidgets(2));
  });

  testWidgets('decision bar shows price, wanted items and the offer action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _listing(photos: 1));

    expect(find.byType(SwapChip), findsWidgets);
    expect(find.text('iPhone 15 Pro, planshet'), findsOneWidget);
    // One photo: no counter.
    expect(find.byType(PhotoCounter), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/listing_detail_phone.png'),
    );
  });

  testWidgets('viewer: arrows page through photos, Escape closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, _listing());

    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Back on the listing, on the photo last viewed.
    expect(find.byType(PhotoCounter), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('detail page meets tap-target, label and contrast rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await _pump(tester, _listing());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
