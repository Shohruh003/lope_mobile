import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppBadgeVariant { success, warning, danger, info, neutral, primary }

/// Kichik status badge (masalan "Bo'sh"/"Band"/"Tasdiqlangan"). Yumshoq
/// tinted fon + kuchli matn — Uzum/Click va Stripe dashboardidagi kabi.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.dot = false,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;

  /// Chap tomonda kichik doira ko'rsatish (bo'sh/band uchun mos).
  final bool dot;

  Color get _color => switch (variant) {
        AppBadgeVariant.success => AppColors.success,
        AppBadgeVariant.warning => AppColors.warning,
        AppBadgeVariant.danger => AppColors.danger,
        AppBadgeVariant.info => AppColors.primary,
        AppBadgeVariant.neutral => AppColors.textMuted,
        AppBadgeVariant.primary => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.rPill,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
