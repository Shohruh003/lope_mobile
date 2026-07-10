import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme/colors.dart';
import '../theme/motion.dart';
import '../theme/radius.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, success }
enum AppButtonSize { sm, md, lg }
// Note: HapticStrength lives in ../haptics.dart — TapScale bilan bir xil enum
// ishlatilishi uchun. Bu yerda import qilingan (yuqoridagi haptics.dart).

/// Ilova bo'yicha yagona tugma. Loading state, ikon, disabled — hammasi
/// bir joyda. Primary tugma yumshoq glow bilan CTA'ni ajratib turadi.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.fullWidth = false,
    this.hapticStrength = HapticStrength.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool fullWidth;
  final HapticStrength hapticStrength;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  double get _height => switch (widget.size) {
        AppButtonSize.sm => 36,
        AppButtonSize.md => 44,
        AppButtonSize.lg => 52,
      };

  EdgeInsets get _padding => switch (widget.size) {
        AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        AppButtonSize.md => const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      };

  TextStyle get _textStyle {
    final base = widget.size == AppButtonSize.lg ? AppText.buttonLg : AppText.button;
    return base.copyWith(color: _fg);
  }

  Color get _bg {
    if (widget.onPressed == null) return AppColors.surfaceElevated;
    return switch (widget.variant) {
      AppButtonVariant.primary => AppColors.primary,
      AppButtonVariant.secondary => AppColors.surfaceElevated,
      AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.danger => AppColors.danger,
      AppButtonVariant.success => AppColors.success,
    };
  }

  Color get _fg {
    if (widget.onPressed == null) return AppColors.textMuted;
    return switch (widget.variant) {
      AppButtonVariant.primary => Colors.white,
      AppButtonVariant.secondary => AppColors.textPrimary,
      AppButtonVariant.ghost => AppColors.primary,
      AppButtonVariant.danger => Colors.white,
      AppButtonVariant.success => Colors.white,
    };
  }

  Border? get _border {
    if (widget.variant == AppButtonVariant.secondary) {
      return Border.all(color: AppColors.border, width: 1);
    }
    return null;
  }

  List<BoxShadow>? get _shadow {
    if (widget.onPressed == null) return null;
    if (widget.variant == AppButtonVariant.primary && !_pressed) {
      return AppShadows.primaryGlow(AppColors.primary);
    }
    return null;
  }

  void _fireHaptic() {
    switch (widget.hapticStrength) {
      case HapticStrength.none:
        return;
      case HapticStrength.light:
        AppHaptics.light();
        break;
      case HapticStrength.medium:
        AppHaptics.medium();
        break;
      case HapticStrength.selection:
        AppHaptics.selection();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    final child = AnimatedContainer(
      duration: AppMotion.short,
      curve: AppMotion.standard,
      height: _height,
      padding: _padding,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: AppRadius.rMd,
        border: _border,
        boxShadow: _shadow,
      ),
      child: Row(
        mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _fg,
              ),
            )
          else ...[
            if (widget.leadingIcon != null) ...[
              Icon(widget.leadingIcon, size: 18, color: _fg),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(widget.label, style: _textStyle),
            if (widget.trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(widget.trailingIcon, size: 18, color: _fg),
            ],
          ],
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              _fireHaptic();
              widget.onPressed?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppMotion.short,
        curve: AppMotion.standard,
        child: child,
      ),
    );
  }
}
