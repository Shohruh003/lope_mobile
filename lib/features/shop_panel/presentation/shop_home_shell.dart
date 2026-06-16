import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../profile/presentation/profile_screen.dart';
import 'shop_barbers_screen.dart';
import 'shop_bookings_screen.dart';
import 'shop_dashboard_screen.dart';

/// 4-tab shell for the barbershop / shop role: dashboard, masters, bookings,
/// profile. Each is a real screen now — no more "tez orada" placeholders.
class ShopHomeShell extends ConsumerStatefulWidget {
  const ShopHomeShell({super.key});

  @override
  ConsumerState<ShopHomeShell> createState() => _ShopHomeShellState();
}

class _ShopHomeShellState extends ConsumerState<ShopHomeShell> {
  int _index = 0;

  static const _tabs = [
    ShopDashboardScreen(),
    ShopBarbersScreen(),
    ShopBookingsScreen(),
    ProfileScreen(),
  ];

  late final List<_Item> _items;

  @override
  void initState() {
    super.initState();
    _items = const [
      _Item(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, labelKey: 'mobile.shop.home.dashboard', fallback: 'Boshqaruv'),
      _Item(icon: Icons.people_alt_outlined, activeIcon: Icons.people_alt, labelKey: 'mobile.shop.home.masters', fallback: 'Mastera'),
      _Item(icon: Icons.event_note_outlined, activeIcon: Icons.event_note, labelKey: 'mobile.shop.home.bookings', fallback: 'Bronlar'),
      _Item(icon: Icons.person_outline, activeIcon: Icons.person, labelKey: 'mobile.shop.home.profile', fallback: 'Profil'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: List.generate(_items.length, (i) {
                final active = _index == i;
                final item = _items[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            color: active ? AppColors.primary : AppColors.textMuted,
                            size: 24,
                          )
                              .animate(target: active ? 1 : 0)
                              .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 200.ms),
                          const SizedBox(height: 4),
                          Text(tr(ref, item.labelKey, item.fallback),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                color: active ? AppColors.primary : AppColors.textMuted,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item {
  const _Item({required this.icon, required this.activeIcon, required this.labelKey, required this.fallback});
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final String fallback;
}
