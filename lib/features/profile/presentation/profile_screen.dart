import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
            ProfileHeroCard(
              user: user,
              balance: balance,
              onEdit: () => context.push(
                  isBarberRole(user?.role) ? '/barber/profile' : '/profile-edit'),
              onTopUp: () => context.push('/transactions'),
            ).animate().fadeIn(duration: 300.ms).slideY(
                begin: -0.05, end: 0, duration: 300.ms, curve: AppMotion.emphasized),

            AppSpacing.gapLg,

            // ═════════════ Menu links ═════════════
            // Ordered by how often a customer actually reaches for the
            // row: everyday actions on top, one-shot preferences at
            // the bottom. 'Profilni tahrirlash' isn't listed because
            // the edit icon on the hero card already goes there.
            if (user != null) ...[
              // ── Everyday actions ──
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
                  icon: Icons.receipt_long,
                  iconColor: AppColors.primary,
                  label: tr(ref, 'myTransactions.title',
                      'Tranzaksiyalar tarixi'),
                  onTap: () => context.push('/transactions'),
                ),
                _LinkTile(
                  icon: Icons.card_giftcard,
                  iconColor: AppColors.warning,
                  label: tr(ref, 'promoCode.title', 'Promo kod'),
                  onTap: () => context.push('/promo'),
                ),
                _LinkTile(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primary,
                  label: tr(
                      ref, 'barberApp.notifications', 'Bildirishnomalar'),
                  onTap: () => context.push('/notifications'),
                ),
              ]),
              AppSpacing.gapLg,
              // ── Preferences (set-once) ──
              _MenuGroup(children: [
                _LangTile(currentLang: currentLang),
                const AppThemeTile(),
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
            const Center(child: AppVersionLabel()),
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

// ═════════════════════════ Language tile ═════════════════════════

const _langOptions = [
  ('uz', "O'zbek", '🇺🇿'),
  ('uz_cyr', 'Ўзбек', '🇺🇿'),
  ('ru', 'Русский', '🇷🇺'),
  ('en', 'English', '🇺🇸'),
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
  return '🌐';
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
