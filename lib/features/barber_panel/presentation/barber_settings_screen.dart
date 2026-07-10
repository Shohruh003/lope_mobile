import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';
import '../data/barber_profile_repository.dart';

class BarberSettingsScreen extends ConsumerWidget {
  const BarberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
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
          if (user != null) ...[
            _AvailabilityTile(userId: user.id),
            AppSpacing.gapLg,
          ],
          _SectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.edit_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'profile.editProfile', 'Profilni tahrirlash'),
              onTap: () => context.push('/barber/profile'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              iconColor: AppColors.warning,
              label: tr(ref, 'barberApp.accountSettings',
                  'Akkaunt sozlamalari'),
              onTap: () => context.push('/barber/account-edit'),
            ),
            _SettingsTile(
              icon: Icons.notifications_active_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'barberApp.reminderSettings',
                  'Eslatma sozlamalari'),
              onTap: () => context.push('/barber/reminders'),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionLabel(
              tr(ref, 'barberApp.management', 'Boshqaruv').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.people_outline,
              iconColor: AppColors.success,
              label: tr(ref, 'barberMyClients.title', 'Mijozlarim'),
              onTap: () => context.push('/barber/my-clients'),
            ),
            _SettingsTile(
              icon: Icons.credit_card_outlined,
              iconColor: AppColors.primary,
              label: tr(ref, 'barberApp.cards', "To'lov kartalarim"),
              onTap: () => context.push('/barber/cards'),
            ),
            _SettingsTile(
              icon: Icons.local_offer_outlined,
              iconColor: AppColors.warning,
              label: tr(ref, 'promoCode.title', 'Promo kodlar'),
              onTap: () => context.push('/barber/promo-code'),
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              iconColor: AppColors.danger,
              label: tr(ref, 'barberApp.myLocation', 'Manzilim'),
              onTap: () => context.push('/barber/location'),
            ),
            _SettingsTile(
              icon: Icons.share,
              iconColor: AppColors.primary,
              label: tr(ref, 'barberApp.publicLink', 'Ommaviy havola'),
              onTap: () => context.push('/barber/public-link'),
            ),
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
              iconColor: AppColors.textMuted,
              label: tr(ref, 'profile.privacy', 'Maxfiylik siyosati'),
              onTap: () => _openUrl('https://lopestyle.uz/privacy'),
            ),
          ]),
          AppSpacing.gapXl,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.logout,
              iconColor: AppColors.textMuted,
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
        backgroundColor: AppColors.surface,
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

class _AvailabilityTile extends ConsumerStatefulWidget {
  const _AvailabilityTile({required this.userId});
  final String userId;
  @override
  ConsumerState<_AvailabilityTile> createState() =>
      _AvailabilityTileState();
}

class _AvailabilityTileState extends ConsumerState<_AvailabilityTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.userId));
    return async.when(
      loading: () => const SkeletonRect(height: 72, radius: AppRadius.lg),
      error: (_, _) => const SizedBox.shrink(),
      data: (b) {
        final on = b['isAvailable'] != false;
        return AppCard(
          variant: AppCardVariant.outlined,
          padding: AppSpacing.cardPadding,
          color: on
              ? AppColors.success.withValues(alpha: 0.06)
              : AppColors.surfaceElevated.withValues(alpha: 0.5),
          borderColor: on
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: on
                    ? const LinearGradient(colors: [
                        Color(0xFF10B981),
                        Color(0xFF059669),
                      ])
                    : null,
                color: on ? null : AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(
                on
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: on ? Colors.white : AppColors.textMuted,
                size: 22,
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    on
                        ? tr(ref, 'barbers.available', "Bo'sh")
                        : tr(ref, 'barbers.unavailable', 'Band'),
                    style: AppText.titleSm.copyWith(
                      color: on ? AppColors.success : AppColors.textBright,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    on
                        ? tr(ref, 'mobile.barber.profileEdit.availableHint',
                            'Yangi bronlar tushishi mumkin')
                        : tr(ref, 'mobile.barber.profileEdit.unavailableHint',
                            "Bron qabul qilmayapsiz — profil yashirin"),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            AppSpacing.hGapSm,
            Switch(
              value: on,
              activeThumbColor: AppColors.success,
              onChanged: _busy
                  ? null
                  : (_) async {
                      AppHaptics.medium();
                      setState(() => _busy = true);
                      try {
                        await ref
                            .read(barberPanelRepositoryProvider)
                            .toggleAvailability(widget.userId);
                        ref.invalidate(
                            barberProfileProvider(widget.userId));
                      } catch (e) {
                        if (!context.mounted) return;
                        AppHaptics.error();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          ]),
        );
      },
    );
  }
}

// Shared local widgets

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
              const Divider(
                color: AppColors.border,
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
                    : AppColors.textBright,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: destructive
                ? AppColors.danger.withValues(alpha: 0.7)
                : AppColors.textMuted,
            size: 18,
          ),
        ]),
      ),
    );
  }
}
