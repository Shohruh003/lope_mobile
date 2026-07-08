import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/l10n.dart';
import '../../../core/roles.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final localeAsync = ref.watch(localeProvider);
    final currentLocale = localeAsync.asData?.value.locale ?? 'uz';
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'barberApp.settings', 'Sozlamalar'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ShadSectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.edit_outlined,
              label: tr(ref, 'profile.editProfile', "Profilni tahrirlash"),
              onTap: () => context.push(isBarberRole(user?.role) ? '/barber/profile' : '/profile-edit'),
            ),
            ShadTile(
              icon: Icons.account_balance_wallet_outlined,
              label: tr(ref, 'myTransactions.title', "Hisobim"),
              onTap: () => context.push('/transactions'),
            ),
            ShadTile(
              icon: Icons.notifications_outlined,
              label: tr(ref, 'barberApp.notifications', "Bildirishnomalar"),
              onTap: () => context.push('/notifications'),
            ),
            ShadTile(
              icon: Icons.card_giftcard_outlined,
              label: tr(ref, 'promoCode.title', "Promo kod"),
              onTap: () => context.push('/promo'),
            ),
          ]),

          const SizedBox(height: 18),
          ShadSectionLabel(
              tr(ref, 'profile.section.app', 'Ilova').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.language_outlined,
              label: tr(ref, 'barberApp.language', "Til"),
              trailing: Text(_localeLabel(currentLocale),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              onTap: () => _pickLanguage(context, ref, currentLocale),
            ),
          ]),

          const SizedBox(height: 18),
          ShadSectionLabel(
              tr(ref, 'profile.section.help', 'Yordam').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.help_outline,
              label: tr(ref, 'profile.faq', "FAQ — Tez-tez beriladigan savollar"),
              onTap: () => _openUrl('https://lopestyle.uz/faq'),
            ),
            ShadTile(
              icon: Icons.support_agent_outlined,
              label: tr(ref, 'barberApp.support', "Qo'llab-quvvatlash"),
              onTap: () => _openUrl('https://t.me/lopestyle_support'),
            ),
            ShadTile(
              icon: Icons.policy_outlined,
              label: tr(ref, 'profile.privacy', "Maxfiylik siyosati"),
              onTap: () => _openUrl('https://lopestyle.uz/privacy'),
            ),
          ]),

          const SizedBox(height: 18),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.logout_outlined,
              label: tr(ref, 'barberApp.logout', "Chiqish"),
              onTap: () => _confirmLogout(context, ref),
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

  String _localeLabel(String code) => switch (code) {
        'uz' => "O'zbekcha",
        'uz_cyr' => 'Ўзбекча',
        'ru' => 'Русский',
        'en' => 'English',
        _ => code,
      };

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr(ref, 'barberApp.language', 'Til'),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright)),
              ),
            ),
            const SizedBox(height: 6),
            for (final code in const ['uz', 'uz_cyr', 'ru', 'en'])
              ListTile(
                title: Text(_localeLabel(code),
                    style: const TextStyle(color: AppColors.textBright)),
                trailing: code == current
                    ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                    : null,
                onTap: () => Navigator.of(sheetCtx).pop(code),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    await ref.read(localeProvider.notifier).setLocale(picked);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('${tr(ref, 'barberApp.logout', 'Chiqish')}?'),
        content: Text(tr(ref, 'profile.logoutConfirm',
            "Tizimdan chiqib, login sahifasiga qaytasiz.")),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'barberApp.logout', "Chiqish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
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
