import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
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
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
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

            // ═════════════ Menu links ═════════════
            // Since we dropped the hamburger drawer, every non-tab
            // destination lives here — this is the customer's single
            // "everything else" surface (Uzum/Click pattern).
            if (user != null) ...[
              _MenuGroup(children: [
                // Language row — compact tile with current flag; tap
                // opens a bottom sheet with the four options.
                _LangTile(currentLang: currentLang),
                // Theme mode picker — cycles between System / Light /
                // Dark. Preference persisted through themeModeProvider.
                const AppThemeTile(),
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
                // Sozlamalar / "Profil" link removed — it just re-opened
                // the same profile screen and confused users.
              ]),
              AppSpacing.gapLg,
            ],

            // ═════════════ Help / Yordam ═════════════
            _MenuGroup(children: [
              _LinkTile(
                icon: Icons.support_agent_outlined,
                iconColor: AppColors.success,
                label: tr(ref, 'barberApp.support', "Qo'llab-quvvatlash"),
                onTap: () => _openUrl('https://t.me/lopestyle_support'),
              ),
              _LinkTile(
                icon: Icons.help_outline,
                iconColor: AppColors.primary,
                label: tr(ref, 'profile.faq',
                    'FAQ — Tez-tez beriladigan savollar'),
                onTap: () => _openUrl('https://lopestyle.uz/faq'),
              ),
              _LinkTile(
                icon: Icons.policy_outlined,
                iconColor: context.colors.textMuted,
                label: tr(ref, 'profile.privacy', 'Maxfiylik siyosati'),
                onTap: () => _openUrl('https://lopestyle.uz/privacy'),
              ),
            ]),

            AppSpacing.gapLg,

            // ═════════════ Danger zone: Logout + Delete ═════════════
            if (user != null) ...[
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
              AppSpacing.gapSm,
              TextButton(
                onPressed: () => _confirmDelete(context, ref),
                child: Text(
                  tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish"),
                  style: AppText.bodySm.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

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

/// Deletion path — matches the old /settings screen: prompt, then POST
/// /users/delete-request and log the user out.
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
          content:
              Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
    return;
  }
  await ref.read(authControllerProvider.notifier).logout();
  if (context.mounted) context.go('/login');
}

Future<bool?> _logoutDialog(BuildContext context, WidgetRef ref) {
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

// ═════════════════════════ Profile hero ═════════════════════════

class _ProfileHero extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                            tr(ref, 'mobile.lopepay.home.balance', 'Balans'),
                            style: AppText.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            "${_fmt(amount)} ${tr(ref, 'common.currency', "so'm")}",
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
                            tr(ref, 'topUp.short', "To'ldirish"),
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

// ═════════════════════════ Language tile ═════════════════════════

const _langOptions = [
  ('uz', "O'zbek", 'рџ‡єрџ‡ї'),
  ('uz_cyr', 'РЋР·Р±РµРє', 'рџ‡єрџ‡ї'),
  ('ru', 'Р СѓСЃСЃРєРёР№', 'рџ‡·рџ‡є'),
  ('en', 'English', 'рџ‡єрџ‡ё'),
];

String _localeLabel(String code) {
  for (final opt in _langOptions) {
    if (opt.$1 == code) return opt.$2;
  }
  return code;
}

String _localeFlag(String code) {
  for (final opt in _langOptions) {
    if (opt.$1 == code) return opt.$3;
  }
  return 'рџЊђ';
}

/// Compact language row that slots into the profile menu. Shows the
/// current flag + label on the right; tap opens a bottom sheet with
/// all four options.
class _LangTile extends ConsumerWidget {
  const _LangTile({required this.currentLang});
  final String currentLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TapScale(
      onTap: () => _pickLanguage(context, ref, currentLang),
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
          Text(_localeFlag(currentLang),
              style: const TextStyle(fontSize: 18)),
          AppSpacing.hGapXs,
          Text(
            _localeLabel(currentLang),
            style: AppText.bodySm.copyWith(color: context.colors.textMuted),
          ),
          AppSpacing.hGapSm,
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
      ),
    );
  }

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
              for (final opt in _langOptions)
                TapScale(
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(sheetCtx).pop(opt.$1);
                  },
                  scale: 0.98,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              color: context.colors.textBright,
            )),
          ),
          Icon(Icons.chevron_right,
              color: context.colors.textMuted, size: 18),
        ]),
      ),
    );
  }
}
