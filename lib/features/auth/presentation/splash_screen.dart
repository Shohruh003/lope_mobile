import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import 'auth_controller.dart';

/// Minimal launch screen — small icon bubble + brand. Matches the web's
/// understated tone (no giant glowing logo).
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
    _timer = Timer(const Duration(milliseconds: 1000), () {
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
    // Route per role. 'shop' is the LopePay installments owner, not the
    // barbershop owner — they have different home shells. Sending the
    // shop role to /shop used to bounce through _homeFor in the router
    // redirect; now we land them on /lopepay directly.
    switch (user.role) {
      case 'barber': context.go('/barber-app'); break;
      case 'barbershop': context.go('/shop'); break;
      case 'shop': context.go('/lopepay'); break;
      case 'admin': context.go('/admin-blocked'); break;
      default: context.go('/home');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.content_cut, color: AppColors.primary, size: 28),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 14),
            const Text(
              'Lope Style',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textBright,
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
            const SizedBox(height: 18),
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
