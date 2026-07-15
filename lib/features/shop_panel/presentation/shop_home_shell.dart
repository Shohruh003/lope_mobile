import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/shared.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../data/shop_repository.dart';
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
  void didUpdateWidget(covariant ShopHomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drawer entries navigate via `context.go('/shop?tab=X')` which
    // reuses this State but hands us a new `initialTab`. Without
    // this sync `_index` stayed at whatever was set on first mount,
    // so tapping Bronlar / Mastera from the drawer just re-rendered
    // the Boshqaruv tab.
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() => _index = widget.initialTab.clamp(0, 3));
    }
  }
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

class _Header extends ConsumerWidget {
  const _Header();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // Same scissors logo as the customer / barber shells — one
            // Lope Style brand mark across every panel. "Lope Style"
            // wordmark dropped so the balance chip has room to sit
            // in the centre of the header.
            child: const Icon(Icons.content_cut,
                color: Colors.white, size: 18),
          ),
          const Spacer(),
          const _BalanceChip(),
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

/// Compact pill in the centre of the shop shell header. Renders the
/// current shop balance and taps through to the transactions screen —
/// gives the shop owner a persistent, always-visible reference point
/// for what's in the wallet (previously buried under Drawer →
/// Tranzaktsiyalar).
class _BalanceChip extends ConsumerWidget {
  const _BalanceChip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopBalanceProvider);
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        context.push('/shop/transactions');
      },
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: AppRadius.rPill,
          boxShadow: AppShadows.primaryGlow(AppColors.primary),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 14),
          const SizedBox(width: 6),
          async.when(
            loading: () => const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            error: (_, _) => const Text('—',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            data: (b) => Text(
              "${_fmtMoney(b)} so'm",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

String _fmtMoney(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ri = s.length - i;
    buf.write(s[i]);
    if (ri > 1 && ri % 3 == 1) buf.write(' ');
  }
  return (n < 0 ? '−' : '') + buf.toString();
}

