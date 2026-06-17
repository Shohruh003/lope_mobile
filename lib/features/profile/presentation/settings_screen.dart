import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text("Sozlamalar")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ShadSectionLabel("AKKAUNT"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.edit_outlined,
              label: "Profilni tahrirlash",
              onTap: () => context.push(user?.role == 'barber' ? '/barber/profile' : '/profile-edit'),
            ),
            ShadTile(
              icon: Icons.account_balance_wallet_outlined,
              label: "Hisobim",
              onTap: () => context.push('/transactions'),
            ),
            ShadTile(
              icon: Icons.notifications_outlined,
              label: "Bildirishnomalar",
              onTap: () => context.push('/notifications'),
            ),
          ]),

          const SizedBox(height: 18),
          const ShadSectionLabel("YORDAM"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.help_outline,
              label: "FAQ — Tez-tez beriladigan savollar",
              onTap: () => _openUrl('https://lopestyle.uz/faq'),
            ),
            ShadTile(
              icon: Icons.support_agent_outlined,
              label: "Qo'llab-quvvatlash",
              onTap: () => _openUrl('https://t.me/lopestyle_support'),
            ),
            ShadTile(
              icon: Icons.policy_outlined,
              label: "Maxfiylik siyosati",
              onTap: () => _openUrl('https://lopestyle.uz/privacy'),
            ),
          ]),

          const SizedBox(height: 18),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.delete_outline,
              label: "Hisobni o'chirish",
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
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text("Hisobni o'chirish?"),
        content: const Text(
            "Hisobingiz va barcha ma'lumotlaringiz o'chiriladi. Bu jarayonni bekor qilib bo'lmaydi."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text("Bekor")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}
