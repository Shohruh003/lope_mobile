import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme/colors.dart';
import '../theme/lope_colors.dart';
import '../theme/motion.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Filter chip — sartaroshlar sahifasidagi filterlar (Sevimlilar/Bo'sh/...)
/// va boshqa joylar uchun. Selection state ijobiy vizual signal beradi:
/// primary rang fon, kichik glow.
class AppChip extends StatefulWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.leadingIcon,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final int? count;

  @override
  State<AppChip> createState() => _AppChipState();
}

class _AppChipState extends State<AppChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final disabled = widget.onTap == null;
    final selected = widget.selected;

    final bg = selected ? AppColors.primary : palette.surfaceElevated;
    final fg = selected ? Colors.white : palette.textPrimary;
    final borderColor = selected ? AppColors.primary : palette.border;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled
          ? null
          : (_) {
              setState(() => _pressed = false);
              AppHaptics.selection();
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: AppMotion.short,
        curve: AppMotion.standard,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.rPill,
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leadingIcon != null) ...[
                Icon(widget.leadingIcon, size: 14, color: fg),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                widget.label,
                style: AppText.body.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : palette.background,
                    borderRadius: AppRadius.rPill,
                  ),
                  child: Text(
                    '${widget.count}',
                    style: AppText.caption.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
