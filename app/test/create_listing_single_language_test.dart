import 'dart:io';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/auth/data/auth_repository.dart'
    show regionsProvider;
import 'package:barter_app/features/trade/data/listing_draft.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:barter_app/features/trade/presentation/create_listing_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Publishing used to need every text field in Uzbek, Russian and English
/// before "Next" would enable. One language is enough now.
class _Repo implements TradeRepository {
  Map<String, dynamic>? sent;

  @override
  Future<ListingDetail> createListing(Map<String, dynamic> body) {
    sent = body;
    return Future.error(StateError('not under test'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  testWidgets('one language fills the form and is what gets sent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // A draft with a photo, saved by the old three-language form: its Uzbek
    // title must come back into the single box.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await ListingDraftStore(prefs).save(
      ListingDraft(
        savedAt: DateTime.now(),
        step: 1,
        photos: const [''],
        tag: 'agri',
        fields: const {
          'title': {'uz': 'Guruch 2 tonna', 'ru': '', 'en': ''},
        },
      ),
    );
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tradeRepositoryProvider.overrideWithValue(repo),
          regionsProvider.overrideWith((ref) async => const ['Toshkent']),
        ],
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
    await tester.tap(find.text('Davom ettirish'));
    await tester.pumpAndSettle();

    expect(find.text('UZ'), findsNothing, reason: 'no language tabs');
    expect(find.text('Guruch 2 tonna'), findsOneWidget);

    Future<void> type(String label, String text) async {
      await tester.enterText(find.widgetWithText(TextField, label), text);
      await tester.pump();
    }

    FilledButton next() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Keyingisi'),
    );

    await type('Tavsif', 'Lazer navi');
    await type('Holati', 'Yangi hosil');
    expect(next().onPressed, isNull);
    await type('Miqdori', '2 t');
    expect(next().onPressed, isNotNull, reason: 'one language is enough');

    await tester.tap(find.text('Keyingisi'));
    await tester.pumpAndSettle();
    await type('Nimaga almashtirasiz', 'Nasos');
    await tester.tap(find.text('Keyingisi'));
    await tester.pumpAndSettle();
    await type('Taxminiy qiymat', '14000000');
    await tester.ensureVisible(find.text('E’lonni joylash'));
    await tester.tap(find.text('E’lonni joylash'));
    await tester.pumpAndSettle();

    final body = repo.sent!;
    expect(body['title'], {'uz': 'Guruch 2 tonna'});
    expect(body['wants'], [
      {'uz': 'Nasos'},
    ]);
    // The category is the picked type, in every language.
    expect(body['category'], {
      'uz': 'Qishloq xo‘jaligi',
      'ru': isNotEmpty,
      'en': isNotEmpty,
    });
  });
}
