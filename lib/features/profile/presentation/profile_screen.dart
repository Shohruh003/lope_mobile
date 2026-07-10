import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/l10n.dart';
import '../../../core/roles.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';

/// Ideal-quality profile screen. Uzum/Click darajasi bilan:
///   - Hero profile card: gradient wallet-style block (primary gradient
///     background, avatar with white ring, balance shown big)
///   - Language card with 4-flag grid
///   - Menu links as AppCard tiles with icon + chevron
///   - Logout as AppButton.danger secondary
///
/// State/API preserved: authControllerProvider, myBalanceProvider,
/// localeProvider, /profile-edit / /barber/profile routing.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final localeAsync = ref.watch(localeProvider);
    final currentLang = localeAsync.maybeWhen(
        data: (l) => l.locale, orElse: () => 'uz');
    final balance =
        user == null ? null : ref.watch(myBalanceProvider(user.id));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // ═════════════ Profile hero card ═════════════
            _ProfileHero(
              user: user,
              balance: balance,
              onEdit: () => context.push(
                  isBarberRole(user?.role) ? '/barber/profile' : '/profile-edit'),
              onTopUp: () => context.push('/transactions'),
            ).animate().fadeIn(duration: 300.ms).slideY(
                begin: -0.05, end: 0, duration: 300.ms, curve: AppMotion.emphasized),

            AppSpacing.gapLg,

            // ═════════════ Language card ═════════════
            AppCard(
              variant: AppCardVariant.outlined,
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.language,
                          color: AppColors.primary, size: 18),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        tr(ref, 'barberApp.language', 'Til'),
                        style: AppText.titleSm,
                      ),
                    ),
                  ]),
                  AppSpacing.gapMd,
                  Row(children: [
                    Expanded(
                      child: _LangBtn(
                          code: 'uz',
                          label: "O'zbek",
                          flag: '🇺🇿',
                          on: currentLang == 'uz',
                          ref: ref),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: _LangBtn(
                          code: 'uz_cyr',
                          label: 'Ўзбек',
                          flag: '🇺🇿',
                          on: currentLang == 'uz_cyr',
                          ref: ref),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: _LangBtn(
                          code: 'ru',
                          label: 'Русский',
                          flag: '🇷🇺',
                          on: currentLang == 'ru',
                          ref: ref),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: _LangBtn(
                          code: 'en',
                          label: 'English',
                          flag: '🇺🇸',
                          on: currentLang == 'en',
                          ref: ref),
                    ),
                  ]),
                ],
              ),
            ),

            AppSpacing.gapLg,

            // ═════════════ Menu links ═════════════
            // Since we dropped the hamburger drawer, every non-tab
            // destination lives here — this is the customer's single
            // "everything else" surface (Uzum/Click pattern).
            if (user != null) ...[
              _MenuGroup(children: [
                if (user.role == 'user') ...[
                  _LinkTile(
                    icon: Icons.bookmark_border,
                    iconColor: AppColors.primary,
                    label: tr(ref, 'profile.favorites', 'Masterim'),
                    onTap: () => context.push('/favorites'),
                  ),
                  _LinkTile(
                    icon: Icons.location_on_outlined,
                    iconColor: AppColors.success,
                    label:
                        tr(ref, 'mobile.map.title', 'Yaqin atrofda'),
                    onTap: () => context.push('/map'),
                  ),
                ],
                _LinkTile(
                  icon: Icons.person_outline,
                  iconColor: AppColors.primary,
                  label: tr(
                      ref, 'profile.editProfile', 'Profilni tahrirlash'),
                  onTap: () => context.push(isBarberRole(user.role)
                      ? '/barber/profile'
                      : '/profile-edit'),
                ),
                _LinkTile(
                  icon: Icons.card_giftcard,
                  iconColor: AppColors.warning,
                  label: tr(ref, 'promoCode.title', 'Promo kod'),
                  onTap: () => context.push('/promo'),
                ),
                _LinkTile(
                  icon: Icons.receipt_long,
                  iconColor: AppColors.primary,
                  label: tr(ref, 'myTransactions.title',
                      'Tranzaksiyalar tarixi'),
                  onTap: () => context.push('/transactions'),
                ),
                _LinkTile(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primary,
                  label: tr(
                      ref, 'barberApp.notifications', 'Bildirishnomalar'),
                  onTap: () => context.push('/notifications'),
                ),
                _LinkTile(
                  icon: Icons.settings_outlined,
                  iconColor: AppColors.textMuted,
                  label: tr(ref, 'barberApp.settings', 'Sozlamalar'),
                  onTap: () => context.push('/settings'),
                ),
              ]),
              AppSpacing.gapLg,
            ],

            // ═════════════ Support ═════════════
            _MenuGroup(children: [
              _LinkTile(
                icon: Icons.support_agent_outlined,
                iconColor: AppColors.success,
                label: tr(ref, 'barberApp.support', "Qo'llab-quvvatlash"),
                onTap: () async {
                  AppHaptics.light();
                  final uri = Uri.parse('https://t.me/lopestyle_support');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ]),

            AppSpacing.gapLg,

            // ═════════════ Logout ═════════════
            if (user != null)
              AppButton(
                label: tr(ref, 'barberApp.logout', 'Chiqish'),
                leadingIcon: Icons.logout,
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                onPressed: () async {
                  AppHaptics.light();
                  final yes = await _logoutDialog(context, ref);
                  if (yes == true) {
                    await ref
                        .read(authControllerProvider.notifier)
                        .logout();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),

            AppSpacing.gapMd,
            Center(
              child: Text(
                tr(ref, 'profile.versionLabel', 'Versiya 1.0.0'),
                style: AppText.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _logoutDialog(BuildContext context, WidgetRef ref) {
  return showDialog<bool>(
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

// ═════════════════════════ Profile hero ═════════════════════════

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.balance,
    required this.onEdit,
    required this.onTopUp,
  });
  final dynamic user; // avoiding import; only .avatar / .name / .phone used
  final AsyncValue<dynamic>? balance;
  final VoidCallback onEdit;
  final VoidCallback onTopUp;

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with white ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: (user?.avatar?.isNotEmpty == true)
                      ? CachedNetworkImage(
                          imageUrl: assetUrl(user!.avatar),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const SkeletonCircle(size: 64),
                          errorWidget: (_, _, _) =>
                              _Fallback(name: user?.name ?? '?'),
                        )
                      : _Fallback(name: user?.name ?? '?'),
                ),
              ),
              AppSpacing.hGapMd,
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '—',
                      style: AppText.titleLg.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.phone ?? '',
                      style: AppText.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit
              TapScale(
                onTap: onEdit,
                scale: 0.9,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.edit, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          if (balance != null) ...[
            AppSpacing.gapLg,
            balance!.when(
              loading: () => const SkeletonLine(width: 180, height: 32),
              error: (e, _) => const SizedBox.shrink(),
              data: (b) {
                final amount = (b.amount as int?) ?? 0;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.account_balance_wallet,
                          color: Colors.white, size: 20),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balans',
                            style: AppText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "${_fmt(amount)} so'm",
                            style: AppText.numeric.copyWith(
                              color: Colors.white,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: onTopUp,
                      scale: 0.94,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Row(children: [
                          const Icon(Icons.add,
                              color: AppColors.primary, size: 16),
                          AppSpacing.hGapXs,
                          Text(
                            "To'ldirish",
                            style: AppText.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.15),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.titleLg.copyWith(
          color: Colors.white,
          fontSize: 28,
        ),
      ),
    );
  }
}

// ═════════════════════════ Language button ═════════════════════════

class _LangBtn extends StatelessWidget {
  const _LangBtn({
    required this.code,
    required this.label,
    required this.flag,
    required this.on,
    required this.ref,
  });
  final String code;
  final String label;
  final String flag;
  final bool on;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () async {
        AppHaptics.selection();
        await ref.read(localeProvider.notifier).setLocale(code);
      },
      scale: 0.95,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: on
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: on ? AppColors.primary : AppColors.border,
            width: on ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Text(flag, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.caption.copyWith(
              fontSize: 11,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════ Menu tiles ═════════════════════════

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
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

class _LinkTile extends StatelessWidget {
  const _LinkTile({
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
            child: Text(label, style: AppText.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textBright,
            )),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}
