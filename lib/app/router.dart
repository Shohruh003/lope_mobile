import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/roles.dart';
import '../core/tr.dart';
import '../features/ai_style/presentation/ai_style_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_complete_screen.dart';
import '../features/auth/presentation/register_phone_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/barber_panel/presentation/barber_account_edit_screen.dart';
import '../features/barber_panel/presentation/barber_cards_screen.dart';
import '../features/barber_panel/presentation/barber_client_detail_screen.dart';
import '../features/barber_panel/presentation/barber_clients_screen.dart';
import '../features/barber_panel/presentation/barber_gallery_screen.dart';
import '../features/barber_panel/presentation/barber_home_shell.dart';
import '../features/barber_panel/presentation/barber_location_screen.dart';
import '../features/barber_panel/presentation/barber_profile_edit_screen.dart';
import '../features/barber_panel/presentation/barber_public_link_screen.dart';
import '../features/barber_panel/presentation/barber_reminder_settings_screen.dart';
import '../features/barber_panel/presentation/barber_vacations_screen.dart';
import '../features/barber_panel/presentation/barber_schedule_screen.dart';
import '../features/barber_panel/presentation/barber_services_screen.dart';
import '../features/barber_panel/presentation/barber_settings_screen.dart';
import '../features/barber_panel/presentation/barber_sms_history_screen.dart';
import '../features/barber_panel/presentation/barber_working_hours_screen.dart';
import '../features/barber_panel/presentation/schedule_generator_screen.dart';
import '../features/lopepay/presentation/payment_callback_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_home_shell.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/promo/presentation/promo_code_screen.dart';
import '../features/public_booking/presentation/public_booking_screen.dart';
import '../features/barbers/presentation/barber_detail_screen.dart';
import '../features/barbers/presentation/barbershop_detail_screen.dart';
import '../features/bookings/presentation/booking_screen.dart';
import '../features/favorites/presentation/favorites_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/lopepay/presentation/transactions_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_edit_screen.dart';
import '../features/profile/presentation/settings_screen.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/shop_panel/presentation/shop_admins_screen.dart';
import '../features/shop_panel/presentation/shop_client_detail_screen.dart';
import '../features/shop_panel/presentation/shop_clients_screen.dart';
import '../features/shop_panel/presentation/shop_home_shell.dart';
import '../features/shop_panel/presentation/shop_profile_screen.dart';
import '../features/shop_panel/presentation/shop_reminders_screen.dart';
import '../features/shop_panel/presentation/shop_settings_screen.dart';
import '../features/shop_panel/presentation/shop_sms_screen.dart';
import '../features/shop_panel/presentation/shop_transactions_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_customer_detail_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_customer_form_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_installments_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_products_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_sms_screen.dart';
import '../features/lopepay_shop/presentation/lopepay_transactions_screen.dart';
import '../shared/theme/colors.dart';
import '../features/auth/presentation/auth_controller.dart';

/// Single, deny-by-default router. Every route that depends on a user role
/// checks against `authControllerProvider` and bounces to /login if the
/// session is absent or the role doesn't match. This way a deep link can
/// never silently land an unauthenticated user inside the barber panel.
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild the router whenever the auth session flips loading/user
  // state so the redirect re-runs after restoreSession completes.
  // Without this, a hard refresh on /home reads user==null before the
  // async restore finishes and dumps the user on /login for good.
  final auth = ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      const publicPaths = {'/', '/login', '/register-phone', '/register-otp', '/register-complete', '/forgot-password'};
      final isPublic = publicPaths.contains(loc) || loc.startsWith('/b/');

      // Auth still resolving from persistent storage → park the user
      // on the splash so it can await the restore and dispatch to the
      // right role home. Prevents the /home → /login flash on refresh.
      if (auth.loading) {
        return loc == '/' ? null : '/';
      }

      // Unauthenticated → public-only.
      if (auth.user == null && !isPublic) return '/login';

      // Role gating for the panel roots.
      final role = auth.user?.role;
      if (loc.startsWith('/barber-app') && !isBarberRole(role)) return _homeFor(role);
      if (loc.startsWith('/shop') && role != 'barbershop') return _homeFor(role);
      if (loc.startsWith('/lopepay') && role != 'shop') return _homeFor(role);
      if (loc.startsWith('/home') && role != null && role != 'user') return _homeFor(role);

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register-phone', builder: (context, state) => const RegisterPhoneScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
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
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final t = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return HomeShell(initialTab: t);
        },
      ),
      GoRoute(
        path: '/barber-app',
        builder: (context, state) {
          final t = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return BarberHomeShell(initialTab: t);
        },
      ),
      GoRoute(
        path: '/shop',
        builder: (context, state) {
          final t = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return ShopHomeShell(initialTab: t);
        },
      ),
      GoRoute(
        path: '/lopepay',
        builder: (context, state) {
          final t = int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
          return LopepayHomeShell(initialTab: t);
        },
      ),

      // Customer feature paths
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/ai-style', builder: (context, state) => const AiStyleScreen()),
      GoRoute(path: '/transactions', builder: (context, state) => const TransactionsScreen()),
      GoRoute(path: '/profile-edit', builder: (context, state) => const ProfileEditScreen()),
      GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
      GoRoute(path: '/promo', builder: (context, state) => const PromoCodeScreen()),
      GoRoute(
        path: '/payment-callback',
        builder: (context, state) {
          // Click returns the user with ?payment_status=2 on success;
          // Payme uses ?status=success. Map both to the same boolean
          // the callback screen consumes.
          final qp = state.uri.queryParameters;
          final clickOk = qp['payment_status'] == '2';
          final paymeOk = qp['status'] == 'success';
          return PaymentCallbackScreen(
            status: (clickOk || paymeOk) ? 'success' : 'failure',
          );
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: '/barbershop/:id',
        builder: (context, state) => BarbershopDetailScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/reviews/:id',
        builder: (context, state) => ReviewsScreen(barberId: state.pathParameters['id']!),
      ),

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
      // Barber vacations — barber's own view uses no `barberId` param
      // (falls back to the logged-in user); shop admin viewing one of
      // their barbers pushes `/shop/barbers/:id/vacations` below.
      GoRoute(path: '/barber/vacations',
          builder: (context, state) => const BarberVacationsScreen()),
      GoRoute(
        path: '/shop/barbers/:id/vacations',
        builder: (context, state) =>
            BarberVacationsScreen(barberId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/barber/clients', builder: (context, state) => const BarberClientsScreen()),
      GoRoute(path: '/barber/my-clients', builder: (context, state) => const BarberClientsScreen()),
      GoRoute(
        path: '/barber/client/:phone',
        builder: (context, state) => BarberClientDetailScreen(
          phone: state.pathParameters['phone']!,
          initialName: state.uri.queryParameters['name'],
          initialAvatar: state.uri.queryParameters['avatar'],
        ),
      ),
      GoRoute(path: '/barber/location', builder: (context, state) => const BarberLocationScreen()),
      GoRoute(path: '/barber/settings', builder: (context, state) => const BarberSettingsScreen()),
      GoRoute(path: '/barber/account-edit', builder: (context, state) => const BarberAccountEditScreen()),
      GoRoute(path: '/barber/cards', builder: (context, state) => const BarberCardsScreen()),
      GoRoute(path: '/barber/promo-code', builder: (context, state) => const PromoCodeScreen()),
      GoRoute(
        path: '/barber/schedule-generator',
        builder: (context, state) {
          final raw = state.uri.queryParameters['date'];
          final parsed = raw == null ? null : DateTime.tryParse(raw);
          return ScheduleGeneratorScreen(initialDate: parsed);
        },
      ),

      // Shop feature paths
      GoRoute(
        // Barbershop admin viewing a specific master: reuse the barber
        // panel's own schedule screen (voice input, date strip,
        // Kunni yopish / Jadval qo'shish, slot grid) so both roles get
        // an identical UX. Passing `barberId` forces the screen to
        // resolve to that master instead of the logged-in user.
        path: '/shop/barbers/:id',
        builder: (context, state) => BarberScheduleScreen(
            key: ValueKey(state.pathParameters['id']!),
            barberId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/shop/clients', builder: (context, state) => const ShopClientsScreen()),
      GoRoute(path: '/shop/sms', builder: (context, state) => const ShopSmsScreen()),
      GoRoute(path: '/shop/transactions', builder: (context, state) => const ShopTransactionsScreen()),
      GoRoute(path: '/shop/profile', builder: (context, state) => const ShopProfileScreen()),
      GoRoute(path: '/shop/admins', builder: (context, state) => const ShopAdminsScreen()),
      GoRoute(path: '/shop/reminders', builder: (context, state) => const ShopRemindersScreen()),
      GoRoute(path: '/shop/settings', builder: (context, state) => const ShopSettingsScreen()),
      GoRoute(
        path: '/shop/clients/:key',
        builder: (context, state) => ShopClientDetailScreen(clientKey: state.pathParameters['key']!),
      ),

      // Lope Pay sub-screens
      GoRoute(
        path: '/lopepay/installments',
        builder: (context, state) => LopepayInstallmentsScreen(
            initialStatus: state.uri.queryParameters['status']),
      ),
      GoRoute(path: '/lopepay/products', builder: (context, state) => const LopepayProductsScreen()),
      GoRoute(path: '/lopepay/sms', builder: (context, state) => const LopepaySmsScreen()),
      GoRoute(path: '/lopepay/transactions', builder: (context, state) => const LopepayTransactionsScreen()),
      GoRoute(
        path: '/lopepay/customers/new',
        builder: (context, state) => const LopepayCustomerFormScreen(),
      ),
      GoRoute(
        path: '/lopepay/customers/:id/edit',
        builder: (context, state) => LopepayCustomerFormScreen(installmentId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/lopepay/customers/:id',
        builder: (context, state) => LopepayCustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),

      // Public booking — shareable link, no auth required.
      GoRoute(
        path: '/b/:slug',
        builder: (context, state) => PublicBookingScreen(slug: state.pathParameters['slug']!),
      ),

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
      body: Center(
        child: Consumer(
          builder: (context, ref, _) => Text(
            tr(ref, 'mobile.common.pageNotFound', 'Sahifa topilmadi: {{uri}}',
                {'uri': state.uri.toString()}),
          ),
        ),
      ),
    ),
  );
});

String _homeFor(String? role) {
  switch (role) {
    // Sartarosh, stilist, kosmetolog — bir xil barber ilovasi.
    case 'barber':
    case 'stylist':
    case 'cosmetologist':
      return '/barber-app';
    case 'barbershop': return '/shop';
    case 'shop': return '/lopepay';
    case 'admin': return '/admin-blocked';
    case null: return '/login';
    default: return '/home';
  }
}
