import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// Profile tab: avatar + name + phone header, then a list of settings rows
/// (language, theme placeholder, app version, logout). Clean iOS-style cards.
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              tr(ref, 'mobile.profile.title', "Profil"),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 20),

            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? '—',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(user?.phone ?? '',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),

            // Quick links — match the web's sidebar navigation
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.edit_outlined,
                label: tr(ref, 'mobile.profile.edit', "Profilni tahrirlash"),
                onTap: () => context.push(user?.role == 'barber' ? '/barber/profile' : '/profile-edit'),
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                label: tr(ref, 'mobile.profile.transactions', "Hisobim va to'lovlar"),
                onTap: () => context.push('/transactions'),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: tr(ref, 'mobile.profile.notifications', "Bildirishnomalar"),
                onTap: () => context.push('/notifications'),
              ),
              if (user?.role == 'user')
                _SettingsTile(
                  icon: Icons.favorite_outline,
                  label: tr(ref, 'mobile.profile.favorites', "Sevimlilar"),
                  onTap: () => context.push('/favorites'),
                ),
            ]).animate().fadeIn(duration: 400.ms, delay: 120.ms),

            const SizedBox(height: 16),

            // Settings list
            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.language_outlined,
                label: tr(ref, 'mobile.auth.language', "Til"),
                trailing: Text(_langLabel(currentLocale),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                onTap: () => _showLanguageSheet(context, ref, currentLocale),
              ),
              _SettingsTile(
                icon: Icons.info_outline,
                label: tr(ref, 'mobile.auth.version', "Versiya"),
                trailing: const Text("1.0.0",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                onTap: null,
              ),
            ]).animate().fadeIn(duration: 400.ms, delay: 160.ms),

            const SizedBox(height: 16),

            _SettingsGroup(children: [
              _SettingsTile(
                icon: Icons.logout,
                label: tr(ref, 'mobile.auth.logout', "Chiqish"),
                isDestructive: true,
                onTap: () async {
                  final yes = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      title: Text(tr(ref, 'mobile.auth.logoutTitle', "Chiqishni tasdiqlang")),
                      content: Text(tr(ref, 'mobile.auth.logoutAsk', "Hisobingizdan chiqmoqchimisiz?")),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(tr(ref, 'mobile.auth.logoutCancel', "Bekor qilish"))),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            child: Text(tr(ref, 'mobile.auth.logout', "Chiqish"))),
                      ],
                    ),
                  );
                  if (yes == true) {
                    await ref.read(authControllerProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  }
                },
              ),
            ]).animate().fadeIn(duration: 400.ms, delay: 240.ms),
          ],
        ),
      ),
    );
  }

  String _langLabel(String code) {
    switch (code) {
      case 'uz':
        return "O'zbek";
      case 'uz_cyr':
        return "Ўзбек";
      case 'ru':
        return 'Русский';
      case 'en':
        return 'English';
    }
    return code;
  }

  void _showLanguageSheet(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(tr(ref, 'mobile.profile.selectLanguage', "Tilni tanlash"),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              ...AppConfig.supportedLanguages.map((code) {
                final on = code == current;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(localeProvider.notifier).setLocale(code);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(_langLabel(code),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                  color: on ? AppColors.primary : AppColors.textPrimary)),
                        ),
                        if (on) const Icon(Icons.check_circle, color: AppColors.primary),
                      ],
                    ),
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i < children.length - 1) {
        separated.add(const Divider(height: 1, indent: 56));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: separated),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (isDestructive ? AppColors.danger : AppColors.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            ),
            ?trailing,
            if (onTap != null && !isDestructive)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
