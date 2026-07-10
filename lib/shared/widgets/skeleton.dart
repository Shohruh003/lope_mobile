import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/lope_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

/// Shimmer bilan skeleton loaderlar — sahifa yuklanayotganda "hech narsa
/// yo'q" empty ekrannni ko'rsatish o'rniga elementlar shakli aksini
/// beramiz. Uzum Bank / Click darajasidagi ilova hech qachon
/// CircularProgressIndicator o'rtasida "aylanish" bilan yuklanmaydi.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final palette = context.colors;
    return Shimmer.fromColors(
      baseColor: palette.surfaceElevated,
      highlightColor: palette.border,
      period: const Duration(milliseconds: 1400),
      child: child,
    );
  }
}

/// Bitta gorizontal matn qatori shakli.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// To'garak (avatar placeholder).
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// To'rtburchak (rasm, katta card placeholder).
class SkeletonRect extends StatelessWidget {
  const SkeletonRect({
    super.key,
    this.width,
    this.height = 80,
    this.radius = AppRadius.md,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Barber list item skeleton — 2-columnli grid uchun tayyor kartochka shakli.
class SkeletonBarberCard extends StatelessWidget {
  const SkeletonBarberCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonRect(height: 100, radius: AppRadius.md),
          SizedBox(height: AppSpacing.md),
          SkeletonLine(width: 120, height: 14),
          SizedBox(height: AppSpacing.sm),
          SkeletonLine(width: 80, height: 10),
          SizedBox(height: AppSpacing.md),
          SkeletonRect(height: 36, radius: AppRadius.sm),
        ],
      ),
    );
  }
}
