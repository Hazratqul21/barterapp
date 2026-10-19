import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';

/// What a tariff buys.
enum TariffKind {
  /// N more listings.
  listingPack,

  /// A listing on top of the feed for N days.
  boost;

  static TariffKind parse(String value) =>
      value == 'boost' ? TariffKind.boost : TariffKind.listingPack;
}

/// A price the admin set. Read from the server every time: prices are not
/// decided yet and change, so nothing here is baked into a release.
class Tariff {
  const Tariff({
    required this.code,
    required this.kind,
    required this.title,
    required this.price,
    required this.finalPrice,
    required this.discountPercent,
    required this.quantity,
    this.durationDays,
    this.discountUntil,
  });

  final String code;
  final TariffKind kind;
  final String title;
  final Money price;
  final Money finalPrice;
  final int discountPercent;
  final DateTime? discountUntil;
  final int quantity;
  final int? durationDays;

  bool get discounted => finalPrice.minor < price.minor;

  factory Tariff.fromJson(Map<String, dynamic> json) => Tariff(
    code: json['code'] as String,
    kind: TariffKind.parse(json['kind'] as String),
    title: json['title'] as String,
    price: Money(minor: json['price_minor'] as int, currency: 'UZS'),
    finalPrice: Money(minor: json['final_price_minor'] as int, currency: 'UZS'),
    discountPercent: json['discount_percent'] as int? ?? 0,
    discountUntil: json['discount_until'] == null
        ? null
        : DateTime.parse(json['discount_until'] as String),
    quantity: json['quantity'] as int? ?? 1,
    durationDays: json['duration_days'] as int?,
  );
}

enum OrderStatus {
  pending,
  paid,
  cancelled;

  static OrderStatus parse(String value) => switch (value) {
    'paid' => OrderStatus.paid,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.pending,
  };
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.kind,
    required this.createdAt,
    this.quantity = 1,
    this.durationDays,
    this.listingId,
    this.checkoutUrl,
    this.paidAt,
  });

  final String id;
  final String title;
  final Money amount;
  final OrderStatus status;
  final TariffKind kind;
  final DateTime createdAt;
  final int quantity;
  final int? durationDays;
  final String? listingId;

  /// The Payme page. Only on a pending order — card number, expiry and the
  /// SMS code are typed there, never into this app.
  final String? checkoutUrl;
  final DateTime? paidAt;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: Money(minor: json['amount_minor'] as int, currency: 'UZS'),
    status: OrderStatus.parse(json['status'] as String),
    kind: TariffKind.parse(json['kind'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    quantity: json['quantity'] as int? ?? 1,
    durationDays: json['duration_days'] as int?,
    listingId: json['listing_id'] as String?,
    checkoutUrl: json['checkout_url'] as String?,
    paidAt: json['paid_at'] == null
        ? null
        : DateTime.parse(json['paid_at'] as String),
  );
}

class BillingStatus {
  const BillingStatus({
    required this.paymentsEnabled,
    required this.listingFeeEnabled,
    required this.freeListingsLeft,
  });

  final bool paymentsEnabled;
  final bool listingFeeEnabled;
  final int freeListingsLeft;

  factory BillingStatus.fromJson(Map<String, dynamic> json) => BillingStatus(
    paymentsEnabled: json['payments_enabled'] as bool? ?? false,
    listingFeeEnabled: json['listing_fee_enabled'] as bool? ?? false,
    freeListingsLeft: json['free_listings_left'] as int? ?? 0,
  );
}

class BillingRepository {
  BillingRepository(this._api);

  final ApiClient _api;

  Future<BillingStatus> status() => _api.get(
    '/payments/status',
    parse: (data) => BillingStatus.fromJson(data as Map<String, dynamic>),
  );

  Future<List<Tariff>> tariffs({TariffKind? kind}) => _api.get(
    '/payments/products',
    query: kind == null
        ? null
        : {'kind': kind == TariffKind.boost ? 'boost' : 'listing_pack'},
    parse: (data) => [
      for (final row in data as List)
        Tariff.fromJson(row as Map<String, dynamic>),
    ],
  );

  Future<PaymentOrder> createOrder(String tariffCode, {String? listingId}) =>
      _api.post(
        '/payments/orders',
        body: {'product_code': tariffCode, 'listing_id': ?listingId},
        parse: (data) => PaymentOrder.fromJson(data as Map<String, dynamic>),
      );

  Future<PaymentOrder> order(String id) => _api.get(
    '/payments/orders/$id',
    parse: (data) => PaymentOrder.fromJson(data as Map<String, dynamic>),
  );

  Future<List<PaymentOrder>> orders() => _api.get(
    '/payments/orders',
    parse: (data) => [
      for (final row in data as List)
        PaymentOrder.fromJson(row as Map<String, dynamic>),
    ],
  );
}

final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(ref.watch(apiClientProvider)),
);

final billingStatusProvider = FutureProvider.autoDispose<BillingStatus?>((
  ref,
) async {
  if (!ref.watch(authStateProvider)) return null;
  return ref.watch(billingRepositoryProvider).status();
});

final tariffsProvider = FutureProvider.autoDispose
    .family<List<Tariff>, TariffKind?>(
      (ref, kind) => ref.watch(billingRepositoryProvider).tariffs(kind: kind),
    );

final myOrdersProvider = FutureProvider.autoDispose<List<PaymentOrder>>((
  ref,
) async {
  if (!ref.watch(authStateProvider)) return const [];
  return ref.watch(billingRepositoryProvider).orders();
});
