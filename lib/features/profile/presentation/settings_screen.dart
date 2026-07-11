import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/l10n.dart';
import '../../../core/roles.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';

/// Settings screen — grouped list of tiles with the new design system.
/// State/API preserved: locale change, logout, delete-request POST.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final localeAsync = ref.watch(localeProvider);
    final currentLocale = localeAsync.asData?.value.locale ?? 'uz';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'barberApp.settings', 'Sozlamalar'),
          style: AppText.titleMd,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          // ═══════════ Account section ═══════════
          _SectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.edit_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'profile.editProfile', 'Profilni tahrirlash'),
              onTap: () => context.push(isBarberRole(user?.role)
                  ? '/barber/profile'
                  : '/profile-edit'),
            ),
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.success,
              label: tr(ref, 'myTransactions.title', 'Hisobim'),
              onTap: () => context.push('/transactions'),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'barberApp.notifications', 'Bildirishnomalar'),
              onTap: () => context.push('/notifications'),
            ),
            _SettingsTile(
              icon: Icons.card_giftcard_outlined,
              iconColor: AppColors.warning,
              label: tr(ref, 'promoCode.title', 'Promo kod'),
              onTap: () => context.push('/promo'),
            ),
          ]),

          AppSpacing.gapXl,

          // ═══════════ App section ═══════════
          _SectionLabel(
              tr(ref, 'profile.section.app', 'Ilova').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.language_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'barberApp.language', 'Til'),
              trailing: Text(
                _localeLabel(currentLocale),
                style: AppText.bodySm.copyWith(color: context.colors.textMuted),
              ),
              onTap: () => _pickLanguage(context, ref, currentLocale),
            ),
          ]),

          AppSpacing.gapXl,

          // ═══════════ Help section ═══════════
          _SectionLabel(
              tr(ref, 'profile.section.help', 'Yordam').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.help_outline,
              iconColor: AppColors.primary,
              label: tr(ref, 'profile.faq',
                  'FAQ — Tez-tez beriladigan savollar'),
              onTap: () => _openUrl('https://lopestyle.uz/faq'),
            ),
            _SettingsTile(
              icon: Icons.support_agent_outlined,
              iconColor: AppColors.success,
              label: tr(ref, 'barberApp.support', "Qo'llab-quvvatlash"),
              onTap: () => _openUrl('https://t.me/lopestyle_support'),
            ),
            _SettingsTile(
              icon: Icons.policy_outlined,
              iconColor: context.colors.textMuted,
              label: tr(ref, 'profile.privacy', 'Maxfiylik siyosati'),
              onTap: () => _openUrl('https://lopestyle.uz/privacy'),
            ),
          ]),

          AppSpacing.gapXl,

          // ═══════════ Danger zone ═══════════
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.logout_outlined,
              iconColor: context.colors.textMuted,
              label: tr(ref, 'barberApp.logout', 'Chiqish'),
              onTap: () => _confirmLogout(context, ref),
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              iconColor: AppColors.danger,
              label: tr(ref, 'barberApp.deleteAccount',
                  "Hisobni o'chirish"),
              destructive: true,
              onTap: () => _confirmDelete(context, ref),
            ),
          ]),
        ],
      ),
    );
  }

  String _localeLabel(String code) => switch (code) {
        'uz' => "O'zbekcha",
        'uz_cyr' => 'Ўзбекча',
        'ru' => 'Русский',
        'en' => 'English',
        _ => code,
      };

  Future<void> _pickLanguage(
      BuildContext context, WidgetRef ref, String current) async {
    AppHaptics.light();
    final picked = await showModalBottomSheet<String>(
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
                tr(ref, 'barberApp.language', 'Til'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapMd,
              for (final code in const ['uz', 'uz_cyr', 'ru', 'en'])
                TapScale(
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetCtx).pop(code);
                  },
                  scale: 0.98,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: code == current
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : context.colors.surfaceElevated,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(
                        color: code == current
                            ? AppColors.primary
                            : context.colors.border,
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                          _localeLabel(code),
                          style: AppText.body.copyWith(
                            color: code == current
                                ? AppColors.primary
                                : context.colors.textBright,
                            fontWeight: code == current
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (code == current)
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final ok = await _confirmDialog(
      context,
      ref,
      title: '${tr(ref, 'barberApp.logout', 'Chiqish')}?',
      message: tr(ref, 'profile.logoutConfirm',
          'Tizimdan chiqib, login sahifasiga qaytasiz.'),
      confirmLabel: tr(ref, 'barberApp.logout', 'Chiqish'),
      confirmVariant: AppButtonVariant.danger,
      iconColor: context.colors.textMuted,
      icon: Icons.logout,
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return;
    AppHaptics.light();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final ok = await _confirmDialog(
      context,
      ref,
      title: '${tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish")}?',
      message: tr(ref, 'barberApp.deleteAccountConfirm',
          "Hisobingiz va barcha ma'lumotlaringiz o'chiriladi. Bu jarayonni bekor qilib bo'lmaydi."),
      confirmLabel: tr(ref, 'common.delete', "O'chirish"),
      confirmVariant: AppButtonVariant.danger,
      iconColor: AppColors.danger,
      icon: Icons.delete_outline,
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/users/delete-request',
          data: <String, dynamic>{});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'barberApp.deleteAccountQueued',
                "O'chirish so'rovingiz qabul qilindi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
      return;
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}

// ═══════════ Reusable local widgets ═══════════

Future<bool?> _confirmDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required String confirmLabel,
  required AppButtonVariant confirmVariant,
  required Color iconColor,
  required IconData icon,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dCtx) => Dialog(
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              AppSpacing.hGapMd,
              Expanded(child: Text(title, style: AppText.titleMd)),
            ]),
            AppSpacing.gapMd,
            Text(message, style: AppText.bodySm),
            AppSpacing.gapLg,
            Row(children: [
              Expanded(
                child: AppButton(
                  label: tr(ref, 'common.cancel', 'Bekor'),
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.pop(dCtx, false),
                  fullWidth: true,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  variant: confirmVariant,
                  onPressed: () => Navigator.pop(dCtx, true),
                  fullWidth: true,
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Text(text, style: AppText.overline),
    );
  }
}

class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                color: context.colors.border,
                height: 1,
                indent: AppSpacing.xxl + AppSpacing.md,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
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
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: destructive
                    ? AppColors.danger
                    : context.colors.textBright,
              ),
            ),
          ),
          ?trailing,
          AppSpacing.hGapSm,
          Icon(
            Icons.chevron_right,
            color: destructive
                ? AppColors.danger.withValues(alpha: 0.7)
                : context.colors.textMuted,
            size: 18,
          ),
        ]),
      ),
    );
  }
}
