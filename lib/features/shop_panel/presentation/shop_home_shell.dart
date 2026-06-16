import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../profile/presentation/profile_screen.dart';

/// Bottom-nav shell for the SHOP / BARBERSHOP role. v1 is a single overview
/// + profile tab; we'll expand to match the web's full shop dashboard
/// (master management, bookings, stats, finance) incrementally.
class ShopHomeShell extends ConsumerStatefulWidget {
  const ShopHomeShell({super.key});

  @override
  ConsumerState<ShopHomeShell> createState() => _ShopHomeShellState();
}

class _ShopHomeShellState extends ConsumerState<ShopHomeShell> {
  int _index = 0;

  static const _tabs = [
    _ShopOverviewTab(),
    ProfileScreen(),
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
              children: [
                _Tab(
                  active: _index == 0,
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront,
                  label: 'Salonim',
                  onTap: () => setState(() => _index = 0),
                ),
                _Tab(
                  active: _index == 1,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  onTap: () => setState(() => _index = 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? activeIcon : icon,
                color: active ? AppColors.primary : AppColors.textMuted,
                size: 24,
              )
                  .animate(target: active ? 1 : 0)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 200.ms),
              const SizedBox(height: 4),
              Text(
                label,
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
  }
}

class _ShopOverviewTab extends StatelessWidget {
  const _ShopOverviewTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              "Salonim",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 4),
            const Text(
              "Boshqaruv paneli — tez orada",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text("Eslatma",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Salon boshqaruvi (mastera, bronlar, statistika, moliya) hozircha veb-versiyada to'liq mavjud. "
                    "Mobile ilovaga bosqichma-bosqich olib o'tilmoqda.",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text("app.lopestyle.uz da ochish"),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}
