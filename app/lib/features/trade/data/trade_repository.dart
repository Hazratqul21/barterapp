import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';

class TradeRepository {
  TradeRepository(this._api);

  final ApiClient _api;

  // ------------------------------------------------------------------ offers

  Future<Offer> sendOffer({
    required String listingId,
    required List<String> offeredListingIds,
    int cashDeltaMinor = 0,
    String? message,
  }) {
    return _api.post(
      '/offers',
      body: {
        'listing_id': listingId,
        'offered_listing_ids': offeredListingIds,
        'cash_delta_minor': cashDeltaMinor,
        if (message != null && message.trim().isNotEmpty) 'message': message,
      },
      parse: (data) => Offer.fromJson(data as Map<String, dynamic>),
    );
  }

  /// accept · decline · counter · complete · dispute. The server rejects any
  /// transition that is not legal from the offer's current state.
  Future<Offer> act(
    String offerId,
    String action, {
    int? cashDeltaMinor,
    String? message,
  }) {
    return _api.patch(
      '/offers/$offerId',
      body: {
        'action': action,
        'cash_delta_minor': ?cashDeltaMinor,
        if (message != null && message.trim().isNotEmpty) 'message': message,
      },
      parse: (data) => Offer.fromJson(data as Map<String, dynamic>),
    );
  }

  // -------------------------------------------------------------------- chat

  Future<List<ConversationSummary>> conversations() => _api.get(
    '/conversations',
    parse: (data) => (data as List)
        .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<ConversationDetail> conversation(String id) => _api.get(
    '/conversations/$id',
    parse: (data) => ConversationDetail.fromJson(data as Map<String, dynamic>),
  );

  Future<ChatMessage> send(String threadId, String body) => _api.post(
    '/conversations/$threadId/messages',
    body: {'body': body},
    parse: (data) => ChatMessage.fromJson(data as Map<String, dynamic>),
  );

  // ----------------------------------------------------- matches & the rest

  Future<List<TradeMatch>> matches() => _api.get(
    '/matches',
    parse: (data) => (data as List)
        .map((e) => TradeMatch.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<void> dismissMatch(String id) =>
      _api.post('/matches/$id/dismiss', parse: (_) {});

  Future<List<AppNotification>> notifications() => _api.get(
    '/notifications',
    parse: (data) => (data as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<void> markRead({List<String> ids = const []}) =>
      _api.post('/notifications/read', body: {'ids': ids}, parse: (_) {});

  Future<List<ListingCard>> myListings() => _api.get(
    '/me/listings',
    parse: (data) => (data as List)
        .map((e) => ListingCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<TraderProfile> trader(String id) => _api.get(
    '/users/$id',
    parse: (data) => TraderProfile.fromJson(data as Map<String, dynamic>),
  );

  Future<List<Review>> reviews(String userId) => _api.get(
    '/users/$userId/reviews',
    parse: (data) => (data as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<ListingCard>> traderListings(String userId) => _api.get(
    '/users/$userId/listings',
    parse: (data) => (data as List)
        .map((e) => ListingCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<({int trustScore, List<VerificationStep> steps})> verification() =>
      _api.get(
        '/me/verification',
        parse: (data) {
          final json = data as Map<String, dynamic>;
          return (
            trustScore: json['trust_score'] as int,
            steps: (json['steps'] as List)
                .map((e) => VerificationStep.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        },
      );

  Future<void> submitStep(String step) =>
      _api.post('/me/verification/$step', parse: (_) {});

  Future<List<PaymentCard>> cards() => _api.get(
    '/me/payment-methods',
    parse: (data) => (data as List)
        .map((e) => PaymentCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<PaymentCard>> makePrimary(String cardId) => _api.post(
    '/me/payment-methods/$cardId/primary',
    parse: (data) => (data as List)
        .map((e) => PaymentCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<List<PaymentCard>> removeCard(String cardId) => _api.delete(
    '/me/payment-methods/$cardId',
    parse: (data) => (data as List)
        .map((e) => PaymentCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Future<ListingDetail> createListing(Map<String, dynamic> body) => _api.post(
    '/listings',
    body: body,
    parse: (data) => ListingDetail.fromJson(data as Map<String, dynamic>),
  );

  Future<List<Settlement>> settlements() => _api.get(
    '/me/settlements',
    parse: (data) => (data as List)
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

final tradeRepositoryProvider = Provider<TradeRepository>(
  (ref) => TradeRepository(ref.watch(apiClientProvider)),
);

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) {
      if (!ref.watch(authStateProvider)) return Future.value(const []);
      return ref.watch(tradeRepositoryProvider).conversations();
    });

final conversationProvider = FutureProvider.autoDispose
    .family<ConversationDetail, String>((ref, id) {
      return ref.watch(tradeRepositoryProvider).conversation(id);
    });

final matchesProvider = FutureProvider.autoDispose<List<TradeMatch>>((ref) {
  if (!ref.watch(authStateProvider)) return Future.value(const []);
  return ref.watch(tradeRepositoryProvider).matches();
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
      if (!ref.watch(authStateProvider)) return Future.value(const []);
      return ref.watch(tradeRepositoryProvider).notifications();
    });

final myListingsProvider = FutureProvider.autoDispose<List<ListingCard>>((ref) {
  if (!ref.watch(authStateProvider)) return Future.value(const []);
  return ref.watch(tradeRepositoryProvider).myListings();
});

final traderProvider = FutureProvider.autoDispose
    .family<TraderProfile, String>(
      (ref, id) => ref.watch(tradeRepositoryProvider).trader(id),
    );

final traderReviewsProvider = FutureProvider.autoDispose
    .family<List<Review>, String>(
      (ref, id) => ref.watch(tradeRepositoryProvider).reviews(id),
    );

final traderListingsProvider = FutureProvider.autoDispose
    .family<List<ListingCard>, String>(
      (ref, id) => ref.watch(tradeRepositoryProvider).traderListings(id),
    );

final settlementsProvider =
    FutureProvider.autoDispose<List<Settlement>>((ref) {
      if (!ref.watch(authStateProvider)) return Future.value(const []);
      return ref.watch(tradeRepositoryProvider).settlements();
    });

/// A live event from the server: a new message, or the peer typing.
sealed class LiveEvent {
  const LiveEvent(this.conversationId);
  final String conversationId;
}

class MessageArrived extends LiveEvent {
  const MessageArrived(super.conversationId, this.message);
  final ChatMessage message;
}

class PeerTyping extends LiveEvent {
  const PeerTyping(super.conversationId);
}

/// The single WebSocket for the whole app. Screens listen; nothing else knows
/// there is a socket at all.
class LiveChannel {
  LiveChannel(this._session);

  final SessionStore _session;
  WebSocketChannel? _channel;
  final _events = StreamController<LiveEvent>.broadcast();

  Stream<LiveEvent> get events => _events.stream;

  void connect() {
    final token = _session.accessToken;
    if (token == null || _channel != null) return;

    final base = defaultApiBaseUrl().replaceFirst(RegExp('^http'), 'ws');
    _channel = WebSocketChannel.connect(Uri.parse('$base/ws?token=$token'));
    _channel!.stream.listen(
      (raw) {
        final json = jsonDecode(raw as String) as Map<String, dynamic>;
        final id = json['conversation_id'] as String?;
        if (id == null) return;

        switch (json['type']) {
          case 'message':
            _events.add(
              MessageArrived(
                id,
                ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
              ),
            );
          case 'typing':
            _events.add(PeerTyping(id));
        }
      },
      onDone: _reset,
      onError: (_) => _reset(),
      cancelOnError: true,
    );
  }

  void typing(String conversationId) {
    _channel?.sink.add(
      jsonEncode({'type': 'typing', 'conversation_id': conversationId}),
    );
  }

  void _reset() {
    _channel = null;
  }

  void dispose() {
    _channel?.sink.close();
    _events.close();
  }
}

final liveChannelProvider = Provider<LiveChannel>((ref) {
  final channel = LiveChannel(ref.watch(sessionStoreProvider));
  ref.onDispose(channel.dispose);
  return channel;
});
