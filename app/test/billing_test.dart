import 'dart:io';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/core/theme/app_theme.dart';
import 'package:barter_app/features/billing/data/billing_repository.dart';
import 'package:barter_app/features/billing/presentation/order_status_page.dart';
import 'package:barter_app/features/billing/presentation/payme_button.dart';
import 'package:barter_app/features/billing/presentation/tariffs_page.dart';
import 'package:barter_app/l10n/app_localizations.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Payme pays in the browser; the app only has to price the plans, hand the
/// person over and notice when the server says the order is paid.
class _Repo implements BillingRepository {
  final created = <String>[];
  var polls = 0;

  static PaymentOrder _order(OrderStatus status) => PaymentOrder(
    id: 'o1',
    title: '3 ta e’lon',
    amount: const Money(minor: 1200000, currency: 'UZS'),
    status: status,
    kind: TariffKind.listingPack,
    quantity: 3,
    createdAt: DateTime(2026, 10, 19),
    checkoutUrl: status == OrderStatus.pending
        ? 'https://test.paycom.uz/abc'
        : null,
  );

  @override
  Future<BillingStatus> status() async => const BillingStatus(
    paymentsEnabled: true,
    listingFeeEnabled: true,
    freeListingsLeft: 0,
  );

  @override
  Future<List<Tariff>> tariffs({TariffKind? kind}) async => [
    const Tariff(
      code: 'pack3',
      kind: TariffKind.listingPack,
      title: '3 ta e’lon',
      price: Money(minor: 1500000, currency: 'UZS'),
      finalPrice: Money(minor: 1200000, currency: 'UZS'),
      discountPercent: 20,
      quantity: 3,
    ),
  ];

  @override
  Future<PaymentOrder> createOrder(String code, {String? listingId}) async {
    created.add(code);
    return _order(OrderStatus.pending);
  }

  // Pending on the first look, paid on the next: Payme confirmed meanwhile.
  @override
  Future<PaymentOrder> order(String id) async =>
      _order(polls++ == 0 ? OrderStatus.pending : OrderStatus.paid);

  @override
  Future<List<PaymentOrder>> orders() async => const [];

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

  testWidgets('a plan is priced, paid through Payme and confirmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    SharedPreferences.setMockInitialValues({'access_token': 't'});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repo();
    final opened = <String>[];

    final router = GoRouter(
      initialLocation: '/tariffs',
      routes: [
        GoRoute(path: '/tariffs', builder: (_, _) => const TariffsPage()),
        GoRoute(
          path: '/payments/order/:id',
          builder: (_, s) => OrderStatusPage(orderId: s.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          billingRepositoryProvider.overrideWithValue(repo),
          checkoutLauncherProvider.overrideWithValue((url) async {
            opened.add(url);
            return true;
          }),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('uz'),
          supportedLocales: L.supportedLocales,
          localizationsDelegates: const [
            L.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0 ta bepul e’lon qoldi'), findsOneWidget);
    expect(find.text('−20%'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets, reason: 'discounted price');
    expect(find.textContaining('15'), findsWidgets, reason: 'struck-through');
    expect(find.bySemanticsLabel('Payme orqali to‘lash'), findsOneWidget);

    await tester.tap(find.byType(PaymeButton));
    await tester.pumpAndSettle();

    expect(repo.created, ['pack3']);
    expect(opened, ['https://test.paycom.uz/abc']);
    expect(find.text('To‘lov kutilmoqda'), findsOneWidget);

    // The page asks again on its own and sees the payment land.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('To‘lov qabul qilindi'), findsOneWidget);
    expect(find.text('Hisobingizga 3 ta e’lon qo‘shildi.'), findsOneWidget);
    semantics.dispose();
  });
}
