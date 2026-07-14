import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/asset_url.dart';
import '../../core/tr.dart';
import '../shared.dart';
import '../../features/auth/presentation/auth_controller.dart';

/// Side-menu drawer matching the web sidebar. The item set depends on the
/// current user's role — barber sees 12 items, shop 9, lopepay 5, customer 5.
/// One widget, role-switched body.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final role = user?.role ?? 'user';

    final items = _itemsForRole(role, ref);

    return Drawer(
      backgroundColor: context.colors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Header: avatar + name + phone
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarCircle(
                    avatar: user?.avatar,
                    name: user?.name,
                  ),
                  const SizedBox(height: 12),
                  Text(user?.name ?? '—',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(user?.phone ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _roleLabel(role, ref),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            // Menu
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in items)
                    if (item == null)
                      Divider(
                          height: 12, color: context.colors.border)
                    else
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          final route = item.route;
                          if (route == null) return;
                          // Routes that point to a panel shell (/barber-app,
                          // /shop, /lopepay) or the customer home (/home) must
                          // replace the stack — pushing them stacks a fresh
                          // shell on top of the live one and leaks the old
                          // state (each tap from the drawer kept another
                          // IndexedStack alive).
                          if (_isShellRoute(route)) {
                            context.go(route);
                          } else {
                            context.push(route);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          child: Row(children: [
                            Icon(item.icon, color: item.destructive ? AppColors.danger : AppColors.primary, size: 22),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(item.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: item.destructive
                                        ? AppColors.danger
                                        : context.colors.textPrimary,
                                  )),
                            ),
                            if (item.badge != null && item.badge!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(item.badge!,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                          ]),
                        ),
                      ),
                ],
              ),
            ),

            // Footer: logout
            Divider(height: 1, color: context.colors.border),
            InkWell(
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.logout, color: AppColors.danger, size: 22),
                  const SizedBox(width: 14),
                  Text(tr(ref, 'barberApp.logout', "Chiqish"),
                      style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isShellRoute(String r) {
    final path = r.split('?').first;
    return path == '/barber-app' ||
        path == '/shop' ||
        path == '/lopepay' ||
        path == '/home';
  }

  String _roleLabel(String role, WidgetRef ref) {
    switch (role) {
      case 'barber': return 'BARBER';
      case 'barbershop': return 'SALON';
      case 'shop': return 'LOPE PAY';
      case 'admin': return 'ADMIN';
      default: return tr(ref, 'auth.roleCustomer', 'Mijoz').toUpperCase();
    }
  }

  /// `null` means render a divider.
  List<_DrawerItem?> _itemsForRole(String role, WidgetRef ref) {
    final iAi = tr(ref, 'mobile.tabs.aiStyle', 'AI Stil');
    final iSms = tr(ref, 'mobile.barber.sms.title', 'SMS tarixi');
    final iNotif = tr(ref, 'barberApp.notifications', 'Bildirishnomalar');
    final iSettings = tr(ref, 'barberApp.settings', 'Sozlamalar');
    final iEditProfile = tr(ref, 'profile.editProfile', 'Profilni tahrirlash');
    final iPromo = tr(ref, 'promoCode.title', 'Promo kod');
    switch (role) {
      case 'barber':
        return [
          _DrawerItem(Icons.calendar_view_day, tr(ref, 'mobile.barber.schedule.title', "Jadval"), '/barber-app?tab=0'),
          _DrawerItem(Icons.people, tr(ref, 'mobile.barber.schedule.addClient', "Bugungi mijozlar"), '/barber-app?tab=1'),
          _DrawerItem(Icons.history, tr(ref, 'barberMyClients.title', "Mijozlarim"), '/barber/my-clients'),
          _DrawerItem(Icons.bar_chart, tr(ref, 'mobile.barber.stats.title', "Statistika"), '/barber-app?tab=3'),
          _DrawerItem(Icons.auto_awesome, iAi, '/ai-style'),
          null,
          _DrawerItem(Icons.edit, iEditProfile, '/barber/profile'),
          _DrawerItem(Icons.share, tr(ref, 'barberApp.publicLink', "Ommaviy havola"), '/barber/public-link'),
          _DrawerItem(Icons.notifications_active, tr(ref, 'barberApp.reminderSettings', "Eslatma sozlamalari"), '/barber/reminders'),
          _DrawerItem(Icons.location_on, tr(ref, 'barberApp.myLocation', "Manzilim"), '/barber/location'),
          _DrawerItem(Icons.credit_card, tr(ref, 'barberApp.cards', "Kartalarim"), '/barber/cards'),
          _DrawerItem(Icons.local_offer, iPromo, '/barber/promo-code'),
          null,
          _DrawerItem(Icons.account_balance_wallet, tr(ref, 'mobile.customer.transactions.title', "Hisob"), '/transactions'),
          _DrawerItem(Icons.sms, iSms, '/barber/sms'),
          _DrawerItem(Icons.notifications, iNotif, '/notifications'),
          _DrawerItem(Icons.settings, iSettings, '/barber/settings'),
        ];
      case 'barbershop':
        return [
          _DrawerItem(Icons.dashboard, tr(ref, 'mobile.shop.home.dashboard', "Boshqaruv"), '/shop?tab=0'),
          _DrawerItem(Icons.event_note, tr(ref, 'mobile.tabs.bookings', "Bronlar"), '/shop?tab=2'),
          _DrawerItem(Icons.people_alt, tr(ref, 'mobile.shop.home.masters', "Mastera"), '/shop?tab=1'),
          _DrawerItem(Icons.people_outline, tr(ref, 'shop.nav.clients', "Mijozlar"), '/shop/clients'),
          _DrawerItem(Icons.alarm, tr(ref, 'barberApp.reminderSettings', "Eslatmalar"), '/shop/reminders'),
          _DrawerItem(Icons.sms, iSms, '/shop/sms'),
          _DrawerItem(Icons.account_balance_wallet, tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"), '/shop/transactions'),
          _DrawerItem(Icons.admin_panel_settings, tr(ref, 'shop.nav.admins', "Adminlar"), '/shop/admins'),
          null,
          _DrawerItem(Icons.storefront, tr(ref, 'profile.barberProfile', "Salon profili"), '/shop/profile'),
          _DrawerItem(Icons.settings, iSettings, '/shop/settings'),
          _DrawerItem(Icons.notifications, iNotif, '/notifications'),
          _DrawerItem(Icons.auto_awesome, iAi, '/ai-style'),
        ];
      case 'shop':
        return [
          _DrawerItem(Icons.dashboard, tr(ref, 'mobile.shop.home.dashboard', "Boshqaruv"), '/lopepay?tab=0'),
          _DrawerItem(Icons.people, tr(ref, 'shop.nav.clients', "Mijozlar"), '/lopepay?tab=1'),
          _DrawerItem(Icons.assignment, tr(ref, 'mobile.lopepay.installments.title', "Rassrochkalar"), '/lopepay/installments'),
          _DrawerItem(Icons.shopping_bag, tr(ref, 'mobile.lopepay.products.title', "Mahsulotlar"), '/lopepay/products'),
          _DrawerItem(Icons.sms, iSms, '/lopepay/sms'),
          _DrawerItem(Icons.account_balance_wallet, tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"), '/lopepay/transactions'),
          null,
          _DrawerItem(Icons.notifications, iNotif, '/notifications'),
        ];
      default: // 'user'
        return [
          _DrawerItem(Icons.content_cut, tr(ref, 'mobile.tabs.discover', "Sartaroshlar"), '/home?tab=0'),
          _DrawerItem(Icons.calendar_month, tr(ref, 'mobile.tabs.bookings', "Bronlarim"), '/home?tab=2'),
          _DrawerItem(Icons.auto_awesome, iAi, '/ai-style'),
          _DrawerItem(Icons.favorite, tr(ref, 'profile.favorites', "Sevimlilar"), '/favorites'),
          _DrawerItem(Icons.map, tr(ref, 'mobile.map.title', "Xarita"), '/map'),
          null,
          _DrawerItem(Icons.account_balance_wallet, tr(ref, 'mobile.customer.transactions.title', "Hisobim"), '/transactions'),
          _DrawerItem(Icons.local_offer, iPromo, '/promo'),
          _DrawerItem(Icons.notifications, iNotif, '/notifications'),
          _DrawerItem(Icons.settings, iSettings, '/settings'),
          _DrawerItem(Icons.edit, iEditProfile, '/profile-edit'),
        ];
    }
  }
}

class _DrawerItem {
  const _DrawerItem(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String? route;
  // Drawer items don't currently render badges or destructive styles —
  // keeping the constructor narrow until we wire those up.
  String? get badge => null;
  bool get destructive => false;
}

/// Header avatar circle — renders the user's uploaded photo when set and
/// falls back to a first-letter monogram otherwise. Broken avatar URLs
/// silently degrade to the monogram instead of the CachedNetworkImage
/// error text.
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.avatar, required this.name});
  final String? avatar;
  final String? name;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: ClipOval(
        child: (avatar != null && avatar!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: assetUrl(avatar),
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => _fallback(),
                errorWidget: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Text(
          (name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
