import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';

class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _SectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.person_outline,
              iconColor: AppColors.primary,
              label: tr(ref, 'profile.editProfile', 'Profilni tahrirlash'),
              onTap: () => context.push('/profile-edit'),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionLabel(tr(ref, 'mobile.shop.settings.salon', 'SALON')),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.storefront_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'profile.barberProfile', 'Salon profili'),
              onTap: () => context.push('/shop/profile'),
            ),
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              iconColor: AppColors.warning,
              label: tr(ref, 'shop.nav.admins', 'Adminlar'),
              onTap: () => context.push('/shop/admins'),
            ),
            _SettingsTile(
              icon: Icons.alarm,
              iconColor: AppColors.success,
              label: tr(ref, 'barberApp.reminderSettings', 'Eslatmalar'),
              onTap: () => context.push('/shop/reminders'),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionLabel(
              tr(ref, 'profile.section.preferences', 'Sozlamalar')
                  .toUpperCase()),
          AppSpacing.gapSm,
          const _TileGroup(children: [
            AppThemeTile(),
            AppLanguageTile(),
          ]),
          AppSpacing.gapXl,
          _SectionLabel(
              tr(ref, 'profile.section.help', 'Yordam').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
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
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.logout,
              iconColor: context.colors.textMuted,
              label: tr(ref, 'barberApp.logout', 'Chiqish'),
              onTap: () async {
                AppHaptics.light();
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
            _SettingsTile(
              icon: Icons.delete_outline,
              iconColor: AppColors.danger,
              label: tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish"),
              destructive: true,
              onTap: () => _confirmDelete(context, ref),
            ),
          ]),
        ],
      ),
    );
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
    final ok = await showDialog<bool>(
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
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 22),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Text(
                    '${tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish")}?',
                    style: AppText.titleMd,
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'barberApp.deleteAccountConfirm',
                    "Hisobingiz va barcha ma'lumotlaringiz o'chiriladi. Bu jarayonni bekor qilib bo'lmaydi."),
                style: AppText.bodySm,
              ),
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
                    label: tr(ref, 'common.delete', "O'chirish"),
                    variant: AppButtonVariant.danger,
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
    if (ok != true) return;
    try {
      await ref
          .read(dioProvider)
          .post('/users/delete-request', data: <String, dynamic>{});
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
    this.destructive = false,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
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
