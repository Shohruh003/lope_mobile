import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import 'shop_barbers_screen.dart';
import 'shop_bookings_screen.dart';
import 'shop_dashboard_screen.dart';
import 'shop_settings_screen.dart';

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
    ShopSettingsScreen(),
  ];
  static const _items = [
    _Item(icon: Icons.dashboard_outlined, label: 'Boshqaruv'),
    _Item(icon: Icons.people_alt_outlined, label: 'Mastera'),
    _Item(icon: Icons.event_note_outlined, label: 'Bronlar'),
    _Item(icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        const _Header(),
        Expanded(child: IndexedStack(index: _index, children: _tabs)),
      ]),
      bottomNavigationBar: _BottomBar(items: _items, index: _index, onSelect: (i) => setState(() => _index = i)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          Row(children: const [
            Icon(Icons.storefront, color: AppColors.primary, size: 24),
            SizedBox(width: 6),
            Text("Lope Style",
                style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.items, required this.index, required this.onSelect});
  final List<_Item> items;
  final int index;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(children: List.generate(items.length, (i) {
            final active = i == index;
            final item = items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: active ? AppColors.primary : AppColors.textMuted, size: active ? 24 : 20),
                    const SizedBox(height: 2),
                    Text(item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        )),
                  ],
                ),
              ),
            );
          })),
        ),
      ),
    );
  }
}

class _Item {
  const _Item({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
