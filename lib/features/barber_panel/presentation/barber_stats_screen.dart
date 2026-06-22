import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/stat_charts.dart';
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
              Text(
                tr(ref, 'mobile.barber.stats.title', "Statistika"),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright),
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted)),
                data: (list) {
                  final now = DateTime.now();
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final monthAgo = DateTime(now.year, now.month - 1, now.day);

                  int weekCount = 0, monthCount = 0, totalRev = 0;
                  int weekRev = 0, monthRev = 0;
                  // Build day-of-week (Mon=0..Sun=6) bucket for the bar chart.
                  final byDow = List<int>.filled(7, 0);
                  for (final b in list) {
                    final d = DateTime.tryParse(b.date);
                    if (d == null) continue;
                    if (b.status == 'cancelled') continue;
                    totalRev += b.totalPrice;
                    if (d.isAfter(weekAgo)) {
                      weekCount++;
                      weekRev += b.totalPrice;
                      // weekday: 1=Mon..7=Sun → index 0..6
                      byDow[d.weekday - 1]++;
                    }
                    if (d.isAfter(monthAgo)) {
                      monthCount++;
                      monthRev += b.totalPrice;
                    }
                  }

                  // Count today's bookings (matches web's todayCount)
                  final todayStr =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final todayCount = list
                      .where((b) => b.date == todayStr && b.status != 'cancelled')
                      .length;
                  final uniqueClients = list
                      .where((b) => b.status != 'cancelled')
                      .map((b) => b.userPhone ?? b.guestPhone ?? b.userName)
                      .toSet()
                      .length;

                  // 4 stat tiles, 2x2 — matches web's statCards array exactly.
                  return Column(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.45,
                        children: [
                          _StatTile(
                            icon: Icons.event_available,
                            label: tr(ref, 'mobile.barber.stats.todayBookings', "Bugungi bronlar"),
                            value: "$todayCount",
                            color: const Color(0xFF3B82F6), // blue-500
                          ),
                          _StatTile(
                            icon: Icons.trending_up,
                            label: tr(ref, 'mobile.barber.stats.month', "Bu oy"),
                            value: "$monthCount",
                            color: const Color(0xFF22C55E), // green-500
                          ),
                          _StatTile(
                            icon: Icons.people_outline,
                            label: tr(ref, 'mobile.barber.stats.totalClients', "Jami mijozlar"),
                            value: "$uniqueClients",
                            color: const Color(0xFFA855F7), // purple-500
                          ),
                          _StatTile(
                            icon: Icons.attach_money,
                            label: tr(ref, 'mobile.barber.stats.monthRevenue', "Bu oy daromad"),
                            value: "${_fmt(monthRev)} ${tr(ref, 'common.currency', "so'm")}",
                            color: const Color(0xFF10B981), // emerald-500
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Weekly bar chart card
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(ref, 'mobile.barber.stats.weeklyBookings', "Haftalik bronlar"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textBright)),
                            const SizedBox(height: 8),
                            WeeklyBookingsBarChart(
                              counts: byDow,
                              dayLabels: trList(ref, 'mobile.dates.weekDaysShort',
                                  const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya']),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr(ref, 'mobile.barber.stats.summary', "Umumiy hisob"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textBright)),
                            const SizedBox(height: 10),
                            _SummaryRow(
                                label: tr(ref, 'mobile.barber.stats.week', "Bu hafta"),
                                value: "$weekCount ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')} · ${_fmt(weekRev)} ${tr(ref, 'common.currency', "so'm")}"),
                            const Divider(color: AppColors.border, height: 14),
                            _SummaryRow(
                                label: tr(ref, 'mobile.barber.stats.totalBookings', "Jami bronlar"),
                                value: "${list.length} ${tr(ref, 'mobile.barber.stats.countSuffix', 'ta')}"),
                            const Divider(color: AppColors.border, height: 14),
                            _SummaryRow(
                                label: tr(ref, 'mobile.barber.stats.total', "Jami daromad"),
                                value: "${_fmt(totalRev)} ${tr(ref, 'common.currency', "so'm")}"),
                          ],
                        ),
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

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      color: AppColors.textBright)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(
                color: AppColors.textBright,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
