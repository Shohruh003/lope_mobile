import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import '../../ai_style/presentation/ai_style_screen.dart';
import '../../bookings/presentation/my_bookings_screen.dart';
import '../../barbers/presentation/barbers_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Customer shell — mirrors the web's CustomerLayout exactly:
///   - Top header: Scissors+Logo (primary) on left, notification bell on right
///   - Bottom tab bar: 4 tabs (Barbers, AI Style, Bookings, Profile), active
///     tab gets a slightly bigger icon and bolder weight
///   - NO drawer (the web doesn't have one for the customer role)
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    BarbersListScreen(),
    AiStyleScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    _Item(icon: Icons.content_cut, label: 'Sartaroshlar'),
    _Item(icon: Icons.auto_awesome, label: 'AI Stil'),
    _Item(icon: Icons.calendar_today, label: 'Bronlar'),
    _Item(icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _CustomerHeader(),
          Expanded(child: IndexedStack(index: _index, children: _tabs)),
        ],
      ),
      bottomNavigationBar: _BottomTabBar(
        items: _items,
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Header bar — `border-b bg-background/95 backdrop-blur` in web. Logo
/// (Scissors + "Lope Style") on left, notification bell on right.
class _CustomerHeader extends ConsumerWidget {
  const _CustomerHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(children: [
          InkWell(
            onTap: () {},
            child: Row(children: const [
              Icon(Icons.content_cut, color: AppColors.primary, size: 24),
              SizedBox(width: 6),
              Text("Lope Style",
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
            ]),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Bildirishnomalar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
        ]),
      ),
    );
  }
}

/// Bottom tab bar — flat, no shadow. Active tab: primary color, icon 24px
/// + label w600. Inactive: textMuted, icon 20px + label w500. Matches the
/// web's `flex flex-col items-center justify-center` tabs.
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({required this.items, required this.index, required this.onSelect});
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
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          item.icon,
                          color: active ? AppColors.primary : AppColors.textMuted,
                          size: active ? 24 : 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
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
