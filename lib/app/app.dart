import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/connectivity_service.dart';
import '../core/deep_link_service.dart';
import '../core/live_refresh.dart';
import '../core/push_service.dart';
import '../core/theme_mode_provider.dart';
import '../core/update_check_service.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../shared/theme/typography.dart';
import '../shared/widgets/offline_banner.dart';
import '../shared/widgets/update_available_dialog.dart';
import 'router.dart';
import 'theme.dart';

class LopeApp extends ConsumerStatefulWidget {
  const LopeApp({super.key});

  @override
  ConsumerState<LopeApp> createState() => _LopeAppState();
}

class _LopeAppState extends ConsumerState<LopeApp> with WidgetsBindingObserver {
  bool _pushInited = false;
  bool _updateCheckShown = false;
  // Global ScaffoldMessenger key so push_service can show a foreground
  // banner from outside the widget tree when an FCM message arrives
  // while the app has focus.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Global refresh trigger #2 — the OS just brought us back to the
    // foreground (user tapped the icon, swiped over from another app,
    // unlocked the phone with us in view). Anything the server changed
    // while we were suspended (a booking cancel, a fresh notification,
    // an admin balance top-up) needs a fetch. Debug builds don't get
    // FCM push reliably, and iOS aggressively throttles background
    // wake-ups even in release, so a lifecycle-triggered invalidate is
    // the boring fallback that catches everything.
    if (state == AppLifecycleState.resumed) {
      final role = ref.read(authControllerProvider).user?.role;
      invalidateLiveDataW(ref, role: role);
    }
  }

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
      // Global refresh trigger #1 — every foreground FCM push invalidates
      // notifications + every booking/schedule provider family so the
      // bell, badge, and any open screen all react live. Delegated to
      // invalidateLiveData so the same helper covers app resume and
      // bottom-nav taps.
      ref.listen<int>(fcmForegroundPushSignal, (_, __) {
        invalidateLiveDataW(ref, role: currentUser.role);
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

    // "Yangi versiya bor" modal — fires once per app launch, after the
    // update check resolves. Uses the root navigator (via messengerKey's
    // context) so it sits on top of the router. Guarded by _updateCheckShown
    // so a rebuild during the async fetch doesn't re-open the dialog.
    ref.listen<AsyncValue<UpdateCheckResult>>(updateCheckProvider, (_, next) {
      next.whenData((result) {
        if (_updateCheckShown) return;
        if (result.status == UpdateStatus.upToDate) return;
        final navContext = _messengerKey.currentContext;
        if (navContext == null || !navContext.mounted) return;
        _updateCheckShown = true;
        showDialog<void>(
          context: navContext,
          barrierDismissible: result.status == UpdateStatus.softUpdate,
          useRootNavigator: true,
          builder: (_) => UpdateAvailableDialog(result: result),
        );
      });
    });

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
