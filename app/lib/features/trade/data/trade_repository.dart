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
        'cash_delta_minor': cashDeltaMinor,
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

  /// Rate the other side of a finished trade.
  ///
  /// The server decides who may write: only a participant, only once, only
  /// after the offer reached `completed`.
  Future<Review> writeReview({
    required String offerId,
    required int rating,
    required String body,
  }) {
    return _api.post(
      '/reviews',
      body: {'offer_id': offerId, 'rating': rating, 'body': body},
      parse: (data) => Review.fromJson(data as Map<String, dynamic>),
    );
  }

  /// What this user already wrote about a deal, so the screen asks only once.
  Future<Review?> myReviewFor(String offerId) => _api.get(
    '/offers/$offerId/review',
    parse: (data) => data == null
        ? null
        : Review.fromJson(data as Map<String, dynamic>),
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

  /// Upload a listing photo and get its hosted URL.
  ///
  /// The server re-encodes it: rotated upright, capped at 1600px, stripped of
  /// EXIF — so nothing here has to care what came out of the camera.
  Future<String> uploadPhoto({
    required List<int> bytes,
    required String filename,
    void Function(int sent, int total)? onProgress,
  }) {
    return _api.upload(
      '/uploads',
      bytes: bytes,
      filename: filename,
      onProgress: onProgress,
      parse: (data) => (data as Map<String, dynamic>)['url'] as String,
    );
  }

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

/// The review this user already left on a given offer, if any.
final myReviewProvider = FutureProvider.autoDispose.family<Review?, String>(
  (ref, offerId) => ref.watch(tradeRepositoryProvider).myReviewFor(offerId),
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
///
/// It reconnects on its own, and that is the whole reason this class is more
/// than a `WebSocketChannel.connect` call. A phone drops its socket constantly:
/// the screen locks, the app is backgrounded, wifi hands over to 4G, a tunnel
/// swallows the signal. The first version treated every one of those as the
/// end — `onDone` cleared the field and nothing ever dialled again — so a chat
/// left open for two minutes stopped receiving messages and gave no sign of it.
/// The reader saw a conversation that had simply gone quiet.
class LiveChannel {
  LiveChannel(this._session, {WebSocketChannel Function(Uri)? connector})
    : _connect = connector ?? WebSocketChannel.connect;

  /// How a socket is opened. Injectable so the reconnect behaviour can be
  /// tested without a server — the bug this class exists to fix only appears
  /// when a connection drops, which is the one thing that is hard to arrange
  /// for real.
  final WebSocketChannel Function(Uri) _connect;

  final SessionStore _session;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _retry;
  final _events = StreamController<LiveEvent>.broadcast();

  /// How many times in a row the socket has failed. Resets the moment a frame
  /// arrives, because a connection that delivered something was a real one.
  int _attempt = 0;

  /// Set by [dispose] so a retry already in flight does not resurrect the
  /// socket after the provider is gone.
  bool _closed = false;

  /// True while a socket is open or being dialled — screens use it to avoid
  /// showing "live" state they are not actually getting.
  bool get isConnected => _channel != null;

  Stream<LiveEvent> get events => _events.stream;

  /// Back off so a server that is down is not hammered by every phone at once,
  /// but stay responsive for the common case — a brief handover — where the
  /// first retry a second later succeeds. Capped at half a minute: beyond that
  /// the person has put the phone down anyway.
  Duration get _backoff {
    const steps = [1, 2, 5, 10, 20, 30];
    return Duration(seconds: steps[_attempt.clamp(0, steps.length - 1)]);
  }

  void connect() {
    if (_closed || _channel != null) return;
    final token = _session.accessToken;
    if (token == null) return;

    _retry?.cancel();

    final base = defaultApiBaseUrl().replaceFirst(RegExp('^http'), 'ws');
    final channel = _connect(Uri.parse('$base/ws?token=$token'));
    _channel = channel;

    _socketSub = channel.stream.listen(
      (raw) {
        // A frame arrived, so whatever went wrong before is over.
        _attempt = 0;

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
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
      cancelOnError: true,
    );
  }

  /// Drop the dead socket and dial again after a pause.
  ///
  /// A signed-out session is the one case that must not retry — the token is
  /// gone, so every attempt would be refused forever.
  void _scheduleReconnect() {
    _teardownSocket();
    if (_closed || _session.accessToken == null) return;

    final wait = _backoff;
    _attempt++;
    _retry?.cancel();
    _retry = Timer(wait, connect);
  }

  /// Reconnect now rather than waiting out the backoff.
  ///
  /// Called when the app returns to the foreground: the socket almost certainly
  /// died while it was away, and the person is looking at the screen right now.
  void resume() {
    if (_closed) return;
    _attempt = 0;
    if (_channel == null) {
      _retry?.cancel();
      connect();
    }
  }

  void typing(String conversationId) {
    _channel?.sink.add(
      jsonEncode({'type': 'typing', 'conversation_id': conversationId}),
    );
  }

  void _teardownSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    _channel = null;
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _socketSub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}

final liveChannelProvider = Provider<LiveChannel>((ref) {
  final channel = LiveChannel(ref.watch(sessionStoreProvider));
  ref.onDispose(channel.dispose);
  return channel;
});
