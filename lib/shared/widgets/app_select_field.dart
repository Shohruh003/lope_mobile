import 'package:flutter/material.dart';

import '../haptics.dart';
import '../theme/lope_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import 'tap_scale.dart';

/// One value in a select. `icon` is optional; when set it shows up in
/// the picker sheet next to the label.
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Replacement for the stock Material `DropdownButtonFormField`. Shows
/// as a tap-scaling input tile with the current label + chevron, and
/// opens a bottom sheet with each option as a rounded row (icon square,
/// label, selection check). The sheet inherits the app palette so it
/// looks identical in light and dark modes.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    this.hint,
  });

  final String label;
  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Leading icon on the picker tile itself.
  final IconData? icon;

  /// Optional placeholder shown when [value] isn't in [options].
  final String? hint;

  AppSelectOption<T>? get _current {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final current = _current;
    return TapScale(
      onTap: () => _openSheet(context),
      haptic: HapticStrength.selection,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: palette.border),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: AppRadius.rSm,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: palette.textMuted),
            ),
            AppSpacing.hGapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.overline),
                const SizedBox(height: 2),
                Text(
                  current?.label ?? hint ?? '—',
                  style: AppText.titleSm.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.expand_more, size: 20, color: palette.textMuted),
        ]),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final palette = context.colors;
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) {
        final sheetPalette = sheetCtx.colors;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetPalette.border,
                      borderRadius: AppRadius.rPill,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Text(label, style: AppText.titleMd),
                AppSpacing.gapMd,
                for (final opt in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TapScale(
                      onTap: () {
                        AppHaptics.selection();
                        Navigator.of(sheetCtx).pop(opt.value);
                      },
                      scale: 0.98,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: opt.value == value
                              ? sheetPalette.surfaceElevated
                              : sheetPalette.surface,
                          borderRadius: AppRadius.rMd,
                          border: Border.all(
                            color: opt.value == value
                                ? sheetPalette.textPrimary
                                    .withValues(alpha: 0.3)
                                : sheetPalette.border,
                          ),
                        ),
                        child: Row(children: [
                          if (opt.icon != null) ...[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: sheetPalette.background,
                                borderRadius: AppRadius.rSm,
                              ),
                              alignment: Alignment.center,
                              child: Icon(opt.icon,
                                  size: 16,
                                  color: sheetPalette.textPrimary),
                            ),
                            AppSpacing.hGapMd,
                          ],
                          Expanded(
                            child: Text(
                              opt.label,
                              style: AppText.body.copyWith(
                                fontWeight: opt.value == value
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (opt.value == value)
                            Icon(Icons.check,
                                size: 20,
                                color: sheetPalette.textBright),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && picked != value) onChanged(picked);
  }
}
