import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/auth/presentation/auth_controller.dart';
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
  PushService(this._dio, this._ref);
  final Dio _dio;
  final Ref _ref;
  String? _lastToken;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;

  Future<void> initIfPossible({
    GoRouter? router,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
  }) async {
    _messengerKey = messengerKey;
    if (kIsWeb) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      debugPrint('[FCM] Firebase.initializeApp OK');
    } catch (e) {
      debugPrint('[FCM] Firebase.initializeApp FAILED: $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      debugPrint('[FCM] permission status=${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.notification.request();
      }

      // On iOS getToken() throws 'apns-token-not-set' if called before APNs
      // has delivered the device token to Firebase. Wait for the APNs handshake
      // before we ask FCM for the mapped token.
      await _waitForApnsToken();
      final token = await messaging.getToken();
      debugPrint('[FCM] getToken → ${token == null ? "NULL" : "${token.length} chars, prefix=${token.substring(0, token.length > 30 ? 30 : token.length)}..."}');
      if (token != null && token.isNotEmpty) await _registerToken(token);

      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen(_registerToken);

      // Deep-link handling. Three entry points:
      //  - app opened from a notification (terminated/background → tap)
      //  - app in foreground when a notification arrives — FCM doesn't
      //    show a heads-up automatically on iOS or when the app has
      //    focus on Android, so we render a Material banner ourselves
      //    that the user can tap to jump to the linked screen.
      //  - already-open app tapped → onMessageOpenedApp fires.
      if (router != null) {
        final initial = await messaging.getInitialMessage();
        if (initial != null) _route(router, initial);
        _openedSub?.cancel();
        _openedSub = FirebaseMessaging.onMessageOpenedApp
            .listen((m) => _route(router, m));
        _foregroundSub?.cancel();
        _foregroundSub = FirebaseMessaging.onMessage
            .listen((m) => _showForegroundBanner(router, m));
      }
    } catch (_) {
      // Best-effort. Push not working should never block the rest of the app.
    }
  }

  /// Foreground message → in-app snackbar so the user knows something
  /// arrived even while the app is open. Tapping "Ochish" jumps to
  /// whatever screen the payload points to.
  void _showForegroundBanner(GoRouter router, RemoteMessage m) {
    final messenger = _messengerKey?.currentState;
    if (messenger == null) return;
    final title = m.notification?.title ?? m.data['title']?.toString() ?? '';
    final body = m.notification?.body ?? m.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isNotEmpty)
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(body,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
      action: SnackBarAction(
        label: 'Ochish',
        onPressed: () => _route(router, m),
      ),
    ));
  }

  /// Read `route`, `bookingId`, or `barberId` from the push payload and
  /// navigate. Anything unfamiliar — silently ignored so a stray payload
  /// can't crash the app. Payload key precedence:
  ///   1. explicit `route` (backend knows exactly where to send us)
  ///   2. `barberId` -> `/barber/{id}`
  ///   3. `bookingId` -> role-appropriate bookings tab (customer /home?tab=2,
  ///      barber /barber-app?tab=1, barbershop /shop?tab=2). Backend now
  ///      typically sends an explicit `route`, so this is a fallback.
  ///   4. anything else -> `/notifications`
  void _route(GoRouter router, RemoteMessage m) {
    final data = m.data;
    final explicit = data['route']?.toString();
    if (explicit != null && explicit.startsWith('/')) {
      router.push(explicit);
      return;
    }
    final barberId = data['barberId']?.toString();
    if (barberId != null && barberId.isNotEmpty) {
      router.push('/barber/$barberId');
      return;
    }
    final bookingId = data['bookingId']?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      final role = _ref.read(authControllerProvider).user?.role;
      switch (role) {
        case 'barbershop':
          router.push('/shop?tab=2');
          return;
        case 'barber':
        case 'stylist':
        case 'cosmetologist':
          router.push('/barber-app?tab=1');
          return;
        default:
          router.push('/home?tab=2');
          return;
      }
    }
    router.push('/notifications');
  }

  Future<void> _registerToken(String token) async {
    if (_lastToken == token) {
      debugPrint('[FCM] _registerToken skipped (same token cached)');
      return;
    }
    _lastToken = token;
    try {
      final res = await _dio.post('/auth/register-device', data: {
        'fcmToken': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      debugPrint('[FCM] /auth/register-device OK status=${res.statusCode}');
    } catch (e) {
      debugPrint('[FCM] /auth/register-device FAILED: $e');
    }
  }

  /// Force a fresh register-device call. Use after login: the first run of
  /// [initIfPossible] happens before the user signs in, so the dio call has
  /// no Authorization header and the backend route (JwtAuthGuard) rejects
  /// it. The token caching in [_registerToken] then short-circuits future
  /// registration attempts. Resetting [_lastToken] forces a retry.
  Future<void> registerCurrentToken() async {
    if (kIsWeb) return;
    try {
      // Force-init Firebase if the app-level bootstrap hasn't finished
      // yet — race window is common on cold-start: _restore() fires as
      // soon as the notifier builds, but initIfPossible runs inside an
      // addPostFrameCallback that hasn't landed on the first tick.
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp();
          debugPrint('[FCM] registerCurrentToken: force-init OK');
        } catch (e) {
          debugPrint('[FCM] registerCurrentToken: force-init FAILED: $e');
          return;
        }
      }
      // Same permission request — a no-op if the user already granted
      // it, otherwise iOS shows the prompt (also required for the very
      // first cached-session app open after install).
      await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true);
      // iOS: FCM getToken() throws 'apns-token-not-set' if APNs hasn't
      // handed a device token to Firebase yet — poll briefly so the very
      // first launch after install still lands a token instead of bailing.
      await _waitForApnsToken();
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] registerCurrentToken getToken → ${token == null ? "NULL" : "${token.length} chars"}');
      if (token == null || token.isEmpty) return;
      _lastToken = null;
      await _registerToken(token);
    } catch (e) {
      debugPrint('[FCM] registerCurrentToken FAILED: $e');
    }
  }

  /// Polls FirebaseMessaging.getAPNSToken() until iOS delivers the APNs
  /// device token to Firebase, or up to ~6s. On Android this is a no-op
  /// (getAPNSToken returns null). Fixes 'apns-token-not-set' the very
  /// first time the app runs on a device — the FCM handshake needs the
  /// APNs token to exist BEFORE getToken() is called.
  Future<void> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    for (var i = 0; i < 20; i++) {
      try {
        final apns = await FirebaseMessaging.instance.getAPNSToken();
        if (apns != null && apns.isNotEmpty) {
          debugPrint('[FCM] APNs token ready after ${i * 300}ms');
          return;
        }
      } catch (_) { /* swallow — try again */ }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    debugPrint('[FCM] APNs token still null after 6s — proceeding anyway');
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
    await _foregroundSub?.cancel();
    _foregroundSub = null;
    await _openedSub?.cancel();
    _openedSub = null;
  }
}

final pushServiceProvider =
    Provider<PushService>((ref) => PushService(ref.watch(dioProvider), ref));
