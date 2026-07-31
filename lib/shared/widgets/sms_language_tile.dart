import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tr.dart';
import '../shared.dart';

/// Settings-list row that lets a barber (or shop owner) pick the language
/// for OUTGOING customer SMS — booking confirmations, reminders, retention.
/// Not to be confused with the app UI language (see [AppLanguageTile]).
///
/// - Barber use: current comes from Barber.smsLanguage; null means "inherit
///   from shop" (barber-managed) or "default uz" (standalone).
/// - Shop use: current comes from Barbershop.smsLanguage; never null.
///
/// The caller passes an async [onSave] that does the network mutation and
/// throws on failure. This widget shows a bottom sheet, calls onSave, and
/// pops back to the settings screen.
class SmsLanguageTile extends ConsumerWidget {
  const SmsLanguageTile({
    super.key,
    required this.currentValue,
    required this.onSave,
    this.showInherit = false,
  });

  /// Current stored value ('uz' | 'ru' | null). Null renders as "inherit"
  /// when [showInherit] is true, or as 'uz' otherwise.
  final String? currentValue;

  /// Persist the pick. Called with 'uz', 'ru', or null (inherit).
  /// Throws on failure so this widget can surface a snackbar.
  final Future<void> Function(String? newValue) onSave;

  /// Whether to offer the "Salon sozlamasidan" (inherit) option. On for
  /// shop-managed barbers, off for shop-owner and standalone barber.
  final bool showInherit;

  String _labelFor(String? v, WidgetRef ref) {
    if (v == null) {
      return tr(ref, 'mobile.smsLanguage.inherit', 'Salon sozlamasidan');
    }
    if (v == 'ru') return tr(ref, 'mobile.smsLanguage.ru', 'Русский');
    return tr(ref, 'mobile.smsLanguage.uz', "O'zbek");
  }

  String _flagFor(String? v) {
    if (v == null) return '⚙';
    if (v == 'ru') return '🇷🇺';
    return '🇺🇿';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TapScale(
      onTap: () => _pick(context, ref),
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
            child: const Icon(Icons.sms_outlined,
                color: AppColors.primary, size: 18),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(ref, 'mobile.smsLanguage.title', 'SMS tili'),
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textBright,
                  ),
                ),
                Text(
                  tr(ref, 'mobile.smsLanguage.subtitle',
                      "Mijozlarga yuboriladigan SMS matnining tili"),
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted),
                ),
              ],
            ),
          ),
          Text(_flagFor(currentValue),
              style: const TextStyle(fontSize: 18)),
          AppSpacing.hGapXs,
          Text(_labelFor(currentValue, ref),
              style: AppText.bodySm
                  .copyWith(color: context.colors.textMuted)),
          AppSpacing.hGapSm,
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final options = <(String?, String, String)>[
      if (showInherit)
        (null,
            tr(ref, 'mobile.smsLanguage.inherit', 'Salon sozlamasidan'),
            '⚙'),
      ('uz', tr(ref, 'mobile.smsLanguage.uz', "O'zbek"), '🇺🇿'),
      ('ru', tr(ref, 'mobile.smsLanguage.ru', 'Русский'), '🇷🇺'),
    ];
    final picked = await showModalBottomSheet<_PickResult>(
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
                tr(ref, 'mobile.smsLanguage.title', 'SMS tili'),
                style: AppText.titleMd
                    .copyWith(color: context.colors.textBright),
              ),
              const SizedBox(height: 4),
              Text(
                tr(ref, 'mobile.smsLanguage.subtitle',
                    "Mijozlarga yuboriladigan SMS matnining tili"),
                style: AppText.caption
                    .copyWith(color: context.colors.textSecondary),
              ),
              AppSpacing.gapMd,
              for (final opt in options)
                TapScale(
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetCtx).pop(_PickResult(opt.$1));
                  },
                  scale: 0.98,
                  child: Container(
                    margin:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: opt.$1 == currentValue
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : context.colors.surfaceElevated,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(
                        color: opt.$1 == currentValue
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
                            color: opt.$1 == currentValue
                                ? AppColors.primary
                                : context.colors.textBright,
                            fontWeight: opt.$1 == currentValue
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (opt.$1 == currentValue)
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
    if (picked == null || picked.value == currentValue) return;
    try {
      await onSave(picked.value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.smsLanguage.saved', 'Saqlandi')),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${tr(ref, 'common.error', 'Xatolik')}: ${e.toString()}'),
        ));
      }
    }
  }
}

/// Wrapper so the picker can distinguish "user picked null (inherit)"
/// from "user dismissed the sheet". Bottom-sheet pop returns null in
/// both cases otherwise.
class _PickResult {
  const _PickResult(this.value);
  final String? value;
}
