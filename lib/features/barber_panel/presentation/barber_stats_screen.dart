import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

/// Lightweight stats for the barber: this week / month booking totals,
/// computed client-side from the bookings list. The web has a richer stats
/// page; this is the v1 mobile equivalent.
class BarberStatsScreen extends ConsumerWidget {
  const BarberStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberAllBookingsProvider(barberId));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(barberAllBookingsProvider(barberId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text(
                "Statistika",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 16),
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text("Xato: $e",
                    style: const TextStyle(color: AppColors.textMuted)),
                data: (list) {
                  final now = DateTime.now();
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final monthAgo = DateTime(now.year, now.month - 1, now.day);

                  int weekCount = 0, monthCount = 0, totalRev = 0;
                  int weekRev = 0, monthRev = 0;
                  for (final b in list) {
                    final d = DateTime.tryParse(b.date);
                    if (d == null) continue;
                    if (b.status == 'cancelled') continue;
                    totalRev += b.totalPrice;
                    if (d.isAfter(weekAgo)) {
                      weekCount++;
                      weekRev += b.totalPrice;
                    }
                    if (d.isAfter(monthAgo)) {
                      monthCount++;
                      monthRev += b.totalPrice;
                    }
                  }

                  return Column(
                    children: [
                      _StatCard(
                        label: 'Bu hafta',
                        primary: '$weekCount ta bron',
                        secondary: "${_fmt(weekRev)} so'm",
                        color: AppColors.primary,
                        delay: 0,
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        label: 'Bu oy',
                        primary: '$monthCount ta bron',
                        secondary: "${_fmt(monthRev)} so'm",
                        color: AppColors.success,
                        delay: 80,
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        label: 'Jami daromad',
                        primary: "${_fmt(totalRev)} so'm",
                        secondary: '${list.length} ta bron tarixi',
                        color: AppColors.warning,
                        delay: 160,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i;
      buf.write(s[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.color,
    required this.delay,
  });
  final String label;
  final String primary;
  final String secondary;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.bar_chart, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(primary,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(secondary,
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: delay.ms).slideY(begin: 0.1, end: 0);
  }
}
