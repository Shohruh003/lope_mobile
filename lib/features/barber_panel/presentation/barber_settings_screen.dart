import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';
import '../data/barber_profile_repository.dart';

class BarberSettingsScreen extends ConsumerWidget {
  const BarberSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'barberApp.settings', "Sozlamalar"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ===== Availability toggle — mirrors web BarberSettingsDrawer =====
          if (user != null) ...[
            _AvailabilityTile(userId: user.id),
            const SizedBox(height: 18),
          ],

          ShadSectionLabel(
              tr(ref, 'profile.section.account', 'Akkaunt').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
                icon: Icons.edit_outlined,
                label: tr(ref, 'profile.editProfile', "Profilni tahrirlash"),
                onTap: () => context.push('/barber/profile')),
            ShadTile(
                icon: Icons.lock_outline,
                label: tr(ref, 'barberApp.accountSettings', "Akkaunt sozlamalari"),
                onTap: () => context.push('/barber/account-edit')),
            ShadTile(
                icon: Icons.notifications_active_outlined,
                label: tr(ref, 'barberApp.reminderSettings', "Eslatma sozlamalari"),
                onTap: () => context.push('/barber/reminders')),
          ]),

          const SizedBox(height: 18),
          ShadSectionLabel(
              tr(ref, 'barberApp.management', 'Boshqaruv').toUpperCase()),
          const SizedBox(height: 8),
          ShadTileGroup(children: [
            ShadTile(
                icon: Icons.people_outline,
                label: tr(ref, 'barberMyClients.title', "Mijozlarim"),
                onTap: () => context.push('/barber/my-clients')),
            ShadTile(
                icon: Icons.credit_card_outlined,
                label: tr(ref, 'barberApp.cards', "To'lov kartalarim"),
                onTap: () => context.push('/barber/cards')),
            ShadTile(
                icon: Icons.local_offer_outlined,
                label: tr(ref, 'promoCode.title', "Promo kodlar"),
                onTap: () => context.push('/barber/promo-code')),
            ShadTile(
                icon: Icons.location_on_outlined,
                label: tr(ref, 'barberApp.myLocation', "Manzilim"),
                onTap: () => context.push('/barber/location')),
            ShadTile(
                icon: Icons.share,
                label: tr(ref, 'barberApp.publicLink', "Ommaviy havola"),
                onTap: () => context.push('/barber/public-link')),
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

/// Quick toggle for "I'm accepting bookings". Mirrors the prominent
/// availability switch in web's BarberSettingsDrawer — keeps the barber from
/// having to dive into the Profile editor just to flip this one flag.
class _AvailabilityTile extends ConsumerStatefulWidget {
  const _AvailabilityTile({required this.userId});
  final String userId;
  @override
  ConsumerState<_AvailabilityTile> createState() => _AvailabilityTileState();
}

class _AvailabilityTileState extends ConsumerState<_AvailabilityTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (b) {
        final on = b['isAvailable'] != false;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SwitchListTile(
            value: on,
            activeThumbColor: AppColors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            secondary: Icon(
                on ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.primary),
            title: Text(
                on
                    ? tr(ref, 'barbers.available', "Bo'sh")
                    : tr(ref, 'barbers.unavailable', 'Band'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textBright)),
            subtitle: Text(
                on
                    ? tr(ref, 'mobile.barber.profileEdit.availableHint',
                        "Yangi bronlar tushishi mumkin")
                    : tr(ref, 'mobile.barber.profileEdit.unavailableHint',
                        "Bron qabul qilmayapsiz — profil yashirin"),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
            onChanged: _busy
                ? null
                : (_) async {
                    setState(() => _busy = true);
                    try {
                      await ref
                          .read(barberPanelRepositoryProvider)
                          .toggleAvailability(widget.userId);
                      ref.invalidate(barberProfileProvider(widget.userId));
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        );
      },
    );
  }
}
