import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import 'auth_controller.dart';

/// First screen the user sees. Holds for ~1.2s while the auth restore runs in
/// the background, then routes to /home or /login. The scissors logo gets a
/// gentle scale loop so the wait never feels dead.
///
/// Routing is gated on TWO conditions: the 1200ms brand-impression timer AND
/// the auth-restore future. Whichever finishes second triggers `_route`. We
/// use ref.listen inside build() (the only legal place) and a local flag to
/// make sure we route at most once.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _timerFired = false;
  bool _routed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _timerFired = true);
      _maybeRoute();
    });
  }

  void _maybeRoute() {
    if (_routed || !mounted) return;
    if (!_timerFired) return;
    final state = ref.read(authControllerProvider);
    if (state.loading) return;
    _routed = true;
    final user = state.user;
    if (user == null) {
      context.go('/login');
      return;
    }
    // Role-based routing — barber/shop owners land on their dashboards, not
    // the customer feed.
    switch (user.role) {
      case 'barber':
        context.go('/barber');
        break;
      case 'barbershop':
      case 'shop':
        context.go('/shop');
        break;
      case 'admin':
        // Admins use the web panel — surface a friendly message instead of
        // routing them into a customer shell.
        context.go('/admin-blocked');
        break;
      default:
        context.go('/home');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth state — when it transitions out of `loading`, we may be
    // ready to route (if the brand timer has already fired).
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (!next.loading) _maybeRoute();
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.content_cut, color: Colors.white, size: 48),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: 1500.ms,
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.04, 1.04),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 24),
            const Text(
              'Lope Style',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: AppColors.textBright,
              ),
            )
                .animate()
                .fadeIn(duration: 800.ms, delay: 200.ms)
                .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 10),
            const Text(
              "Sartaroshlik bron platformasi",
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ).animate().fadeIn(duration: 800.ms, delay: 400.ms),
          ],
        ),
      ),
    );
  }
}
