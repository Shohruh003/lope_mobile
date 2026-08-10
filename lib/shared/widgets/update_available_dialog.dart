import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/tr.dart';
import '../../core/update_check_service.dart';
import '../shared.dart';

/// Rounded bottom-sheet style dialog telling the user a new version is
/// live on their store. Two flavours:
///
///   softUpdate — dismissable, "Yangilash" + "Keyinroq" buttons.
///   hardUpdate — non-dismissable (barrier tap does nothing, no
///     Keyinroq button, no back button on Android).
///
/// The "Yangilash" button opens the App Store / Play Market URL from
/// [MobileConfig.storeUrl].
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({
    super.key,
    required this.result,
  });

  final UpdateCheckResult result;

  bool get _isHard => result.status == UpdateStatus.hardUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = result.config;
    if (config == null) return const SizedBox.shrink();
    final palette = context.colors;
    // For hard update we wrap in PopScope to block Android back button.
    // Soft update just uses the framework's default dismiss behaviour.
    return PopScope(
      canPop: !_isHard,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.rXl,
                    boxShadow: AppShadows.primaryGlow(AppColors.primary),
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              AppSpacing.gapLg,
              Text(
                _isHard
                    ? tr(ref, 'mobile.update.hardTitle', 'Yangilash majburiy')
                    : tr(ref, 'mobile.update.softTitle', 'Yangi versiya mavjud'),
                style: AppText.titleLg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _isHard
                    ? tr(
                        ref,
                        'mobile.update.hardBody',
                        'Bu versiya (eskirdi). Davom etish uchun ilovani yangilang.',
                      )
                    : tr(
                        ref,
                        'mobile.update.softBody',
                        'Lope Style yangi versiyasi chiqdi. Yangi imkoniyatlar va yaxshilanishlar bor.',
                      ),
                style: AppText.body.copyWith(color: palette.textMuted),
                textAlign: TextAlign.center,
              ),
              if (result.currentVersion.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  tr(
                    ref,
                    'mobile.update.versionLine',
                    'Joriy: {{current}}    Yangi: {{latest}}',
                    {
                      'current': result.currentVersion,
                      'latest': config.latestVersion,
                    },
                  ),
                  style: AppText.caption
                      .copyWith(color: palette.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapXl,
              AppButton(
                label: tr(ref, 'mobile.update.updateBtn', 'Yangilash'),
                trailingIcon: Icons.arrow_outward,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: () async {
                  final uri = Uri.tryParse(config.storeUrl);
                  if (uri == null) return;
                  // externalApplication launches the store app directly
                  // on both platforms — leaves the browser in the dust.
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              if (!_isHard) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: tr(ref, 'mobile.update.laterBtn', 'Keyinroq'),
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
