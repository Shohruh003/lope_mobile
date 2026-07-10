import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.rXxl,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.content_cut,
                      color: Colors.white, size: 44),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms),
                AppSpacing.gapXl,
                Text(
                  'Lope Style',
                  style: AppText.display.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .moveY(
                        begin: 8,
                        end: 0,
                        duration: 500.ms,
                        delay: 200.ms,
                        curve: AppMotion.emphasized),
                AppSpacing.gapSm,
                Text(
                  'Sartaroshingiz — bir bosishda',
                  style: AppText.bodyLg.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.1,
                  ),
                ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .fadeIn(
                            duration: 400.ms, delay: (500 + i * 120).ms)
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1.0, 1.0),
                          duration: 600.ms,
                          delay: (i * 120).ms,
                          curve: Curves.easeInOut,
                        ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
