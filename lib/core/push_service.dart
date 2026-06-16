import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_client.dart';

/// FCM bootstrap + device registration with the backend.
///
/// Backend contract:
///   POST /auth/register-device  { fcmToken, platform }
///   POST /auth/logout-device    { fcmToken }
///
/// We never log the raw token — it's an opaque secret that could be replayed
/// to deliver pushes if leaked.
class PushService {
  PushService(this._dio);
  final Dio _dio;
  String? _lastToken;
  StreamSubscription<String>? _refreshSub;

  Future<void> initIfPossible({GoRouter? router}) async {
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);

      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_registerToken);

      // Deep-link handling. Two entry points:
      //  - app opened from a notification (terminated/background → tap)
      //  - app in foreground when a notification arrives (we can't navigate
      //    silently — only react to actions). Foreground messages are surfaced
      //    by FCM into the system tray on Android automatically, so we just
      //    listen for the explicit "user opened it" event.
      if (router != null) {
        final initial = await messaging.getInitialMessage();
        if (initial != null) _route(router, initial);
        FirebaseMessaging.onMessageOpenedApp.listen((m) => _route(router, m));
      }
    } catch (_) {
      // Best-effort. Push not working should never block the rest of the app.
    }
  }

  /// Read `route`, `bookingId`, or `barberId` from the push payload and
  /// navigate. Anything unfamiliar — silently ignored so a stray payload
  /// can't crash the app.
  void _route(GoRouter router, RemoteMessage m) {
    final data = m.data;
    final explicit = data['route']?.toString();
    if (explicit != null && explicit.startsWith('/')) {
      router.push(explicit);
      return;
    }
    final bookingId = data['bookingId']?.toString();
    final barberId = data['barberId']?.toString();
    if (bookingId != null) {
      router.push('/notifications'); // detail screen will land users on the bookings list
      return;
    }
    if (barberId != null) {
      router.push('/barber/$barberId');
      return;
    }
    router.push('/notifications');
  }

  Future<void> _registerToken(String token) async {
    if (_lastToken == token) return;
    _lastToken = token;
    try {
      await _dio.post('/auth/register-device', data: {
        'fcmToken': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (_) {
      // Quietly. Backend may not have the endpoint in every env.
    }
  }

  /// Tear down on logout so the next user doesn't inherit pushes.
  Future<void> deregisterOnLogout() async {
    final token = _lastToken;
    if (token == null) return;
    try {
      await _dio.post('/auth/logout-device', data: {'fcmToken': token});
    } catch (_) {}
    _lastToken = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
  }
}

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref.watch(dioProvider)));
