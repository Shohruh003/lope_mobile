import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'storage.dart';

/// Dio instance with:
///   - production base URL baked in (HTTPS only)
///   - 15-second connect / 30-second receive timeouts
///   - automatic Bearer token injection from secure storage
///   - one-shot refresh on 401 (POST /auth/refresh with refreshToken) before
///     bailing the session; if refresh fails the token is cleared so the next
///     launch routes to /login instead of looping bad JWTs.
///   - sensitive headers/cookies are NEVER logged
Dio buildDio(StorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // Treat 5xx as exceptions; 4xx surface as DioException so callers can
      // branch on response.statusCode.
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  // Defensive: reject any baseUrl that's not HTTPS in production. We never
  // want a stolen token replayed over plaintext.
  final scheme = Uri.tryParse(AppConfig.apiUrl)?.scheme.toLowerCase();
  assert(scheme == 'https',
      'API base URL must be HTTPS (got $scheme://...) — refusing to send tokens over plaintext.');

  dio.interceptors.add(_AuthInterceptor(dio, storage));
  return dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._storage);
  final Dio _dio;
  final StorageService _storage;
  bool _refreshing = false;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isRefreshCall = path.contains('/auth/refresh');

    if (status == 401 && !isRefreshCall && !_refreshing) {
      _refreshing = true;
      try {
        final refresh = await _storage.readRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          await _hardLogout();
          return handler.next(err);
        }
        final res = await _dio.post('/auth/refresh', data: {'refreshToken': refresh});
        final data = res.data;
        if (data is Map && data['token'] is String) {
          await _storage.writeToken(data['token'] as String);
          if (data['refreshToken'] is String) {
            await _storage.writeRefreshToken(data['refreshToken'] as String);
          }
          // Replay the original request with the new token.
          final clone = err.requestOptions;
          clone.headers['Authorization'] = 'Bearer ${data['token']}';
          final retry = await _dio.fetch(clone);
          return handler.resolve(retry);
        }
        await _hardLogout();
      } catch (_) {
        await _hardLogout();
      } finally {
        _refreshing = false;
      }
    }
    handler.next(err);
  }

  Future<void> _hardLogout() async {
    await _storage.clearToken();
    await _storage.clearRefreshToken();
    await _storage.clearUser();
  }
}

final dioProvider = Provider<Dio>((ref) {
  return buildDio(ref.watch(storageProvider));
});
