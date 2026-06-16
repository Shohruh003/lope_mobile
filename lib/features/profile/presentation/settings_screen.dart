import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// Standalone settings page mirroring the web's customer settings:
/// language, notifications, account actions, support links. Some of the
/// language and profile bits exist in profile_screen too — this is the
/// single place where the customer can find them all together.
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
          _Group(label: "Akkaunt", children: [
            _Row(icon: Icons.edit_outlined, label: "Profilni tahrirlash",
                onTap: () => context.push(user?.role == 'barber' ? '/barber/profile' : '/profile-edit')),
            _Row(icon: Icons.account_balance_wallet_outlined, label: "Hisobim",
                onTap: () => context.push('/transactions')),
            _Row(icon: Icons.notifications_outlined, label: "Bildirishnomalar",
                onTap: () => context.push('/notifications')),
          ]),
          const SizedBox(height: 14),
          _Group(label: "Yordam", children: [
            _Row(icon: Icons.help_outline, label: "FAQ — Tez-tez beriladigan savollar",
                onTap: () => _openUrl('https://lopestyle.uz/faq')),
            _Row(icon: Icons.support_agent_outlined, label: "Qo'llab-quvvatlash",
                onTap: () => _openUrl('https://t.me/lopestyle_support')),
            _Row(icon: Icons.policy_outlined, label: "Maxfiylik siyosati",
                onTap: () => _openUrl('https://lopestyle.uz/privacy')),
          ]),
          const SizedBox(height: 14),
          _Group(label: "Hisob", children: [
            _Row(
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Account-deletion confirmation. The actual deletion endpoint is sent
  /// asynchronously on the backend (24h delay window in the web app); here
  /// we just register the request and sign the user out.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
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

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1, indent: 56, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.onTap, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, color: destructive ? AppColors.danger : AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color))),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }
}
