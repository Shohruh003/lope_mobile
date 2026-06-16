import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../profile/presentation/profile_screen.dart';
import 'barber_schedule_screen.dart';
import 'barber_bookings_screen.dart';
import 'barber_stats_screen.dart';

/// Bottom-nav shell for the BARBER role. Mirrors the web's barber app: today's
/// schedule, all bookings, stats, profile.
class BarberHomeShell extends ConsumerStatefulWidget {
  const BarberHomeShell({super.key});

  @override
  ConsumerState<BarberHomeShell> createState() => _BarberHomeShellState();
}

class _BarberHomeShellState extends ConsumerState<BarberHomeShell> {
  int _index = 0;

  static const _tabs = [
    BarberScheduleScreen(),
    BarberBookingsScreen(),
    BarberStatsScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    _TabItem(icon: Icons.calendar_view_day_outlined, activeIcon: Icons.calendar_view_day, labelKey: 'mobile.barber.home.schedule', fallback: 'Jadval'),
    _TabItem(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, labelKey: 'mobile.barber.home.bookings', fallback: 'Bronlar'),
    _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, labelKey: 'mobile.barber.home.stats', fallback: 'Statistika'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, labelKey: 'mobile.barber.home.profile', fallback: 'Profil'),
  ];

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
                          Text(
                            tr(ref, item.labelKey, item.fallback),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? AppColors.primary : AppColors.textMuted,
                            ),
                          ),
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

class _TabItem {
  const _TabItem({required this.icon, required this.activeIcon, required this.labelKey, required this.fallback});
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final String fallback;
}
