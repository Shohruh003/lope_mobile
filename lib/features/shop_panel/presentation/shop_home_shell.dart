import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import 'shop_barbers_screen.dart';
import 'shop_bookings_screen.dart';
import 'shop_dashboard_screen.dart';
import 'shop_settings_screen.dart';

class ShopHomeShell extends ConsumerStatefulWidget {
  const ShopHomeShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<ShopHomeShell> createState() => _ShopHomeShellState();
}

class _ShopHomeShellState extends ConsumerState<ShopHomeShell> {
  late int _index = widget.initialTab.clamp(0, 3);

  static const _tabs = [
    ShopDashboardScreen(),
    ShopBarbersScreen(),
    ShopBookingsScreen(),
    ShopSettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: tr(ref, 'mobile.shop.home.dashboard', 'Boshqaruv'),
      ),
      _Item(
        icon: Icons.people_alt_outlined,
        activeIcon: Icons.people_alt,
        label: tr(ref, 'mobile.shop.home.masters', 'Mastera'),
      ),
      _Item(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note,
        label: tr(ref, 'mobile.shop.home.bookings', 'Bronlar'),
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
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
            child: const Icon(Icons.storefront,
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
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.menu_rounded,
                  color: AppColors.textPrimary, size: 20),
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
        color: AppColors.background,
        border: const Border(top: BorderSide(color: AppColors.border)),
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
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
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
                                : AppColors.textMuted,
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
