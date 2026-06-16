import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sozlamalar")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _Group(label: "Salon", children: [
            _Row(icon: Icons.storefront_outlined, label: "Salon profili",
                onTap: () => context.push('/shop/profile')),
            _Row(icon: Icons.admin_panel_settings_outlined, label: "Adminlar",
                onTap: () => context.push('/shop/admins')),
            _Row(icon: Icons.alarm, label: "Eslatmalar",
                onTap: () => context.push('/shop/reminders')),
          ]),
          const SizedBox(height: 14),
          _Group(label: "Yordam", children: [
            _Row(icon: Icons.support_agent_outlined, label: "Qo'llab-quvvatlash",
                onTap: () => _openUrl('https://t.me/lopestyle_support')),
            _Row(icon: Icons.policy_outlined, label: "Maxfiylik siyosati",
                onTap: () => _openUrl('https://lopestyle.uz/privacy')),
          ]),
          const SizedBox(height: 14),
          _Group(label: "Hisob", children: [
            _Row(
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
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(height: 1, indent: 56, color: AppColors.border),
            ],
          ]),
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
