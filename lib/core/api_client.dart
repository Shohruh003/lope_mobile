import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'storage.dart';

/// Dio instance with:
///   - production base URL baked in
///   - 15-second connect / 30-second receive timeouts (Eskiz is slow sometimes)
///   - automatic Bearer token injection from secure storage
///   - 401 cleanup so a revoked session can't loop the app on a stale JWT
Dio buildDio(StorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired or revoked — clear it so the next launch routes to
          // login instead of looping authenticated requests with a bad JWT.
          await storage.clearToken();
          await storage.clearUser();
        }
        handler.next(e);
      },
    ),
  );

  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  return buildDio(ref.watch(storageProvider));
});
