import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:barter_app/features/trade/presentation/inbox_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the inbox asks the server to do.
class _Api implements ApiClient {
  final calls = <String>[];

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(dynamic) parse,
  }) async {
    calls.add('POST $path');
    return parse(null);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    required T Function(dynamic) parse,
  }) async {
    calls.add('DELETE $path');
    return parse(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConversationSummary _thread(String id) => ConversationSummary.fromJson({
  'id': id,
  'peer': {'id': 'p$id', 'name': 'Aziz', 'is_verified': true},
  'offer_id': 'o$id',
  'offer_status': 'pending',
  'deal_summary': 'Noutbuk · Telefon',
  'gives': 'Noutbuk',
  'receives': 'Telefon',
  'cash': {'minor': 0, 'currency': 'UZS'},
  'last_message': 'Salom',
  'last_message_at': '2026-10-06T09:00:00Z',
  'unread': 0,
});

void main() {
  test('archived flag parses, defaulting to false', () {
    expect(_thread('a').archived, isFalse);
  });

  testWidgets('swipe archives the thread, with undo', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'access_token': 't'});
    final prefs = await SharedPreferences.getInstance();
    final api = _Api();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tradeRepositoryProvider.overrideWithValue(TradeRepository(api)),
          conversationsProvider.overrideWith((ref) async => [_thread('t1')]),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const InboxPage())],
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

    await tester.drag(find.text('Aziz'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(api.calls, contains('POST /conversations/t1/archive'));
    expect(find.text('Suhbat arxivlandi'), findsOneWidget);

    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /conversations/t1/archive'));
  });
}
