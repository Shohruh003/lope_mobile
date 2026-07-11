import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../ai_style/presentation/ai_style_screen.dart';
import '../../lopepay/presentation/low_balance_modal.dart';
import 'barber_schedule_screen.dart';
import 'barber_bookings_screen.dart';
import 'barber_stats_screen.dart';
import 'barber_settings_screen.dart';

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
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: tr(ref, 'mobile.barber.home.schedule', 'Jadval'),
      ),
      _Item(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: tr(ref, 'shop.nav.clients', 'Mijozlar'),
      ),
      _Item(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome,
        label: tr(ref, 'mobile.tabs.aiStyle', 'AI Stil'),
      ),
      _Item(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: tr(ref, 'mobile.barber.home.stats', 'Statistika'),
      ),
      _Item(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: tr(ref, 'mobile.tabs.profile', 'Profil'),
      ),
    ];
    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(children: [
        const _Header(),
        Expanded(child: IndexedStack(index: _index, children: _tabs)),
      ]),
      bottomNavigationBar: _BottomBar(
        items: items,
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadius.rMd,
              boxShadow: AppShadows.primaryGlow(AppColors.primary),
            ),
            child: const Icon(Icons.content_cut,
                color: Colors.white, size: 18),
          ),
          AppSpacing.hGapSm,
          Text(
            'Lope Style',
            style: AppText.titleMd.copyWith(
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          const NotificationBell(),
          AppSpacing.hGapXs,
          TapScale(
            onTap: () {
              AppHaptics.selection();
              Scaffold.of(context).openDrawer();
            },
            scale: 0.9,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.border),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.menu_rounded,
                  color: context.colors.textPrimary, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.items,
    required this.index,
    required this.onSelect,
  });
  final List<_Item> items;
  final int index;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(top: BorderSide(color: context.colors.border)),
        boxShadow: AppShadows.subtle,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final active = i == index;
                final item = items[i];
                return Expanded(
                  child: TapScale(
                    onTap: () => onSelect(i),
                    haptic: HapticStrength.selection,
                    scale: 0.94,
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      curve: AppMotion.emphasized,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: active
                            ? AppColors.primaryGradient
                            : null,
                        borderRadius: AppRadius.rLg,
                        boxShadow: active
                            ? AppShadows.primaryGlow(AppColors.primary)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            active ? item.activeIcon : item.icon,
                            color: active
                                ? Colors.white
                                : context.colors.textMuted,
                            size: 22,
                          ),
                          if (active) ...[
                            AppSpacing.hGapXs,
                            Flexible(
                              child: Text(
                                item.label,
                                style: AppText.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
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
  const _Item({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
