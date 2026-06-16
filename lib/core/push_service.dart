import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> initIfPossible() async {
    if (kIsWeb) return;
    try {
      // Ensure Firebase has been initialised. If google-services.json is not
      // present the call will throw — swallow and stay silent in that case so
      // the app still runs without FCM (e.g. local dev without firebase).
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
      // On Android 13+ FCM still works without POST_NOTIFICATIONS but the
      // tray icon won't appear. Ask only on Android.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);

      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_registerToken);
    } catch (_) {
      // Best-effort. Push not working should never block the rest of the app.
    }
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
