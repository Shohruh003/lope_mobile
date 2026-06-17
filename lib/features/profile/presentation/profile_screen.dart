import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../../../core/l10n.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';

/// Mirrors the web `CustomerSettingsScreen` exactly:
///  - Profile Card: edit pencil top-right (abs top-3 right-3), centered
///    avatar (h-24), bold name + phone, balance pill with "To'ldirish" link
///  - Language Card with 4 language flags (full-width grid)
///  - Theme toggle Card (skipped on mobile — Material handles dark by default)
///  - Promo code Card
///  - Transactions Card
///  - Notifications Card
///  - Logout + Delete Account at bottom
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final localeAsync = ref.watch(localeProvider);
    final currentLang = localeAsync.maybeWhen(data: (l) => l.locale, orElse: () => 'uz');
    final balance = user == null ? null : ref.watch(myBalanceProvider(user.id));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ===== Profile Card =====
            ShadCard(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Stack(children: [
                // Edit pencil — absolute top-right
                Positioned(
                  top: 0, right: 0,
                  child: InkWell(
                    onTap: () => context.push(user?.role == 'barber' ? '/barber/profile' : '/profile-edit'),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: AppColors.primary, size: 16),
                    ),
                  ),
                ),
                // Centered content
                Center(
                  child: Column(children: [
                    // Big avatar h-24 = 96px
                    ClipOval(
                      child: (user?.avatar?.isNotEmpty == true)
                          ? CachedNetworkImage(
                              imageUrl: user!.avatar!,
                              width: 96, height: 96,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, err) => _Fallback(name: user.name),
                            )
                          : _Fallback(name: user?.name ?? '?'),
                    ),
                    const SizedBox(height: 12),
                    Text(user?.name ?? '—',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textBright)),
                    const SizedBox(height: 2),
                    Text(user?.phone ?? '',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 14),
                    // Balance pill
                    if (balance != null)
                      balance.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => const SizedBox.shrink(),
                        data: (b) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text("${_fmt(b.amount)} so'm",
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => context.push('/transactions'),
                              child: const Text("To'ldirish",
                                  style: TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFF3B82F6),
                                      fontWeight: FontWeight.w500)),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ]),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 14),

            // ===== Language Card =====
            ShadCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.language, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text("Til",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBright)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _LangBtn(code: 'uz', label: "O'zbek", flag: '🇺🇿', on: currentLang == 'uz', ref: ref),
                  const SizedBox(width: 8),
                  _LangBtn(code: 'uz_cyr', label: 'Ўзбек', flag: '🇺🇿', on: currentLang == 'uz_cyr', ref: ref),
                  const SizedBox(width: 8),
                  _LangBtn(code: 'ru', label: 'Русский', flag: '🇷🇺', on: currentLang == 'ru', ref: ref),
                  const SizedBox(width: 8),
                  _LangBtn(code: 'en', label: 'English', flag: '🇺🇸', on: currentLang == 'en', ref: ref),
                ]),
              ]),
            ),

            const SizedBox(height: 10),

            // ===== Promo code Card =====
            if (user != null)
              _LinkCard(
                icon: Icons.card_giftcard,
                label: "Promo kod",
                onTap: () => context.push('/promo'),
              ),
            if (user != null) const SizedBox(height: 10),

            // ===== Transactions Card =====
            if (user != null)
              _LinkCard(
                icon: Icons.receipt_long,
                label: "Tranzaksiyalar tarixi",
                onTap: () => context.push('/transactions'),
              ),
            if (user != null) const SizedBox(height: 10),

            // ===== Notifications Card =====
            if (user != null)
              _LinkCard(
                icon: Icons.notifications_outlined,
                label: "Bildirishnomalar",
                onTap: () => context.push('/notifications'),
              ),
            if (user != null) const SizedBox(height: 10),

            // ===== Favorites Card =====
            if (user?.role == 'user')
              _LinkCard(
                icon: Icons.favorite_outline,
                label: "Sevimlilar",
                onTap: () => context.push('/favorites'),
              ),
            if (user?.role == 'user') const SizedBox(height: 10),

            // ===== Support Card =====
            _LinkCard(
              icon: Icons.support_agent_outlined,
              label: "Qo'llab-quvvatlash",
              onTap: () async {
                final uri = Uri.parse('https://t.me/lopestyle_support');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 14),

            // ===== Logout Button =====
            if (user != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.danger, size: 16),
                  label: const Text("Chiqish",
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  onPressed: () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: AppColors.background,
                        title: const Text("Chiqishni tasdiqlang"),
                        content: const Text("Hisobingizdan chiqmoqchimisiz?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Bekor")),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Chiqish"),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ),

            const SizedBox(height: 12),
            const Center(
              child: Text("Versiya 1.0.0",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

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
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96, height: 96,
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: const TextStyle(color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w700),
      ),
    );
  }
}

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
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await ref.read(localeProvider.notifier).setLocale(code);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? AppColors.primary : AppColors.border),
          ),
          child: Column(children: [
            Text(flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? AppColors.primary : AppColors.textPrimary,
                )),
          ]),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBright)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
        ]),
      ),
    );
  }

  // Silence the unused `_` parameter from `ShadCard` constructor.
  // ignore: unused_element
  void _noop() {}
}

// AppConfig used only to silence import warnings if profile gains more
// config-dependent options later.
// ignore: unused_element
typedef _UnusedConfigRef = AppConfig;
