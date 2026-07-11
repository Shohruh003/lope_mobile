import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_mode_provider.dart';
import '../../core/tr.dart';
import '../shared.dart';

/// Settings-list row for switching between system / light / dark theme
/// modes. Tapping the tile opens a bottom sheet with the three options
/// and persists the pick through [themeModeProvider]. Shared between
/// customer profile and barber settings so both panels get a real
/// theme toggle (previously the barber panel had no way to switch).
///
/// Designed to drop into an [AppCard] / [_TileGroup]-style container:
/// the tile itself renders as a padded row without its own background.
class AppThemeTile extends ConsumerWidget {
  const AppThemeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    return TapScale(
      onTap: () => _pickTheme(context, ref, mode),
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: AppRadius.rSm,
            ),
            alignment: Alignment.center,
            child:
                Icon(_iconFor(mode), color: AppColors.primary, size: 18),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              tr(ref, 'mobile.profile.theme', 'Rejim'),
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textBright,
              ),
            ),
          ),
          Text(
            _labelFor(ref, mode),
            style:
                AppText.bodySm.copyWith(color: context.colors.textMuted),
          ),
          AppSpacing.hGapSm,
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
      ),
    );
  }

  static IconData _iconFor(ThemeMode m) => switch (m) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        ThemeMode.system => Icons.brightness_auto_outlined,
      };

  String _labelFor(WidgetRef ref, ThemeMode m) => switch (m) {
        ThemeMode.light =>
          tr(ref, 'mobile.profile.themeLight', "Yorug'"),
        ThemeMode.dark =>
          tr(ref, 'mobile.profile.themeDark', "Qorong'i"),
        ThemeMode.system =>
          tr(ref, 'mobile.profile.themeSystem', 'Tizim'),
      };

  Future<void> _pickTheme(
      BuildContext context, WidgetRef ref, ThemeMode current) async {
    AppHaptics.light();
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => SafeArea(
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
                    color: context.colors.border,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
              ),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'mobile.profile.theme', 'Rejim'),
                style: AppText.titleMd,
              ),
              const SizedBox(height: 4),
              Text(
                tr(ref, 'mobile.profile.themeHint',
                    "Ilovaning yorug' va qorong'i rejimi tanlangan sozlamalarga qarab moslashadi."),
                style: AppText.caption,
              ),
              AppSpacing.gapMd,
              for (final opt in [
                (
                  ThemeMode.system,
                  tr(ref, 'mobile.profile.themeSystem', 'Tizim')
                ),
                (
                  ThemeMode.light,
                  tr(ref, 'mobile.profile.themeLight', "Yorug'")
                ),
                (
                  ThemeMode.dark,
                  tr(ref, 'mobile.profile.themeDark', "Qorong'i")
                ),
              ])
                TapScale(
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetCtx).pop(opt.$1);
                  },
                  scale: 0.98,
                  child: Container(
                    margin:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: opt.$1 == current
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : context.colors.surfaceElevated,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(
                        color: opt.$1 == current
                            ? AppColors.primary
                            : context.colors.border,
                      ),
                    ),
                    child: Row(children: [
                      Icon(_iconFor(opt.$1),
                          color: opt.$1 == current
                              ? AppColors.primary
                              : context.colors.textMuted,
                          size: 22),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Text(
                          opt.$2,
                          style: AppText.body.copyWith(
                            color: opt.$1 == current
                                ? AppColors.primary
                                : context.colors.textBright,
                            fontWeight: opt.$1 == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (opt.$1 == current)
                        const Icon(Icons.check,
                            color: AppColors.primary, size: 20),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(themeModeProvider.notifier).setMode(picked);
  }
}
