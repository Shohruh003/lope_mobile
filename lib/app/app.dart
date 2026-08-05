import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity_service.dart';
import '../core/deep_link_service.dart';
import '../core/push_service.dart';
import '../core/theme_mode_provider.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/barber_panel/data/barber_panel_repository.dart';
import '../features/bookings/data/booking_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/shop_panel/data/shop_repository.dart';
import '../shared/theme/typography.dart';
import '../shared/widgets/offline_banner.dart';
import 'router.dart';
import 'theme.dart';

class LopeApp extends ConsumerStatefulWidget {
  const LopeApp({super.key});

  @override
  ConsumerState<LopeApp> createState() => _LopeAppState();
}

class _LopeAppState extends ConsumerState<LopeApp> {
  bool _pushInited = false;
  // Global ScaffoldMessenger key so push_service can show a foreground
  // banner from outside the widget tree when an FCM message arrives
  // while the app has focus.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Keep the iOS / Android home-screen icon badge in sync with the
    // unread notification count from notificationsProvider — the same
    // number the in-app bell shows. Fires whenever the notifications
    // list refetches (login, mark-as-read, foreground FCM push).
    final currentUser = ref.watch(authControllerProvider).user;
    if (currentUser != null) {
      ref.listen(notificationsProvider(currentUser.role), (_, next) {
        next.whenData((list) {
          final unread = list.where((n) => !n.read).length;
          AppBadgePlus.updateBadge(unread);
        });
      });
      // Global refresh trigger — every foreground FCM push invalidates
      // the notifications provider AND every booking/schedule provider
      // family across the app. This way, no matter what screen the user
      // is on (or was on when the push arrived), the schedule grid, the
      // bookings tab, the shop bookings list, and the notifications
      // history all reflect the server state on the next mount. Without
      // this, a cancelled booking would still show as ЗАНЯТО in the
      // barber's schedule until they pulled to refresh.
      //
      // Invalidating a family (no argument) drops every cached variant
      // so re-mounted screens with any (barberId, date) key get fresh
      // data. Providers no one is watching are no-ops.
      ref.listen<int>(fcmForegroundPushSignal, (_, __) {
        ref.invalidate(notificationsProvider(currentUser.role));
        // Barber-side
        ref.invalidate(barberDayBookingsProvider);
        ref.invalidate(barberAllBookingsProvider);
        ref.invalidate(scheduleSlotsProvider);
        ref.invalidate(bookedSlotsProvider);
        ref.invalidate(blockedSlotsProvider);
        ref.invalidate(barberScheduledDatesProvider);
        ref.invalidate(barberSavedDatesProvider);
        // Customer-side
        ref.invalidate(myBookingsProvider);
        ref.invalidate(myBookingsPagedProvider);
        // Shop-side
        ref.invalidate(shopBookingsProvider);
      });
    } else {
      // Logged out — wipe the badge so the previous user's count doesn't
      // leak onto the home screen.
      // ignore: unawaited_futures
      AppBadgePlus.updateBadge(0);
    }

    // Fire-and-forget FCM bootstrap on the first build. Wrapped in a guard so
    // it only runs once across rebuilds and only after the router is ready
    // (because push_service needs it for deep-linking).
    if (!_pushInited) {
      _pushInited = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref
            .read(pushServiceProvider)
            .initIfPossible(router: router, messengerKey: _messengerKey);
        // Incoming URIs — Android App Links, iOS Universal Links,
        // and the `lopestyle://` custom scheme fallback all flow
        // through DeepLinkService and end up in router.push.
        await ref.read(deepLinkServiceProvider).initIfPossible(router);
      });
    }

    // Real light/dark mode: buildAppTheme(brightness) returns a
    // ThemeData that registers the matching LopeColors extension, and
    // every screen — shared widgets AND individual features — reads
    // colours through `context.colors.xxx`. AppText's static getters
    // pull from the same palette via a runtime brightness switch so
    // titles/subtitles/captions don't need context to theme correctly.
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.dark;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final effectiveBrightness = switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => systemBrightness,
    };
    AppText.brightness = effectiveBrightness;
    return ValueListenableBuilder<Brightness>(
      valueListenable: AppText.brightnessNotifier,
      builder: (_, __, ___) => MaterialApp.router(
      title: 'Lope Style',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: router,
      // Wrap every route in an amber offline banner + subscribe to
      // connectivity so we can auto-refetch when the network comes
      // back. Both concerns are cross-cutting — no individual screen
      // should be aware of them. Also clamp the system text scale
      // factor so an accessibility user who cranks their font up to
      // 200% doesn't blow out our tight layouts (buttons overflow,
      // stat tiles clip). Full a11y up to 130% — beyond that we
      // stop scaling and rely on Column layouts + overflow ellipsis.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: OfflineBannerWrapper(
            child: _AutoRetryOnReconnect(
                child: child ?? const SizedBox()),
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uz'),
        Locale('ru'),
        Locale('en'),
      ],
    ),
    );
  }
}

/// Listens to the network status and, when it flips from offline back
/// to online, invalidates every screen's FutureProvider so cached
/// errors get replaced with a fresh fetch — the user doesn't have to
/// pull-to-refresh every list after a signal drop.
class _AutoRetryOnReconnect extends ConsumerStatefulWidget {
  const _AutoRetryOnReconnect({required this.child});
  final Widget child;

  @override
  ConsumerState<_AutoRetryOnReconnect> createState() =>
      _AutoRetryOnReconnectState();
}

class _AutoRetryOnReconnectState
    extends ConsumerState<_AutoRetryOnReconnect> {
  bool? _wasOnline;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      final now = next.asData?.value;
      if (now == null) return;
      // Flip from offline -> online: kick every provider so async
      // errors from the offline period get retried. We use
      // ProviderContainer.invalidate on nothing specific (just refresh
      // the whole tree via a router push-refresh signal).
      if (_wasOnline == false && now == true) {
        // Simplest reliable trigger: bump a signal provider — every
        // list screen that wants to react can .watch it. If no one
        // listens, this is a no-op.
        ref.invalidate(networkReconnectSignal);
      }
      _wasOnline = now;
    });
    return widget.child;
  }
}

/// Bumps every time the device transitions from offline to online.
/// Screens that need to re-fetch after a reconnect can `ref.watch`
/// this and pair it with their own `ref.invalidate(...)` in a
/// [ref.listen] callback. Kept intentionally opaque (a plain
/// [Provider] that returns null) — the value is unused, only the
/// invalidation is meaningful.
final networkReconnectSignal = Provider<Object?>((ref) => null);
