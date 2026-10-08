import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

class AnalyticsService {
  AnalyticsService(this._apiClient) {
    _sessionId = const Uuid().v4();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  final ApiClient _apiClient;
  late final String _sessionId;
  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;

  void logEvent(
    String kind, {
    String? targetType,
    String? targetId,
    Map<String, dynamic>? payload,
  }) {
    final event = <String, dynamic>{
      'kind': kind,
      'dedupe_key': const Uuid().v4(),
    };
    if (targetType != null) event['target_type'] = targetType;
    if (targetId != null) event['target_id'] = targetId;
    if (payload != null) event['payload'] = payload;

    _queue.add(event);
    if (_queue.length >= 100) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;
    final eventsToFlush = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await _apiClient.post<dynamic>(
        '/events',
        body: {
          'session_id': _sessionId,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'events': eventsToFlush,
        },
        parse: (data) => data,
      );
    } catch (e) {
      // Typically we might drop them or retry, for now we drop on failure.
    }
  }

  void dispose() {
    _timer?.cancel();
    flush();
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = AnalyticsService(apiClient);
  ref.onDispose(() => service.dispose());
  return service;
});
