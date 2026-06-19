import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n.dart';
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
            ShadTile(
              icon: Icons.card_giftcard_outlined,
              label: "Promo kod",
              onTap: () => context.push('/promo'),
            ),
          ]),

          const SizedBox(height: 18),
          const ShadSectionLabel("ILOVA"),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
              icon: Icons.language_outlined,
              label: "Til",
              trailing: Text(_localeLabel(currentLocale),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              onTap: () => _pickLanguage(context, ref, currentLocale),
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
              icon: Icons.logout_outlined,
              label: "Chiqish",
              onTap: () => _confirmLogout(context, ref),
            ),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Tilni tanlang",
                    style: TextStyle(
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
        title: const Text("Chiqish?"),
        content: const Text("Tizimdan chiqib, login sahifasiga qaytasiz."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: const Text("Bekor")),
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text("Chiqish"),
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
