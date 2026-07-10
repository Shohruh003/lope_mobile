import 'package:flutter/material.dart';

import '../theme/lope_colors.dart';
import '../theme/radius.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import 'tap_scale.dart';

/// Ilova bo'yicha yagona card komponenti. Uch variant:
///
///   AppCardVariant.flat     — surface, 1px border, no shadow (list item)
///   AppCardVariant.outlined — subtle shadow qo'shiladi (default)
///   AppCardVariant.elevated — kattaroq shadow (hero, dashboard block)
///
/// Tap qilinsa avtomatik TapScale + haptik ishlaydi.
enum AppCardVariant { flat, outlined, elevated }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = AppCardVariant.outlined,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.radius = AppRadius.lg,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final effectiveColor = color ?? palette.surface;
    final effectiveBorder = borderColor ?? palette.border;

    final decoration = BoxDecoration(
      color: gradient == null ? effectiveColor : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: variant == AppCardVariant.flat
          ? Border.all(color: effectiveBorder, width: 1)
          : Border.all(color: effectiveBorder.withValues(alpha: 0.6), width: 1),
      boxShadow: switch (variant) {
        AppCardVariant.flat => null,
        AppCardVariant.outlined => AppShadows.subtle,
        AppCardVariant.elevated => AppShadows.card,
      },
    );

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null && onLongPress == null) return content;

    return TapScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}
