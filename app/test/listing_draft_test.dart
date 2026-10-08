import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/trade/data/listing_draft.dart';
import 'package:barter_app/features/feed/presentation/listing_card_tile.dart';
import 'package:barter_app/features/trade/presentation/create_listing_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A half-written listing used to vanish on an incoming call or a closed app.
ListingDraft _draft({DateTime? savedAt, List<String> photos = const []}) =>
    ListingDraft(
      savedAt: savedAt ?? DateTime.now(),
      step: 1,
      photos: photos,
      tag: 'electronics',
      fields: const {
        'title': {'uz': 'Noutbuk', 'ru': 'Ноутбук', 'en': 'Laptop'},
      },
      value: '5000000',
      cashOk: true,
    );

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<void> _pumpCreate(WidgetTester tester, SharedPreferences prefs) async {
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
        home: const CreateListingPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

  group('ListingDraft', () {
    test('survives a JSON round trip', () {
      final draft = _draft(photos: ['https://x/1.jpg', 'https://x/2.jpg']);
      final back = ListingDraft.fromJson(draft.toJson())!;
      expect(back.toJson(), draft.toJson());
    });

    test('rejects data it did not write', () {
      expect(ListingDraft.fromJson('nope'), isNull);
      expect(ListingDraft.fromJson(<String, dynamic>{'step': 1}), isNull);
    });

    test('an untouched form is empty', () {
      expect(ListingDraft(savedAt: DateTime.now()).isEmpty, isTrue);
      expect(
        ListingDraft(
          savedAt: DateTime.now(),
          fields: const {
            'title': {'uz': '  '},
          },
        ).isEmpty,
        isTrue,
      );
      expect(_draft().isEmpty, isFalse);
    });

    test('photos expire before the server sweeps their uploads', () {
      final now = DateTime.now();
      final fresh = _draft(photos: ['u'], savedAt: now);
      final old = _draft(
        photos: ['u'],
        savedAt: now.subtract(const Duration(hours: 6)),
      );
      expect(fresh.photosExpired(now), isFalse);
      expect(old.photosExpired(now), isTrue);
      final kept = old.withoutPhotos();
      expect(kept.photos, isEmpty);
      expect(kept.step, 0);
      expect(kept.fields, old.fields);
    });
  });

  group('ListingDraftStore', () {
    test('saves, loads and clears', () async {
      final store = ListingDraftStore(await _prefs());
      expect(store.load(), isNull);
      await store.save(_draft());
      expect(store.load()?.value, '5000000');
      await store.clear();
      expect(store.load(), isNull);
    });

    test('saving an empty form removes the stored draft', () async {
      final store = ListingDraftStore(await _prefs());
      await store.save(_draft());
      await store.save(ListingDraft(savedAt: DateTime.now()));
      expect(store.load(), isNull);
    });

    test('corrupt storage reads as no draft', () async {
      final store = ListingDraftStore(
        await _prefs({ListingDraftStore.key: '{not json'}),
      );
      expect(store.load(), isNull);
    });
  });

  group('CreateListingPage', () {
    testWidgets('offers the saved draft and restores it', (tester) async {
      final prefs = await _prefs();
      await ListingDraftStore(prefs).save(_draft());
      await _pumpCreate(tester, prefs);

      expect(find.text('Qoralama topildi'), findsOneWidget);
      await tester.tap(find.text('Davom ettirish'));
      await tester.pumpAndSettle();

      // Without photos the draft cannot stay past the first step.
      expect(find.text('Qoralama topildi'), findsNothing);
      expect(
        ListingDraftStore(prefs).load()?.fields['title']?['uz'],
        'Noutbuk',
      );
    });

    testWidgets('starting over discards the draft', (tester) async {
      final prefs = await _prefs();
      await ListingDraftStore(prefs).save(_draft());
      await _pumpCreate(tester, prefs);

      await tester.tap(find.text('Yangidan boshlash'));
      await tester.pumpAndSettle();
      expect(ListingDraftStore(prefs).load(), isNull);
    });

    testWidgets('steps are labelled and the last one previews the card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await _prefs();
      // A finished draft on the last step; an empty URL is an uploaded photo
      // that renders the local placeholder (no network in tests).
      await ListingDraftStore(prefs).save(
        ListingDraft(
          savedAt: DateTime.now(),
          step: 3,
          photos: const [''],
          tag: 'electronics',
          fields: {
            for (final f in [
              'title',
              'description',
              'category',
              'condition',
              'quantity',
            ])
              f: const {'uz': 'Noutbuk', 'ru': 'Ноутбук', 'en': 'Laptop'},
            'wants': const {'uz': 'Telefon', 'ru': 'Телефон', 'en': 'Phone'},
          },
          value: '5000000',
        ),
      );
      await _pumpCreate(tester, prefs);
      await tester.tap(find.text('Davom ettirish'));
      await tester.pumpAndSettle();

      for (final label in ['Suratlar', 'Beraman', 'Olaman', 'Qiymat']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Lentada shunday ko‘rinadi'), findsOneWidget);
      expect(find.byType(ListingCardTile), findsOneWidget);
      expect(find.text('Noutbuk'), findsWidgets);
      expect(find.text('Telefon'), findsOneWidget);
      await expectLater(
        find.byType(CreateListingPage),
        matchesGoldenFile('goldens/create_listing_preview.png'),
      );

      // A finished step is a shortcut back.
      await tester.tap(find.text('Beraman'));
      await tester.pumpAndSettle();
      expect(find.text('Lentada shunday ko‘rinadi'), findsNothing);
    });

    testWidgets('no question without a draft', (tester) async {
      await _pumpCreate(tester, await _prefs());
      expect(find.text('Qoralama topildi'), findsNothing);
    });
  });
}
