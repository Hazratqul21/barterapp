import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:barter_app/shared/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// F02 on the client: the offer carries hold, confirmations and dispute;
/// the dispute request carries its reason.
Map<String, dynamic> _card(String id) => {
  'id': id,
  'tag': 'electronics',
  'title': 'T$id',
  'image_alt': '',
  'wants_summary': 'x',
  'value': {'minor': 100, 'currency': 'UZS'},
  'cash_ok': true,
  'is_premium': false,
  'posted_at': '2026-10-06T09:00:00Z',
  'owner': {'id': 'o', 'name': 'O', 'is_verified': false},
};

Map<String, dynamic> _offer({Map<String, dynamic>? extra}) => {
  'id': 'off',
  'status': 'accepted',
  'cash_delta_minor': 0,
  'currency': 'UZS',
  'created_at': '2026-10-06T09:00:00Z',
  'is_mine': true,
  'counterparty': {'id': 'p', 'name': 'Aziz', 'is_verified': true},
  'wanted': _card('w'),
  'offered': [_card('m')],
  ...?extra,
};

class _Api implements ApiClient {
  Object? body;

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(dynamic) parse,
  }) async {
    this.body = body;
    return parse(_offer());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('older servers: no hold, no confirmations, no dispute', () {
    final o = Offer.fromJson(_offer());
    expect(o.reservedUntil, isNull);
    expect(o.confirmedByMe, isFalse);
    expect(o.dispute, isNull);
  });

  test('hold, my confirmation and a dispute are read', () {
    final o = Offer.fromJson(
      _offer(
        extra: {
          'status': 'disputed',
          'reserved_until': null,
          'confirmed_by_me': true,
          'confirmed_by_peer': false,
          'dispute': {
            'id': 'd',
            'reason': 'no_show',
            'status': 'escalated',
            'resolution': null,
            'decided_by_rule': 'over_limit',
            'opened_by_me': true,
            'created_at': '2026-10-06T10:00:00Z',
          },
        },
      ),
    );
    expect(o.status, OfferStatus.disputed);
    expect(o.confirmedByMe, isTrue);
    expect(o.dispute!.reason, 'no_show');
    expect(o.dispute!.resolved, isFalse);
    expect(o.dispute!.decidedByRule, 'over_limit');
  });

  test('a dispute request sends its reason and trimmed note', () async {
    final api = _Api();
    await TradeRepository(api).act(
      'off',
      'dispute',
      disputeReason: 'no_show',
      disputeNote: '  kelmadi ',
    );
    expect(api.body, {
      'action': 'dispute',
      'cash_delta_minor': null,
      'dispute_reason': 'no_show',
      'dispute_note': 'kelmadi',
    });
  });

  test('confirm sends no dispute fields', () async {
    final api = _Api();
    await TradeRepository(api).act('off', 'confirm');
    expect(api.body, {'action': 'confirm', 'cash_delta_minor': null});
  });
}
