import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/presentation/top_up_modal.dart';
import '../data/shop_repository.dart';

class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        // "Profil" — this screen is now a hub for personal + salon
        // settings, theme / language, support links and destructive
        // actions. Renamed from "Sozlamalar" per user's mental model
        // of the drawer entry.
        title: Text(
          tr(ref, 'mobile.tabs.profile', 'Profil'),
          style: AppText.titleMd,
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
        children: [
          _SectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          AppSpacing.gapSm,
          // Balance hero + top-up CTA lives inside Profil (not the
          // drawer) — user explicitly asked for it here. The chip in
          // the shell header is the quick-glance version; this card
          // is the actionable one.
          _BalanceCard(
            onTopUp: () => TopUpModal.show(context),
          ),
          AppSpacing.gapMd,
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
          // Adminlar and Eslatmalar live in the drawer already — leave
          // Profil focused on info-editing entries only.
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.storefront_outlined,
              iconColor: AppColors.primary,
              label: tr(
                  ref, 'mobile.shop.settings.salonProfile', 'Salon profili'),
              onTap: () => context.push('/shop/profile'),
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

/// Balance hero shown at the top of the Profil page — big amount
/// readout plus a primary "To'ldirish" CTA that opens [TopUpModal].
/// The shell header chip stays synced via [shopBalanceProvider].
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.onTopUp});
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopBalanceProvider);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rLg,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 22),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(ref, 'mobile.lopepay.home.balance', 'Balans'),
                    style: AppText.overline
                        .copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 2),
                  async.when(
                    loading: () => Text('вЂ¦',
                        style: AppText.titleLg
                            .copyWith(color: Colors.white)),
                    error: (_, _) => Text('—',
                        style: AppText.titleLg
                            .copyWith(color: Colors.white)),
                    data: (b) => Text(
                      "${_fmt(b)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.titleLg
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          AppSpacing.gapMd,
          TapScale(
            onTap: onTopUp,
            scale: 0.96,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.rMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    tr(ref, 'topUp.title', "Balansni to'ldirish"),
                    style: AppText.button
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return (n < 0 ? 'в€’' : '') + buf.toString();
  }
}
