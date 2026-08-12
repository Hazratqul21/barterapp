import 'dart:async';

import 'package:barter_app/core/network/api_client.dart';
import 'package:barter_app/features/trade/data/trade_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A socket whose lifetime the test controls: [die] is the network going away.
class _FakeSocket implements WebSocketChannel {
  _FakeSocket() {
    _sink = _FakeSink(_incoming);
  }

  final _incoming = StreamController<dynamic>();
  late final _FakeSink _sink;

  /// What a dropped connection looks like to a listener: the stream simply
  /// ends. No error, no warning — which is why the first version of
  /// `LiveChannel` treated it as a normal shutdown and never dialled again.
  void die() => _incoming.close();

  void deliver(String frame) => _incoming.add(frame);

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._owner);

  final StreamController<dynamic> _owner;
  final sent = <dynamic>[];

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_owner.isClosed) await _owner.close();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SessionStore session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'access_token': 'test-token'});
    session = SessionStore(await SharedPreferences.getInstance());
  });

  test('a dropped socket is dialled again', () {
    fakeAsync((async) {
      final opened = <_FakeSocket>[];
      final channel = LiveChannel(
        session,
        connector: (_) {
          final socket = _FakeSocket();
          opened.add(socket);
          return socket;
        },
      );

      channel.connect();
      expect(opened, hasLength(1), reason: 'connect opens one socket');

      // The network goes away, as it does every time the screen locks.
      opened.single.die();
      async.flushMicrotasks();
      expect(channel.isConnected, isFalse);

      // This is the regression: before the fix, nothing happened here, ever.
      async.elapse(const Duration(seconds: 2));
      expect(opened, hasLength(2), reason: 'the socket is re-opened');
      expect(channel.isConnected, isTrue);

      channel.dispose();
    });
  });

  test('repeated failures back off instead of hammering the server', () {
    fakeAsync((async) {
      var attempts = 0;
      final channel = LiveChannel(
        session,
        connector: (_) {
          attempts++;
          final socket = _FakeSocket();
          // Fails the moment it is listened to — a server that is down.
          scheduleMicrotask(socket.die);
          return socket;
        },
      );

      channel.connect();
      async.elapse(const Duration(seconds: 30));

      // Six steps — 1, 2, 5, 10, 20, 30 — reach 30s of waiting after the
      // seventh dial. A fixed one-second retry would have made 30 by now.
      expect(attempts, lessThan(10), reason: 'backoff is applied');
      expect(attempts, greaterThan(2), reason: 'it does keep trying');

      channel.dispose();
    });
  });

  test('a delivered frame resets the backoff', () {
    fakeAsync((async) {
      final opened = <_FakeSocket>[];
      final channel = LiveChannel(
        session,
        connector: (_) {
          final socket = _FakeSocket();
          opened.add(socket);
          return socket;
        },
      );

      channel.connect();

      // Two failures in a row push the wait out to five seconds.
      opened.last.die();
      async.elapse(const Duration(seconds: 2));
      opened.last.die();
      async.elapse(const Duration(seconds: 5));
      expect(opened, hasLength(3));

      // A frame arrives: this connection is healthy, whatever came before.
      opened.last.deliver(
        '{"type":"typing","conversation_id":"c1"}',
      );
      async.flushMicrotasks();

      // So the next drop is treated as the first one — one second, not five.
      opened.last.die();
      async.elapse(const Duration(seconds: 2));
      expect(opened, hasLength(4), reason: 'backoff started over');

      channel.dispose();
    });
  });

  test('a signed-out session stops retrying', () async {
    SharedPreferences.setMockInitialValues({});
    final anonymous = SessionStore(await SharedPreferences.getInstance());

    fakeAsync((async) {
      var attempts = 0;
      final channel = LiveChannel(
        anonymous,
        connector: (_) {
          attempts++;
          return _FakeSocket();
        },
      );

      channel.connect();
      async.elapse(const Duration(minutes: 5));

      // Without a token every attempt would be refused, so retrying forever
      // would be a background loop that can never succeed.
      expect(attempts, 0);

      channel.dispose();
    });
  });

  test('messages reach listeners as events', () {
    fakeAsync((async) {
      late _FakeSocket socket;
      final channel = LiveChannel(
        session,
        connector: (_) => socket = _FakeSocket(),
      );

      final seen = <LiveEvent>[];
      channel.events.listen(seen.add);
      channel.connect();

      socket.deliver(
        '{"type":"message","conversation_id":"c1","message":'
        '{"id":"m1","body":"salom","created_at":"2026-08-12T10:00:00Z",'
        '"sender_id":"u1","is_mine":false}}',
      );
      async.flushMicrotasks();

      expect(seen, hasLength(1));
      expect(seen.single, isA<MessageArrived>());
      expect((seen.single as MessageArrived).message.body, 'salom');

      channel.dispose();
    });
  });
}
