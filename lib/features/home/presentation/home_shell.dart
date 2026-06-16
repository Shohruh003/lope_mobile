import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../bookings/presentation/my_bookings_screen.dart';
import '../../barbers/presentation/barbers_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Bottom-nav shell for the customer flow. Four tabs: discover barbers, my
/// bookings, AI style (placeholder for now), profile. Each tab keeps its
/// own state across switches via IndexedStack.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = [
    BarbersListScreen(),
    MyBookingsScreen(),
    _AiStylePlaceholder(),
    ProfileScreen(),
  ];

  static const _items = [
    _TabItem(icon: Icons.content_cut_outlined, activeIcon: Icons.content_cut, labelKey: 'tabs.discover'),
    _TabItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, labelKey: 'tabs.bookings'),
    _TabItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, labelKey: 'tabs.aiStyle'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, labelKey: 'tabs.profile'),
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) {
                final active = _index == i;
                final item = _items[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
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
                            _labelFor(item.labelKey),
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

  /// Small inline label map — keeps the shell independent of L10n boot order
  /// so the very first frame doesn't show key names. Real i18n is wired
  /// through the L10n provider for the screens themselves.
  String _labelFor(String key) {
    switch (key) {
      case 'tabs.discover':
        return 'Topish';
      case 'tabs.bookings':
        return 'Bronlar';
      case 'tabs.aiStyle':
        return 'AI Stil';
      case 'tabs.profile':
        return 'Profil';
    }
    return '';
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.activeIcon, required this.labelKey});
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
}

class _AiStylePlaceholder extends StatelessWidget {
  const _AiStylePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 40),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  duration: 1500.ms,
                  begin: const Offset(0.94, 0.94),
                  end: const Offset(1.06, 1.06),
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 20),
            const Text("AI Stil tez orada", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Sochingiz va soqolingiz uchun yangi stillarni AI orqali ko'rib chiqing.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
