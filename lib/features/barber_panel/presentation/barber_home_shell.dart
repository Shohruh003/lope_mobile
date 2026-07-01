import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../ai_style/presentation/ai_style_screen.dart';
import '../../lopepay/presentation/low_balance_modal.dart';
import 'barber_schedule_screen.dart';
import 'barber_bookings_screen.dart';
import 'barber_stats_screen.dart';
import 'barber_settings_screen.dart';

/// Barber shell — mirrors the web's BarberLayout: 5 bottom tabs (Schedule,
/// Clients, AI Style, Stats, Settings) and a flat top header with the
/// Lope Style logo + notification bell. NO drawer — settings is its own tab.
class BarberHomeShell extends ConsumerStatefulWidget {
  const BarberHomeShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<BarberHomeShell> createState() => _BarberHomeShellState();
}

class _BarberHomeShellState extends ConsumerState<BarberHomeShell> {
  late int _index = widget.initialTab.clamp(0, 4);
  bool _balanceCheckDone = false;

  @override
  void initState() {
    super.initState();
    // One-shot low-balance check after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_balanceCheckDone || !mounted) return;
      _balanceCheckDone = true;
      await LowBalanceWatcher.maybeShow(context, ref);
    });
  }

  static const _tabs = [
    BarberScheduleScreen(),
    BarberBookingsScreen(),
    AiStyleScreen(),
    BarberStatsScreen(),
    BarberSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
          icon: Icons.calendar_today,
          label: tr(ref, 'mobile.barber.home.schedule', 'Jadval')),
      _Item(
          icon: Icons.people_outline,
          label: tr(ref, 'shop.nav.clients', 'Mijozlar')),
      _Item(
          icon: Icons.auto_awesome,
          label: tr(ref, 'mobile.tabs.aiStyle', 'AI Stil')),
      _Item(
          icon: Icons.bar_chart,
          label: tr(ref, 'mobile.barber.home.stats', 'Statistika')),
      _Item(
          icon: Icons.person_outline,
          label: tr(ref, 'mobile.tabs.profile', 'Profil')),
    ];
    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(children: [
        const _Header(),
        Expanded(child: IndexedStack(index: _index, children: _tabs)),
      ]),
      bottomNavigationBar: _BottomBar(items: items, index: _index, onSelect: (i) => setState(() => _index = i)),
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
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu, color: AppColors.textPrimary, size: 22),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Row(children: const [
            Icon(Icons.content_cut, color: AppColors.primary, size: 24),
            SizedBox(width: 6),
            Text("Lope Style",
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
          ]),
          const Spacer(),
          const NotificationBell(),
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
                    Icon(item.icon,
                        color: active ? AppColors.primary : AppColors.textMuted,
                        size: active ? 24 : 20),
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
