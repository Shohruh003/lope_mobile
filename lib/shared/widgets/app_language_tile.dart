import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/tr.dart';
import '../shared.dart';

/// Settings-list row that swaps the app UI language. Reads the active
/// locale from [localeProvider] and opens a bottom sheet of options
/// (O'zbek / Ўзбек / Русский / English) on tap. Persists the pick
/// through the same provider so it survives restarts.
///
/// Shared across every panel's settings screen (customer profile,
/// barber settings, shop settings) so all three surface the same
/// tile in the same place.
class AppLanguageTile extends ConsumerWidget {
  const AppLanguageTile({super.key});

  static const _options = [
    ('uz', "O'zbek", '🇺🇿'),
    ('uz_cyr', 'Ўзбек', '🇺🇿'),
    ('ru', 'Русский', '🇷🇺'),
    ('en', 'English', '🇺🇸'),
  ];

  String _label(String code) {
    for (final o in _options) {
      if (o.$1 == code) return o.$2;
    }
    return code;
  }

  String _flag(String code) {
    for (final o in _options) {
      if (o.$1 == code) return o.$3;
    }
    return '🌐';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang =
        ref.watch(localeProvider).asData?.value.locale ?? 'uz';
    return TapScale(
      onTap: () => _pick(context, ref, currentLang),
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
            child: const Icon(Icons.language,
                color: AppColors.primary, size: 18),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              tr(ref, 'barberApp.language', 'Til'),
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textBright,
              ),
            ),
          ),
          Text(_flag(currentLang),
              style: const TextStyle(fontSize: 18)),
          AppSpacing.hGapXs,
          Text(_label(currentLang),
              style: AppText.bodySm
                  .copyWith(color: context.colors.textMuted)),
          AppSpacing.hGapSm,
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, String current) async {
    AppHaptics.light();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape:
          const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
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
                tr(ref, 'barberApp.language', 'Til'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapMd,
              for (final opt in _options)
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
                      Text(opt.$3,
                          style: const TextStyle(fontSize: 22)),
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
    await ref.read(localeProvider.notifier).setLocale(picked);
  }
}
