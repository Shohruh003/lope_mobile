import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final int _index = widget.initialTab.clamp(0, 3);

  static const _tabs = [
    ShopDashboardScreen(),
    ShopBarbersScreen(),
    ShopBookingsScreen(),
    ShopSettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    // Bottom nav removed at user request — everything runs through
    // the side drawer (Boshqaruv / Bronlar / Mastera / Salon
    // profili / Adminlar / Mijozlar / SMS / Tranzaksiyalar / etc.).
    // The IndexedStack + `?tab=X` query param on `/shop` still work
    // so drawer entries continue to switch the visible tab without a
    // full route change.
    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(children: [
        const _Header(),
        Expanded(child: IndexedStack(index: _index, children: _tabs)),
      ]),
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

