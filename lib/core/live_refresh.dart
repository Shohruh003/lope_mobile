import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/barber_panel/data/barber_panel_repository.dart';
import '../features/bookings/data/booking_repository.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/shop_panel/data/shop_repository.dart';

/// Central invalidator for every provider whose data may have gone stale
/// on the server. Called from three places, each covering a different
/// staleness window:
///
///   1. Foreground FCM push (app.dart listener on fcmForegroundPushSignal)
///   2. App lifecycle → resumed (app.dart WidgetsBindingObserver)
///   3. Bottom navigation tap (each role shell's _BottomBar onSelect)
///
/// FCM used to be the only trigger, but debug builds and background
/// throttling meant a barber sitting on the schedule tab could miss a
/// cancellation for minutes. Refreshing on user action (tab tap, app
/// resume) is a boring, reliable fallback — the FCM path stays as a
/// live-latency optimisation on top of it.
///
/// Invalidating a `.family` provider with no argument drops EVERY cached
/// variant, so re-mounted screens with any (barberId, date) key get a
/// fresh fetch. Providers no one is currently watching become no-ops.
///
/// `role` is optional so callers outside the auth context (e.g. cold
/// lifecycle callback before user is loaded) can skip the role-scoped
/// notifications provider without crashing.
void invalidateLiveData(Ref ref, {String? role}) {
  if (role != null) {
    ref.invalidate(notificationsProvider(role));
  }
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
}

/// WidgetRef variant for use inside widget callbacks (bottom nav taps).
/// Same behaviour as [invalidateLiveData] — kept separate because Ref
/// and WidgetRef aren't interchangeable.
void invalidateLiveDataW(WidgetRef ref, {String? role}) {
  if (role != null) {
    ref.invalidate(notificationsProvider(role));
  }
  ref.invalidate(barberDayBookingsProvider);
  ref.invalidate(barberAllBookingsProvider);
  ref.invalidate(scheduleSlotsProvider);
  ref.invalidate(bookedSlotsProvider);
  ref.invalidate(blockedSlotsProvider);
  ref.invalidate(barberScheduledDatesProvider);
  ref.invalidate(barberSavedDatesProvider);
  ref.invalidate(myBookingsProvider);
  ref.invalidate(myBookingsPagedProvider);
  ref.invalidate(shopBookingsProvider);
}
