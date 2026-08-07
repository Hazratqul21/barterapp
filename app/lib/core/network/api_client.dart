import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the API lives during development.
///
/// The Android emulator reaches the host machine on 10.0.2.2, not localhost —
/// everything else can use localhost directly.
String defaultApiBaseUrl() {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;

  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8010';
  return 'http://127.0.0.1:8010';
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isNetworkFailure => statusCode == null;

  @override
  String toString() => message;
}

/// Holds the session token and the language the API should answer in.
class SessionStore {
  SessionStore(this._prefs);

  static const _tokenKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _localeKey = 'locale';

  final SharedPreferences _prefs;

  String? get accessToken => _prefs.getString(_tokenKey);
  String? get refreshToken => _prefs.getString(_refreshKey);
  String get locale => _prefs.getString(_localeKey) ?? 'uz';

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
  ApiClient(this._session, {String? baseUrl})
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
          options.headers['Accept-Language'] = _session.locale;
          final token = _session.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _session;

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

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
);
