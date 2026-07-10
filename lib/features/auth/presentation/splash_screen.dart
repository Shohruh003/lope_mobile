import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/shared.dart';
import 'auth_controller.dart';

/// Splash — Uzum/Click darajasidagi kirish sahifasi.
///   - Radial gradient background
///   - Gradient icon pill with glow, scale-in animation
///   - Wordmark with subtle rise + fade
///   - Tagline (Sartaroshingiz — bir bosishda)
///   - 3-dot bouncing loader at the bottom
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
    switch (user.role) {
      case 'barber':
      case 'stylist':
      case 'cosmetologist':
        context.go('/barber-app');
        break;
      case 'barbershop':
        context.go('/shop');
        break;
      case 'shop':
        context.go('/lopepay');
        break;
      case 'admin':
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
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (!next.loading) _maybeRoute();
    });

    // Splash body reuses the shared BrandedLoader so it matches the web
    // pre-Flutter splash and any in-app hero loading state — one
    // consistent animation everywhere.
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: BrandedLoader(),
    );
  }
}
