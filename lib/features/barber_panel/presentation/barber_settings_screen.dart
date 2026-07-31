import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';
import '../data/barber_profile_repository.dart';

class BarberSettingsScreen extends ConsumerWidget {
  const BarberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No AppBar — the barber shell already renders a fixed header
    // (Lope Style brand + share + bell) above the tab body, and the
    // bottom nav shows "Profil" for this tab. Repeating the word at
    // the top of the screen was a visual duplication the user asked
    // us to remove.
    final user = ref.watch(authControllerProvider).user;
    final balance =
        user == null ? null : ref.watch(myBalanceProvider(user.id));
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
        children: [
          // Hero profile card — same widget the customer profile uses,
          // avatar + name + phone on the primary gradient with a
          // balance pill below. Tap the edit icon to open the same
          // /barber/profile screen the old 'Profilni tahrirlash' tile
          // used to route to, so the tile is now redundant and dropped.
          ProfileHeroCard(
            user: user,
            balance: balance,
            onEdit: () => context.push('/barber/profile'),
            onTopUp: () => context.push('/transactions'),
          ),
          AppSpacing.gapLg,
          // Availability toggle lives on the Sartarosh profili screen
          // (barber_profile_edit_screen) so it sits next to the rest
          // of the barber's public profile controls. Duplicating it
          // here confused users into thinking the two switches did
          // different things.
          _SectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
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
              tr(ref, 'profile.section.finance', 'Moliya').toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
              label:
                  tr(ref, 'mobile.customer.transactions.title', 'Hisob'),
              onTap: () => context.push('/transactions'),
            ),
            _SettingsTile(
              icon: Icons.sms_outlined,
              iconColor: AppColors.warning,
              label: tr(ref, 'mobile.barber.sms.title', 'SMS tarixi'),
              onTap: () => context.push('/barber/sms'),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              iconColor: AppColors.primary,
              label: tr(
                  ref, 'barberApp.notifications', 'Bildirishnomalar'),
              onTap: () => context.push('/notifications'),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionLabel(tr(ref, 'profile.section.preferences', 'Sozlamalar')
              .toUpperCase()),
          AppSpacing.gapSm,
          _TileGroup(children: [
            const AppThemeTile(),
            const AppLanguageTile(),
            if (user != null) _BarberSmsLanguageSettingsTile(barberId: user.id),
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
          // Danger zone — same layout as customer profile so a barber
          // switching between roles sees a familiar Chiqish/O'chirish
          // block instead of two red list rows. Logout was also
          // firing without any confirmation before, which was easy to
          // trigger by accident on the way down the tile list.
          AppButton(
            label: tr(ref, 'barberApp.logout', 'Chiqish'),
            leadingIcon: Icons.logout,
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: () async {
              AppHaptics.light();
              final yes = await _confirmLogout(context, ref);
              if (yes == true) {
                await ref
                    .read(authControllerProvider.notifier)
                    .logout();
                if (context.mounted) context.go('/login');
              }
            },
          ),
          AppSpacing.gapSm,
          Center(
            child: TextButton(
              onPressed: () => _confirmDelete(context, ref),
              child: Text(
                tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish"),
                style: AppText.bodySm.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          AppSpacing.gapMd,
          const Center(child: AppVersionLabel()),
        ],
      ),
    );
  }

  /// Same shape as the customer's logout dialog — icon + title +
  /// message + Bekor/Chiqish. Barber logout used to fire immediately
  /// on tile-tap, which was an easy misclick.
  Future<bool?> _confirmLogout(BuildContext context, WidgetRef ref) {
    AppHaptics.light();
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
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout,
                      color: AppColors.danger, size: 22),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Text(
                    tr(ref, 'profile.logoutConfirmTitle',
                        'Chiqishni tasdiqlang'),
                    style: AppText.titleMd,
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'profile.logoutConfirmMsg',
                    'Hisobingizdan chiqmoqchimisiz?'),
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
                    label: tr(ref, 'barberApp.logout', 'Chiqish'),
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

/// Loads the barber's smsLanguage lazily so the tile knows the current
/// pick and whether to expose the "inherit from shop" option. Standalone
/// barbers don't see the inherit choice.
class _BarberSmsLanguageSettingsTile extends ConsumerStatefulWidget {
  const _BarberSmsLanguageSettingsTile({required this.barberId});
  final String barberId;
  @override
  ConsumerState<_BarberSmsLanguageSettingsTile> createState() =>
      _BarberSmsLanguageSettingsTileState();
}

class _BarberSmsLanguageSettingsTileState
    extends ConsumerState<_BarberSmsLanguageSettingsTile> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(barberProfileRepositoryProvider)
        .getBarber(widget.barberId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!;
        final current = data['smsLanguage']?.toString();
        final barbershopId = data['barbershopId']?.toString();
        return SmsLanguageTile(
          currentValue: current,
          showInherit: barbershopId != null && barbershopId.isNotEmpty,
          onSave: (v) async {
            await ref
                .read(barberProfileRepositoryProvider)
                .updateSmsLanguage(widget.barberId, v);
            if (mounted) {
              setState(() {
                _future = ref
                    .read(barberProfileRepositoryProvider)
                    .getBarber(widget.barberId);
              });
            }
          },
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

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
                color: context.colors.textBright,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: context.colors.textMuted,
            size: 18,
          ),
        ]),
      ),
    );
  }
}
