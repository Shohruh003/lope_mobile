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
      body: Stack(
        children: [
          // Fon gradient — Click/Payme uslubidagi yumshoq atmosfera.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.10),
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
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        AppColors.primary.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.24),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.content_cut, color: AppColors.primary, size: 40),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1.0, 1.0),
                      duration: 700.ms,
                      curve: Curves.easeOutBack,
                    )
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 20),
                const Text(
                  'Lope Style',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.textBright,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 200.ms)
                    .moveY(begin: 8, end: 0, duration: 500.ms, delay: 200.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text(
                  "Sartaroshingiz — bir bosishda",
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    letterSpacing: 0.1,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms, delay: 350.ms),
              ],
            ),
          ),
          // Pastda loading dot animatsiyasi (spinner emas — yumshoqroq).
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
                        .animate(
                          onPlay: (c) => c.repeat(reverse: true),
                        )
                        .fadeIn(duration: 400.ms, delay: (500 + i * 120).ms)
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
