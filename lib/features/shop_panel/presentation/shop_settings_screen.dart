import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
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
            ShadTile(
              icon: Icons.delete_outline,
              label: tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish"),
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
        title: Text('${tr(ref, 'barberApp.deleteAccount', "Hisobni o'chirish")}?'),
        content: Text(tr(ref, 'barberApp.deleteAccountConfirm',
            "Hisobingiz va barcha ma'lumotlaringiz o'chiriladi. Bu jarayonni bekor qilib bo'lmaydi.")),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'common.delete', "O'chirish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/users/delete-request',
          data: <String, dynamic>{});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'barberApp.deleteAccountQueued',
                "O'chirish so'rovingiz qabul qilindi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
      return;
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }
}
