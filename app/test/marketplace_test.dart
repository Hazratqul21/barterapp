import 'dart:async';
import 'dart:io';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/router/app_router.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/feed/data/listing_repository.dart';
import 'package:barter_app/features/auth/data/auth_repository.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:barter_app/features/feed/presentation/listing_card_tile.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

models.ListingCard item(String id) => models.ListingCard(
  id: id,
  tag: models.ListingTag.electronics,
  title: 'MacBook Pro 14',
  imageAlt: 'Laptop',
  wantsSummary: 'Telefon / Elektronika',
  value: const models.Money(minor: 148680000, currency: 'UZS'),
  cashOk: true,
  isPremium: false,
  postedAt: DateTime(2026, 8, 22),
  owner: const models.TraderBrief(id: 'owner', name: 'Jasur', isVerified: true),
);

class Repository implements ListingRepository {
  Future<models.Page<models.ListingCard>> Function(String?, String?)? handler;
  @override
  Future<models.Page<models.ListingCard>> feed({
    String? categoryId,
    String? query,
    String? cursor,
    double? minPrice,
    double? maxPrice,
    String? region,
    String? sortBy,
  }) async {
    if (handler != null) return handler!(query, cursor);
    return models.Page(items: List.generate(6, (i) => item('$i')));
  }

  @override
  Future<List<models.CategoryModel>> categories() async => const [
    models.CategoryModel(id: 'agri', name: 'Qishloq xo‘jaligi'),
    models.CategoryModel(id: 'electronics', name: 'Elektronika'),
    models.CategoryModel(id: 'construction', name: 'Qurilish'),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingApi implements ApiClient {
  Map<String, dynamic>? query;
  Object? body;
  String? postPath;
  dynamic response;
  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(dynamic) parse,
  }) async {
    postPath = path;
    this.body = body;
    return parse(response);
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic) parse,
  }) async {
    this.query = query;
    return parse(response ?? {'items': <dynamic>[], 'next_cursor': null});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    // Real glyphs for the feed golden below.
    await (FontLoader('Manrope')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/Manrope-Variable.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });

  test('favorites reads the page envelope returned by the API', () async {
    final page = await TradeRepository(RecordingApi()).getFavorites();
    expect(page.items, isEmpty);
    expect(page.nextCursor, isNull);
  });
  test('favorites pages past the first batch with the cursor', () async {
    final api = RecordingApi()
      ..response = {'items': <dynamic>[], 'next_cursor': 'next-page'};
    final repository = TradeRepository(api);

    final first = await repository.getFavorites();
    expect(api.query, isNot(contains('cursor')));
    expect(first.nextCursor, 'next-page');

    await repository.getFavorites(cursor: first.nextCursor);
    expect(api.query?['cursor'], 'next-page');
  });
  test('reports and notification reads use the backend contract', () async {
    final api = RecordingApi();
    final repository = TradeRepository(api);
    await repository.reportUser('trader', 'Inappropriate');
    expect(api.postPath, '/reports');
    expect(api.body, {
      'target_type': 'user',
      'target_id': 'trader',
      'reason': 'other',
      'note': 'Inappropriate',
    });
    await repository.markRead(ids: ['notice']);
    expect(api.postPath, '/notifications/read');
    expect(api.body, {
      'ids': ['notice'],
    });
  });

  test(
    'feed uses backend filter names, minor units and supported sorting',
    () async {
      final api = RecordingApi();
      await ListingRepository(api).feed(
        categoryId: 'electronics',
        minPrice: 1000.25,
        maxPrice: 5000,
        sortBy: const FeedQuery().sortBy,
      );
      expect(api.query, {
        'tag': 'electronics',
        'min_value': '100025',
        'max_value': '500000',
        'sort': 'new',
      });
    },
  );

  testWidgets('active filters show as chips and drop in one tap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(RecordingApi()),
        regionsProvider.overrideWith((ref) async => ['Farg‘ona']),
        listingRepositoryProvider.overrideWithValue(Repository()),
      ],
    );
    container
        .read(feedQueryProvider.notifier)
        .setFilters(region: 'Farg‘ona', minPrice: 100000, sortBy: 'cheap');
    final router = buildRouter()..go('/home');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
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

    expect(find.byType(InputChip), findsNWidgets(3));
    expect(find.widgetWithText(InputChip, 'Farg‘ona'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Farg‘ona'),
        matching: find.byTooltip('Tozalash'),
      ),
    );
    await tester.pumpAndSettle();
    final query = container.read(feedQueryProvider);
    expect(query.region, isNull);
    expect(query.minPrice, 100000);
    expect(query.sortBy, 'cheap');
    expect(find.byType(InputChip), findsNWidgets(2));

    // Unmount, dispose the container (its providers own timers), and let
    // anything left run out before the binding checks for pending timers.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(seconds: 31));
  });

  test('a heart tap flips one card in place, keeping the page', () async {
    final repo = Repository()
      ..handler = (_, _) async =>
          models.Page(items: [item('a'), item('b')], nextCursor: 'more');
    final container = ProviderContainer(
      overrides: [listingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(feedProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(feedProvider.future);

    container.read(feedProvider.notifier).setFavorite('b', true);
    final state = container.read(feedProvider).requireValue;
    expect(state.items.map((i) => i.isFavorite), [false, true]);
    expect(state.cursor, 'more');
    expect(state.items.last.title, item('b').title);
  });

  test('pagination failure preserves rows and allows explicit retry', () async {
    final repo = Repository();
    var fail = true;
    repo.handler = (_, cursor) async {
      if (cursor == null) {
        return models.Page(items: [item('one')], nextCursor: 'next');
      }
      if (fail) throw StateError('offline');
      return models.Page(items: [item('one'), item('two')]);
    };
    final container = ProviderContainer(
      overrides: [listingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(feedProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(feedProvider.future);
    await container.read(feedProvider.notifier).loadMore();
    final failed = container.read(feedProvider).requireValue;
    expect(failed.items.single.id, 'one');
    expect(failed.loadingMore, false);
    expect(failed.loadMoreError, isNotNull);
    fail = false;
    await container.read(feedProvider.notifier).loadMore(retry: true);
    expect(container.read(feedProvider).requireValue.items.map((i) => i.id), [
      'one',
      'two',
    ]);
  });

  test('an old next-page response cannot overwrite a new search', () async {
    final delayed = Completer<models.Page<models.ListingCard>>();
    final repo = Repository()
      ..handler = (query, cursor) async {
        if (cursor != null) return delayed.future;
        return models.Page(
          items: [item(query == 'new' ? 'new' : 'old')],
          nextCursor: 'next',
        );
      };
    final container = ProviderContainer(
      overrides: [listingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(feedProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(feedProvider.future);
    final pending = container.read(feedProvider.notifier).loadMore();
    container.read(feedQueryProvider.notifier).search('new');
    await container.read(feedProvider.future);
    delayed.complete(models.Page(items: [item('stale')]));
    await pending;
    expect(container.read(feedProvider).requireValue.items.single.id, 'new');
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('feed fits ${size.width}x${size.height} text $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final router = buildRouter()..go('/home');
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              apiClientProvider.overrideWithValue(RecordingApi()),
              regionsProvider.overrideWith(
                (ref) async => ['Toshkent shahri', 'Farg‘ona'],
              ),
              listingRepositoryProvider.overrideWithValue(Repository()),
            ],
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              theme: AppTheme.light(),
              locale: const Locale('uz'),
              supportedLocales: L.supportedLocales,
              localizationsDelegates: const [
                L.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
        if (size == const Size(390, 844) && scale == 1.0) {
          // The phone feed as a whole: header, categories, two-column grid.
          // Asset images (the logo) decode asynchronously; wait for them so
          // the screenshot does not depend on timing.
          await tester.runAsync(() async {
            for (final element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/feed_phone.png'),
          );
        }
        if (size.width < 1000) {
          final bar = find.text('Asosiy');
          expect(
            tester.getRect(bar).bottom,
            lessThanOrEqualTo(size.height - 34),
          );
        }
        // A cleared query must stay cleared even when a debounce was pending.
        await tester.enterText(find.byType(TextField), 'MacBook');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byTooltip('Tozalash').first);
        await tester.pump(const Duration(milliseconds: 500));
        final context = tester.element(find.byType(TextField));
        expect(
          ProviderScope.containerOf(context).read(feedQueryProvider).search,
          '',
        );
        expect(tester.takeException(), isNull);
        if (size.width == 390 && scale == 1) {
          await tester.tap(find.byTooltip('Filterlar'));
          await tester.pumpAndSettle();
          final minField = find.byType(TextFormField).at(0);
          final maxField = find.byType(TextFormField).at(1);
          await tester.enterText(minField, '-1');
          await tester.tap(find.text("Qo'llash"));
          await tester.pumpAndSettle();
          expect(find.text('To‘g‘ri, musbat narx kiriting'), findsOneWidget);
          await tester.enterText(minField, '2000');
          await tester.enterText(maxField, '1000');
          await tester.tap(find.text("Qo'llash"));
          await tester.pumpAndSettle();
          expect(
            find.text('Eng kam narx eng yuqori narxdan katta bo‘lmasin.'),
            findsOneWidget,
          );
          await tester.enterText(maxField, '5000');
          await tester.tap(find.text("Qo'llash"));
          await tester.pumpAndSettle();
          expect(
            ProviderScope.containerOf(context).read(feedQueryProvider).minPrice,
            2000,
          );
          expect(
            ProviderScope.containerOf(context).read(feedQueryProvider).maxPrice,
            5000,
          );
          expect(tester.takeException(), isNull);
        }
        // Force the cards into view, including on landscape phones.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
        await tester.pumpAndSettle();
        expect(find.byType(ListingCardTile), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
