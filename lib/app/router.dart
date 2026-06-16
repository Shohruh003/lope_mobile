import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/register_complete_screen.dart';
import '../features/auth/presentation/register_phone_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/barber_panel/presentation/barber_home_shell.dart';
import '../features/barbers/presentation/barber_detail_screen.dart';
import '../features/bookings/presentation/booking_screen.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/shop_panel/presentation/shop_home_shell.dart';
import '../shared/theme/colors.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
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
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(path: '/barber-app', builder: (context, state) => const BarberHomeShell()),
      GoRoute(path: '/shop', builder: (context, state) => const ShopHomeShell()),
      GoRoute(
        path: '/admin-blocked',
        builder: (context, state) => const Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined,
                        size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text("Admin panel mobile'da mavjud emas",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Text("Veb-versiyadan foydalaning: app.lopestyle.uz",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
