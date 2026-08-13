import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';

/// Where the API lives during development.
///
/// The Android emulator reaches the host machine on 10.0.2.2, not localhost —
/// everything else can use localhost directly.
String defaultApiBaseUrl() {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  // A release build has no business talking to a laptop. Without this, a
  // store build compiled without the define would install, open, and fail
  // every request in silence — which looks like a broken server, not a
  // broken build, and is found by users rather than by whoever shipped it.
  if (kReleaseMode) {
    throw StateError(
      'API_BASE_URL berilmagan. Reliz quring:\n'
      '  flutter build web --dart-define=API_BASE_URL=https://api.example.uz',
    );
  }

  // The Android emulator reaches the host machine on 10.0.2.2, not localhost.
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8010';
  return 'http://127.0.0.1:8010';
}

/// Where the listing-writing AI service lives.
///
/// A separate process from the API — `ai_backend/`, Dart and Genkit — so it
/// gets its own address rather than a path on the main one.
///
/// It follows the same rules as [defaultApiBaseUrl] for the same reason: the
/// dialog used to post to a literal `http://127.0.0.1:8081`, which on a phone
/// is the phone. Not the laptop that is running the service — the handset
/// itself, where nothing is listening. The feature worked in a desktop browser
/// and could not work on a single real device, which is the only place this app
/// is meant to run.
String defaultAiBaseUrl() {
  const override = String.fromEnvironment('AI_BASE_URL');
  if (override.isNotEmpty) return override;

  // Unlike the API, a missing address here is not fatal: the button is a
  // shortcut and the form is fully usable without it. So a release build gets
  // an empty string and the button hides itself, rather than throwing.
  if (kReleaseMode) return '';

  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8081';
  return 'http://127.0.0.1:8081';
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() => message;
}

/// The three languages the product ships in. Content and interface always move
/// together — there is no way to read a Russian interface over Uzbek listings.
const kSupportedLocales = ['uz', 'ru', 'en'];

/// Holds the session token and the language the API should answer in.
class SessionStore {
  SessionStore(this._prefs);

  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _localeKey = 'locale';
  static const _introKey = 'intro_seen';

  final SharedPreferences _prefs;

  String? get accessToken => _prefs.getString(_tokenKey);
  String? get refreshToken => _prefs.getString(_refreshKey);

  /// Whether the three intro screens have been shown. Kept out of [clear] on
  /// purpose: signing out is not a reason to re-explain what barter is.
  bool get introSeen => _prefs.getBool(_introKey) ?? false;

  Future<void> markIntroSeen() => _prefs.setBool(_introKey, true);

  String get locale {
    final stored = _prefs.getString(_localeKey);
    return kSupportedLocales.contains(stored) ? stored! : 'uz';
  }

  Future<void> saveTokens(String access, String refresh) async {
    await _prefs.setString(_tokenKey, access);
    await _prefs.setString(_refreshKey, refresh);
  }

  Future<void> setLocale(String value) => _prefs.setString(_localeKey, value);

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_refreshKey);
  }
}

class ApiClient {
  ApiClient(
    this._session, {
    required this.locale,
    this.onUnauthorized,
    String? baseUrl,
  })
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? defaultApiBaseUrl(),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // The API answers in one language; it is chosen here, once.
          options.headers['Accept-Language'] = locale;
          final token = _session.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        // A 401 no longer means "signed out" on its own. The access token now
        // lasts an hour, not a day, so an expired one is routine — the refresh
        // token trades it for a new pair and the original request is retried
        // once, invisibly. Only when that fails is the session actually over.
        onError: (e, handler) async {
          final is401 = e.response?.statusCode == 401;
          final isAuthCall = e.requestOptions.path.contains('/auth/');
          if (!is401 || isAuthCall || _session.refreshToken == null) {
            return handler.next(e);
          }

          final refreshed = await _refreshOnce();
          if (!refreshed) return handler.next(e);

          try {
            final opts = e.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${_session.accessToken}';
            final retry = await _dio.fetch<dynamic>(opts);
            return handler.resolve(retry);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _session;

  /// One refresh at a time. Several requests can 401 at once when a token
  /// expires; they all await the same exchange instead of each spending the
  /// refresh token — which, with rotation on the server, would look like reuse
  /// and drop every session.
  Future<bool>? _refreshing;

  Future<bool> _refreshOnce() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final token = _session.refreshToken;
    if (token == null) return false;
    try {
      // A bare client, so the request carries no stale Authorization header and
      // cannot recurse back into this interceptor.
      final bare = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await bare.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': token},
      );
      final data = response.data as Map<String, dynamic>;
      await _session.saveTokens(
        data['access_token'] as String,
        data['refresh_token'] as String,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  /// The language this client asks for. Held as a field rather than read from
  /// storage per request so that switching it replaces the whole client — which
  /// is what makes every cached listing refetch in the new language.
  final String locale;

  /// Called once when the server rejects the session.
  ///
  /// A token outlives its account — the signing key changes, the row is gone,
  /// the expiry passes. Without this the app kept the dead token and every
  /// screen that needs an account sat on a loading skeleton or showed the
  /// server's "Foydalanuvchi topilmadi", with no way back to the sign-in
  /// screen. A rejected session is not an error to display; it is a session
  /// that has ended.
  final void Function()? onUnauthorized;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      return parse(response.data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: body);
      return parse(response.data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(dynamic data) parse,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(path, data: body);
      return parse(response.data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Send one photo and get back the URL the server stored it under.
  ///
  /// [bytes] rather than a path because the web build has no filesystem to hand
  /// Dio, and a listing has to be publishable from a browser as well as a phone.
  Future<T> upload<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    required T Function(dynamic data) parse,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post<dynamic>(
        path,
        data: form,
        onSendProgress: onProgress,
        // Photos travel over the same mobile connection the rest of the app
        // gives up on after 15 seconds; they need longer.
        options: Options(sendTimeout: const Duration(seconds: 60)),
      );
      return parse(response.data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    required T Function(dynamic data) parse,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(path);
      return parse(response.data);
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  ApiException _translate(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (status == 401) onUnauthorized?.call();

    // FastAPI puts a human-readable reason in `detail`; surface it rather than
    // a generic failure, because those messages are already written for users.
    if (data is Map && data['detail'] is String) {
      return ApiException(data['detail'] as String, statusCode: status);
    }
    if (status != null) {
      return ApiException('HTTP $status', statusCode: status);
    }
    return ApiException('network');
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(sharedPreferencesProvider)),
);

/// The chosen language, as state rather than as a value read out of storage.
///
/// It used to be read straight off `SessionStore`, which returns the same
/// object every time — so writing a new locale changed nothing Riverpod could
/// see, and the app stayed in Uzbek until it was restarted. Holding it here
/// means one setter moves the interface, the `Accept-Language` header and every
/// cached listing at once.
class LocaleController extends Notifier<String> {
  @override
  String build() => ref.watch(sessionStoreProvider).locale;

  Future<void> set(String value) async {
    if (!kSupportedLocales.contains(value) || value == state) return;
    await ref.read(sessionStoreProvider).setLocale(value);
    state = value;
  }
}

final localeProvider = NotifierProvider<LocaleController, String>(
  LocaleController.new,
);

/// Watching the locale here is deliberate: a language change builds a new
/// client, which disposes every repository and provider hanging off it. Content
/// already on screen is refetched in the new language instead of sitting there
/// in the old one.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(sessionStoreProvider),
    locale: ref.watch(localeProvider),
    // Read lazily inside the callback: the auth state must not become a
    // build-time dependency of the client that reports to it.
    onUnauthorized: () => ref.read(authStateProvider.notifier).sessionExpired(),
  ),
);
