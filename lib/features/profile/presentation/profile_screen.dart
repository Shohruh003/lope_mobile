import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile tab — shadcn-style: user card + grouped settings tiles. No more
/// massive gradient header.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final localeAsync = ref.watch(localeProvider);
    final currentLocale = localeAsync.maybeWhen(data: (l) => l.locale, orElse: () => 'uz');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              tr(ref, 'mobile.profile.title', "Profil"),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textBright,
              ),
            ),
            const SizedBox(height: 14),

            // User card
            ShadCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '—',
                          style: const TextStyle(
                              color: AppColors.textBright,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(user?.phone ?? '',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                if (user?.role != null && user!.role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_roleLabel(user.role),
                        style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
              ]),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 18),
            _SectionLabel("AKKAUNT"),
            const SizedBox(height: 8),
            _TileGroup(children: [
              _Tile(
                icon: Icons.edit_outlined,
                label: tr(ref, 'mobile.profile.edit', "Profilni tahrirlash"),
                onTap: () => context.push(user?.role == 'barber' ? '/barber/profile' : '/profile-edit'),
              ),
              _Tile(
                icon: Icons.account_balance_wallet_outlined,
                label: tr(ref, 'mobile.profile.transactions', "Hisobim va to'lovlar"),
                onTap: () => context.push('/transactions'),
              ),
              _Tile(
                icon: Icons.notifications_outlined,
                label: tr(ref, 'mobile.profile.notifications', "Bildirishnomalar"),
                onTap: () => context.push('/notifications'),
              ),
              if (user?.role == 'user')
                _Tile(
                  icon: Icons.favorite_outline,
                  label: tr(ref, 'mobile.profile.favorites', "Sevimlilar"),
                  onTap: () => context.push('/favorites'),
                ),
            ]),

            const SizedBox(height: 18),
            _SectionLabel("SOZLAMALAR"),
            const SizedBox(height: 8),
            _TileGroup(children: [
              _Tile(
                icon: Icons.language_outlined,
                label: tr(ref, 'mobile.auth.language', "Til"),
                trailing: Text(_langLabel(currentLocale),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                onTap: () => _showLanguageSheet(context, ref, currentLocale),
              ),
              _Tile(
                icon: Icons.info_outline,
                label: tr(ref, 'mobile.auth.version', "Versiya"),
                trailing: const Text("1.0.0",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ]),

            const SizedBox(height: 18),
            _TileGroup(children: [
              _Tile(
                icon: Icons.logout,
                label: tr(ref, 'mobile.auth.logout', "Chiqish"),
                destructive: true,
                onTap: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.background,
                      title: Text(tr(ref, 'mobile.auth.logoutTitle', "Chiqishni tasdiqlang")),
                      content: Text(tr(ref, 'mobile.auth.logoutAsk', "Hisobingizdan chiqmoqchimisiz?")),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr(ref, 'mobile.auth.logoutCancel', "Bekor"))),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(tr(ref, 'mobile.auth.logout', "Chiqish")),
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
            ]),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'barber': return 'BARBER';
      case 'barbershop': return 'SALON';
      case 'shop': return 'LOPE PAY';
      case 'admin': return 'ADMIN';
      default: return 'MIJOZ';
    }
  }

  String _langLabel(String code) {
    switch (code) {
      case 'uz': return "O'zbek";
      case 'uz_cyr': return "Ўзбек";
      case 'ru': return 'Русский';
      case 'en': return 'English';
    }
    return code;
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(tr(ref, 'mobile.profile.selectLanguage', "Tilni tanlash"),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textBright)),
              ),
              ...AppConfig.supportedLanguages.map((code) {
                final on = code == current;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(localeProvider.notifier).setLocale(code);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Row(children: [
                      Expanded(
                        child: Text(_langLabel(code),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                color: on ? AppColors.primary : AppColors.textPrimary)),
                      ),
                      if (on) const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: non_constant_identifier_names
Widget _SectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1)),
    );

class _TileGroup extends StatelessWidget {
  const _TileGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i < children.length - 1) {
        out.add(const Divider(height: 1, indent: 48, color: AppColors.border));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: out),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, this.onTap, this.trailing, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Icon(icon, color: destructive ? AppColors.danger : AppColors.primary, size: 18),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: color))),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
          if (onTap != null && !destructive)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
            ),
        ]),
      ),
    );
  }
}
