import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'barberApp.settings', "Sozlamalar"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ShadSectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
                icon: Icons.person_outline,
                label: tr(ref, 'profile.editProfile', "Profilni tahrirlash"),
                onTap: () => context.push('/profile-edit')),
          ]),

          const SizedBox(height: 18),
          ShadSectionLabel(tr(ref, 'mobile.shop.settings.salon', 'SALON')),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
                icon: Icons.storefront_outlined,
                label: tr(ref, 'profile.barberProfile', "Salon profili"),
                onTap: () => context.push('/shop/profile')),
            ShadTile(
                icon: Icons.admin_panel_settings_outlined,
                label: tr(ref, 'shop.nav.admins', "Adminlar"),
                onTap: () => context.push('/shop/admins')),
            ShadTile(
                icon: Icons.alarm,
                label: tr(ref, 'barberApp.reminderSettings', "Eslatmalar"),
                onTap: () => context.push('/shop/reminders')),
          ]),

          const SizedBox(height: 18),
          ShadSectionLabel(
              tr(ref, 'profile.section.help', 'Yordam').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
                icon: Icons.support_agent_outlined,
                label: tr(ref, 'barberApp.support', "Qo'llab-quvvatlash"),
                onTap: () => _openUrl('https://t.me/lopestyle_support')),
            ShadTile(
                icon: Icons.policy_outlined,
                label: tr(ref, 'profile.privacy', "Maxfiylik siyosati"),
                onTap: () => _openUrl('https://lopestyle.uz/privacy')),
          ]),

          const SizedBox(height: 18),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.logout,
              label: tr(ref, 'barberApp.logout', "Chiqish"),
              destructive: true,
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
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
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
