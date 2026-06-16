import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/tr.dart';
import '../features/ai_style/presentation/ai_style_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_complete_screen.dart';
import '../features/auth/presentation/register_phone_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/barber_panel/presentation/barber_gallery_screen.dart';
import '../features/barber_panel/presentation/barber_home_shell.dart';
import '../features/barber_panel/presentation/barber_profile_edit_screen.dart';
import '../features/barber_panel/presentation/barber_public_link_screen.dart';
import '../features/barber_panel/presentation/barber_reminder_settings_screen.dart';
import '../features/barber_panel/presentation/barber_services_screen.dart';
import '../features/barber_panel/presentation/barber_sms_history_screen.dart';
import '../features/barber_panel/presentation/barber_working_hours_screen.dart';
import '../features/barbers/presentation/barber_detail_screen.dart';
import '../features/bookings/presentation/booking_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/lopepay/presentation/transactions_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_edit_screen.dart';
import '../features/shop_panel/presentation/shop_home_shell.dart';
import '../shared/theme/colors.dart';
import '../features/auth/presentation/auth_controller.dart';

/// Single, deny-by-default router. Every route that depends on a user role
/// checks against `authControllerProvider` and bounces to /login if the
/// session is absent or the role doesn't match. This way a deep link can
/// never silently land an unauthenticated user inside the barber panel.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = ProviderScope.containerOf(context).read(authControllerProvider);
      final loc = state.matchedLocation;
      const publicPaths = {'/', '/login', '/register-phone', '/register-otp', '/register-complete'};
      final isPublic = publicPaths.contains(loc) || loc.startsWith('/b/');

      // Unauthenticated → public-only.
      if (auth.user == null && !isPublic) return '/login';

      // Role gating for the three panel roots.
      final role = auth.user?.role;
      if (loc.startsWith('/barber-app') && role != 'barber') return _homeFor(role);
      if (loc.startsWith('/shop') && role != 'barbershop' && role != 'shop') return _homeFor(role);
      if (loc.startsWith('/home') && role != null && role != 'user') return _homeFor(role);

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register-phone', builder: (context, state) => const RegisterPhoneScreen()),
      GoRoute(
        path: '/register-otp',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/register-complete',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return RegisterCompleteScreen(phone: phone);
        },
      ),

      // Roots
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(path: '/barber-app', builder: (context, state) => const BarberHomeShell()),
      GoRoute(path: '/shop', builder: (context, state) => const ShopHomeShell()),

      // Customer feature paths
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/ai-style', builder: (context, state) => const AiStyleScreen()),
      GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
      GoRoute(path: '/profile-edit', builder: (context, state) => const ProfileEditScreen()),

      // Barber feature paths
      GoRoute(path: '/barber/profile', builder: (context, state) => const BarberProfileEditScreen()),
      GoRoute(path: '/barber/services',
          builder: (context, state) {
            final id = ProviderScope.containerOf(context).read(authControllerProvider).user?.id ?? '';
            return BarberServicesScreen(barberId: id);
          }),
      GoRoute(path: '/barber/hours',
          builder: (context, state) {
            final id = ProviderScope.containerOf(context).read(authControllerProvider).user?.id ?? '';
            return BarberWorkingHoursScreen(barberId: id);
          }),
      GoRoute(path: '/barber/gallery',
          builder: (context, state) {
            final id = ProviderScope.containerOf(context).read(authControllerProvider).user?.id ?? '';
            return BarberGalleryScreen(barberId: id);
          }),
      GoRoute(path: '/barber/reminders', builder: (context, state) => const BarberReminderSettingsScreen()),
      GoRoute(path: '/barber/sms', builder: (context, state) => const BarberSmsHistoryScreen()),
      GoRoute(path: '/barber/public-link', builder: (context, state) => const BarberPublicLinkScreen()),

      // Admin role isn't a panel — direct it to a friendly stub.
      GoRoute(
        path: '/admin-blocked',
        builder: (context, state) => Consumer(
          builder: (context, wRef, _) => Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined, size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text(tr(wRef, 'mobile.admin.title', "Admin panel mobile'da mavjud emas"),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(tr(wRef, 'mobile.admin.subtitle', "Veb-versiyadan foydalaning: app.lopestyle.uz"),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // Detail / booking
      GoRoute(
        path: '/barber/:id',
        builder: (context, state) => BarberDetailScreen(barberId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) => BookingScreen(barberId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Sahifa topilmadi: ${state.uri}')),
    ),
  );
});

String _homeFor(String? role) {
  switch (role) {
    case 'barber': return '/barber-app';
    case 'barbershop':
    case 'shop': return '/shop';
    case 'admin': return '/admin-blocked';
    case null: return '/login';
    default: return '/home';
  }
}
