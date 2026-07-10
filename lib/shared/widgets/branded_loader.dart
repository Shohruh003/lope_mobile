import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Lope Style branded loading UI. Uses the same gradient logo pill,
/// wordmark, tagline and bouncing-dot animation as the web splash and
/// SplashScreen widget so full-page loading states across the app feel
/// like one continuous experience — no random spinners.
///
///   BrandedLoader()                   full-screen (default)
///   BrandedLoader(compact: true)      logo + dots only, tight footprint
///   BrandedLoader(message: "...")     custom subtitle line
///
/// Prefer skeleton widgets (AppListSkeleton, SkeletonRect) for
/// list/content loading — this loader is meant for hero-level waits
/// (splash, AI generation, initial app open).
class BrandedLoader extends StatelessWidget {
  const BrandedLoader({
    super.key,
    this.compact = false,
    this.message,
  });

  /// When true — hide the brand + tagline; keep just the logo pill and
  /// bouncing dots. Fits inline slots (dialogs, cards).
  final bool compact;

  /// Optional line under the brand. Falls back to the default tagline
  /// when null on the full-size variant. Ignored in compact mode.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 64.0 : 96.0;
    final radius = compact ? AppRadius.lg : AppRadius.xl;
    return Container(
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
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
                ...AppShadows.card,
              ],
            ),
            child: Icon(
              Icons.content_cut,
              color: Colors.white,
              size: logoSize * 0.46,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.06, 1.06),
                duration: 1100.ms,
                curve: Curves.easeInOut,
              ),
          if (!compact) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Lope Style',
              style: AppText.titleLg.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message ?? 'Sartaroshingiz — bir bosishda',
              style: AppText.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
          _BouncingDots(size: compact ? 6 : 8),
        ],
      ),
    );
  }
}

class _BouncingDots extends StatelessWidget {
  const _BouncingDots({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size / 2.5),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
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
    );
  }
}
