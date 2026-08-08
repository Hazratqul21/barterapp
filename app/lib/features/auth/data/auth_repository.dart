import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';

class AuthRepository {
  AuthRepository(this._api, this._session);

  final ApiClient _api;
  final SessionStore _session;

  /// Returns the debug code while the backend has no SMS provider, so the app
  /// can be driven end to end. In production this is always null.
  Future<String?> requestCode(String phone) {
    return _api.post(
      '/auth/otp/request',
      body: {'phone': phone},
      parse: (data) => (data as Map<String, dynamic>)['debug_code'] as String?,
    );
  }

  Future<bool> verify(String phone, String code) async {
    final tokens = await _api.post(
      '/auth/otp/verify',
      body: {'phone': phone, 'code': code},
      parse: (data) => data as Map<String, dynamic>,
    );
    await _session.saveTokens(
      tokens['access_token'] as String,
      tokens['refresh_token'] as String,
    );
    return tokens['is_new_user'] as bool? ?? false;
  }

  Future<Me> me() =>
      _api.get('/me', parse: (data) => Me.fromJson(data as Map<String, dynamic>));

  Future<Me> updateProfile(Map<String, dynamic> body) =>
      _api.patch('/me', body: body, parse: (data) => Me.fromJson(data as Map<String, dynamic>));

  /// The regions an account can be placed in.
  ///
  /// Fetched rather than baked into the app: picking one is also what gives the
  /// account coordinates, and distance is 30% of every match score.
  Future<List<String>> regions() => _api.get(
    '/regions',
    parse: (data) => (data as List).cast<String>(),
  );

  Future<void> signOut() => _session.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Whether there is a token on this device. Screens that need an account watch
/// this rather than catching 401s one by one.
class AuthState extends Notifier<bool> {
  @override
  bool build() => ref.watch(sessionStoreProvider).accessToken != null;

  Future<void> signedIn() async => state = true;

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = false;
    ref.invalidate(meProvider);
  }
}

final authStateProvider = NotifierProvider<AuthState, bool>(AuthState.new);

final meProvider = FutureProvider.autoDispose<Me?>((ref) async {
  if (!ref.watch(authStateProvider)) return null;
  return ref.watch(authRepositoryProvider).me();
});

/// Not auto-disposed: the list never changes during a session, and a profile
/// form should not wait on a round trip every time it is opened.
final regionsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(authRepositoryProvider).regions(),
);
