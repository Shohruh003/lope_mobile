import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

class BarberSettingsScreen extends ConsumerWidget {
  const BarberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sozlamalar")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ShadSectionLabel("AKKAUNT"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(icon: Icons.edit_outlined, label: "Profilni tahrirlash",
                onTap: () => context.push('/barber/profile')),
            ShadTile(icon: Icons.lock_outline, label: "Akkaunt sozlamalari",
                onTap: () => context.push('/barber/account-edit')),
            ShadTile(icon: Icons.notifications_active_outlined, label: "Eslatma sozlamalari",
                onTap: () => context.push('/barber/reminders')),
          ]),

          const SizedBox(height: 18),
          const ShadSectionLabel("BOSHQARUV"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(icon: Icons.people_outline, label: "Mijozlarim",
                onTap: () => context.push('/barber/my-clients')),
            ShadTile(icon: Icons.credit_card_outlined, label: "To'lov kartalarim",
                onTap: () => context.push('/barber/cards')),
            ShadTile(icon: Icons.local_offer_outlined, label: "Promo kodlar",
                onTap: () => context.push('/barber/promo-code')),
            ShadTile(icon: Icons.location_on_outlined, label: "Manzilim",
                onTap: () => context.push('/barber/location')),
            ShadTile(icon: Icons.share, label: "Ommaviy havola",
                onTap: () => context.push('/barber/public-link')),
          ]),

          const SizedBox(height: 18),
          const ShadSectionLabel("YORDAM"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(icon: Icons.support_agent_outlined, label: "Qo'llab-quvvatlash",
                onTap: () => _openUrl('https://t.me/lopestyle_support')),
            ShadTile(icon: Icons.policy_outlined, label: "Maxfiylik siyosati",
                onTap: () => _openUrl('https://lopestyle.uz/privacy')),
          ]),

          const SizedBox(height: 18),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.logout,
              label: "Chiqish",
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
