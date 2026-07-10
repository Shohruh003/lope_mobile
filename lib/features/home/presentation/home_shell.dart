import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../ai_style/presentation/ai_style_screen.dart';
import '../../bookings/presentation/my_bookings_screen.dart';
import '../../barbers/presentation/barbers_list_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Customer shell — 4-tab bottom nav bilan (Sartaroshlar / AI Stil /
/// Bronlar / Profil). Uzum/Click darajasidagi bottom bar:
///   - Aktiv tab uchun primary rangdagi ko'targan pill (gradient + glow)
///   - Nofaol tabs: monochromatic ikon, kichkina label
///   - Har tap qilinganda TapScale + selection haptic
///
/// Header: gradient logo pill + notification bell + drawer icon.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late int _index = widget.initialTab.clamp(0, 3);

  static const _tabs = [
    BarbersListScreen(),
    AiStyleScreen(),
    MyBookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      _Item(
        icon: Icons.content_cut,
        activeIcon: Icons.content_cut,
        label: tr(ref, 'mobile.tabs.discover', 'Sartaroshlar'),
      ),
      _Item(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome,
        label: tr(ref, 'mobile.tabs.aiStyle', 'AI Stil'),
      ),
      _Item(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today,
        label: tr(ref, 'mobile.tabs.bookings', 'Bronlar'),
      ),
      _Item(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: tr(ref, 'mobile.tabs.profile', 'Profil'),
      ),
    ];
    return Scaffold(
      // No side drawer for customers — pro apps (Uzum/Click/Instagram)
      // route secondary destinations through the Profile tab and header
      // shortcuts instead of a hamburger menu.
      body: Column(
        children: [
          const _CustomerHeader(),
          Expanded(child: IndexedStack(index: _index, children: _tabs)),
        ],
      ),
      bottomNavigationBar: _BottomTabBar(
        items: items,
        index: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Top header — brand pill + notification bell + drawer.
class _CustomerHeader extends ConsumerWidget {
  const _CustomerHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Brand — gradient icon + wordmark
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
          // Match NotificationBell's plain-IconButton look — no circular
          // chip around the icon so both header actions read as one row.
          IconButton(
            tooltip: tr(ref, 'profile.favorites', 'Masterim'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.bookmark_border,
                color: AppColors.textPrimary, size: 22),
            onPressed: () {
              AppHaptics.selection();
              context.push('/favorites');
            },
          ),
          const NotificationBell(),
        ]),
      ),
    );
  }
}

/// Bottom nav bar — aktiv tab primary gradient pill sifatida ko'tariladi,
/// nofaol tabs faqat kichik ikon + label. Har tap TapScale + haptic.
class _BottomTabBar extends StatelessWidget {
  const _BottomTabBar({
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
                            AnimatedSize(
                              duration: AppMotion.base,
                              curve: AppMotion.emphasized,
                              child: Text(
                                item.label,
                                style: AppText.caption.copyWith(
                                  color: Colors.white,
                                  fontSize: 12,
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
