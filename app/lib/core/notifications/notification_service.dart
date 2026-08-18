import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Registers this installation for push, when there is a Firebase project to
/// register it with.
///
/// Two things went wrong here before, and both were invisible:
///
/// 1. `FirebaseMessaging.instance` was reached unconditionally. Without a
///    `GoogleService-Info.plist` there is no default app, so the getter threw
///    `[core/no-app]` on the very first frame — an unhandled exception on
///    every launch. `Firebase.initializeApp()` was already wrapped in a
///    try/catch upstream, which hid the cause and left the symptom.
///
/// 2. The request body used `fcm_token`, which the API does not have. The
///    field it requires is `token`, so every registration came back 422 —
///    and the `catch` swallowed it, so push simply never worked and nothing
///    said so.
class NotificationService {
  NotificationService(this._apiClient);

  final ApiClient _apiClient;

  /// Whether a Firebase app actually exists.
  ///
  /// The project is configured per platform and may legitimately be absent —
  /// a developer checkout has no keys, and the app has to run anyway. This is
  /// the difference between "push is off" and "the app crashes".
  bool get _configured => Firebase.apps.isNotEmpty;

  /// What the API expects in `platform`; the value used to be the literal
  /// `'ios'`, so an Android handset registered itself as an iPhone and would
  /// have had its notifications posted to the wrong service.
  String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  }

  Future<void> init({String locale = 'uz'}) async {
    if (!_configured) {
      debugPrint(
        'Push o‘chirilgan: Firebase sozlanmagan '
        '(GoogleService-Info.plist / google-services.json yo‘q).',
      );
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();

      const allowed = {
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      };
      if (!allowed.contains(settings.authorizationStatus)) return;

      final token = await messaging.getToken();
      if (token == null) return;

      await _register(token, locale);

      // A token is rotated by the OS — on reinstall, restore, or at its own
      // discretion. Without this the server keeps the stale one and the
      // person quietly stops receiving anything.
      messaging.onTokenRefresh.listen((fresh) => _register(fresh, locale));
    } catch (e) {
      debugPrint('Push sozlanmadi: $e');
    }
  }

  Future<void> _register(String token, String locale) async {
    try {
      await _apiClient.post<dynamic>(
        '/devices',
        body: {'token': token, 'platform': _platform, 'locale': locale},
        parse: (data) => data,
      );
    } catch (e) {
      // Logged rather than ignored: a silent failure here is why push looked
      // wired up for weeks while no device was ever registered.
      debugPrint('Qurilmani ro‘yxatdan o‘tkazib bo‘lmadi: $e');
    }
  }

  /// Called on sign-out. Without it a phone that was handed to somebody else
  /// keeps receiving the previous owner's notifications.
  Future<void> forget() async {
    if (!_configured) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _apiClient.delete<dynamic>('/devices/$token', parse: (data) => data);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Qurilmani o‘chirib bo‘lmadi: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationService(apiClient);
});
