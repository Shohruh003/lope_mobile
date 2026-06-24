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
                  int confirmedCount = 0, completedCount = 0, cancelledCount = 0;
                  final serviceAgg = <String, ({String name, int count, int revenue})>{};
                  // Build day-of-week (Mon=0..Sun=6) bucket for the bar chart.
                  final byDow = List<int>.filled(7, 0);
                  for (final b in list) {
                    final d = DateTime.tryParse(b.date);
                    if (d == null) continue;
                    switch (b.status) {
                      case 'confirmed':
                        confirmedCount++;
                        break;
                      case 'completed':
                        completedCount++;
                        break;
                      case 'cancelled':
                        cancelledCount++;
                        break;
                    }
                    if (b.status == 'cancelled') continue;
                    totalRev += b.totalPrice;
                    // Aggregate services for the Top Services card.
                    for (final s in b.services) {
                      final key = s.name;
                      final prev = serviceAgg[key];
                      serviceAgg[key] = (
                        name: s.name,
                        count: (prev?.count ?? 0) + 1,
                        revenue: (prev?.revenue ?? 0) + s.price,
                      );
                    }
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
                  final topServices = serviceAgg.values.toList()
                    ..sort((a, b) => b.count.compareTo(a.count));

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
                      const SizedBox(height: 14),

                      // ===== Booking status breakdown (mirrors web) =====
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
                            Text(
                                tr(ref, 'barberApp.bookingsByStatus',
                                    "Bronlar holati bo'yicha"),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textBright)),
                            const SizedBox(height: 12),
                            _StatusRow(
                                color: const Color(0xFF3B82F6),
                                label: tr(ref, 'status.confirmed',
                                    'Tasdiqlangan'),
                                count: confirmedCount),
                            const SizedBox(height: 8),
                            _StatusRow(
                                color: const Color(0xFF22C55E),
                                label:
                                    tr(ref, 'status.completed', 'Yakunlangan'),
                                count: completedCount),
                            const SizedBox(height: 8),
                            _StatusRow(
                                color: const Color(0xFFEF4444),
                                label:
                                    tr(ref, 'status.cancelled', 'Bekor qilingan'),
                                count: cancelledCount),
                          ],
                        ),
                      ),

                      if (topServices.isNotEmpty) ...[
                        const SizedBox(height: 14),
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
                              Text(
                                  tr(ref, 'barberApp.topServices',
                                      "Eng ko'p so'ralgan xizmatlar"),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.textBright)),
                              const SizedBox(height: 10),
                              ...topServices.take(5).toList().asMap().entries.map(
                                  (e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: _TopServiceRow(
                                          rank: e.key + 1,
                                          name: e.value.name,
                                          count: e.value.count,
                                          revenue: e.value.revenue,
                                          currency: tr(ref, 'common.currency',
                                              "so'm"),
                                          fmt: _fmt,
                                        ),
                                      )),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),
                      _SmsStatsCard(barberId: barberId),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow(
      {required this.color, required this.label, required this.count});
  final Color color;
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textBright, fontSize: 13)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text("$count",
            style: const TextStyle(
                color: AppColors.textBright,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    ]);
  }
}

class _TopServiceRow extends StatelessWidget {
  const _TopServiceRow({
    required this.rank,
    required this.name,
    required this.count,
    required this.revenue,
    required this.currency,
    required this.fmt,
  });
  final int rank;
  final String name;
  final int count;
  final int revenue;
  final String currency;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 22,
        child: Text("#$rank",
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ),
      Expanded(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.textBright, fontSize: 13)),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text("${count}x",
            style: const TextStyle(
                color: AppColors.textBright,
                fontWeight: FontWeight.w700,
                fontSize: 11)),
      ),
      const SizedBox(width: 8),
      Text("${fmt(revenue)} $currency",
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

/// SMS-billing breakdown card. Mirrors the web BarberStatsScreen SMS
/// section — total sent + total cost at the top, per-type
/// (confirmation / reminder / retention) rows below.
class _SmsStatsCard extends ConsumerWidget {
  const _SmsStatsCard({required this.barberId});
  final String barberId;

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final firstOfMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final async = ref.watch(barberSmsStatsProvider(
        (barberId: barberId, from: firstOfMonth, to: today)));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.sms_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(tr(ref, 'mobile.barber.stats.smsTitle', "SMS xizmat"),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textBright)),
            const Spacer(),
            Text(tr(ref, 'mobile.barber.stats.thisMonth', "Bu oy"),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
            data: (s) => Column(
              children: [
                _SummaryRow(
                    label: tr(ref, 'mobile.barber.stats.smsTotal',
                        "Jami SMS"),
                    value:
                        "${s.totalSent} · ${_fmt(s.totalCost)} ${tr(ref, 'common.currency', "so'm")}"),
                const Divider(color: AppColors.border, height: 14),
                _SummaryRow(
                    label: tr(ref, 'mobile.barber.stats.smsConfirmation',
                        "Tasdiqlash"),
                    value:
                        "${s.confirmationRegistered + s.confirmationGuest} · ${_fmt(s.confirmationRegisteredCost + s.confirmationGuestCost)} ${tr(ref, 'common.currency', "so'm")}"),
                const Divider(color: AppColors.border, height: 14),
                _SummaryRow(
                    label: tr(ref, 'mobile.barber.stats.smsReminder',
                        "Eslatma"),
                    value:
                        "${s.reminderCount} · ${_fmt(s.reminderCost)} ${tr(ref, 'common.currency', "so'm")}"),
                const Divider(color: AppColors.border, height: 14),
                _SummaryRow(
                    label: tr(ref, 'mobile.barber.stats.smsRetention',
                        "Retention"),
                    value:
                        "${s.retentionCount} · ${_fmt(s.retentionCost)} ${tr(ref, 'common.currency', "so'm")}"),
                if (s.returnedClients > 0) ...[
                  const Divider(color: AppColors.border, height: 14),
                  _SummaryRow(
                      label: tr(ref, 'mobile.barber.stats.smsReturned',
                          "Qaytib kelganlar"),
                      value: "${s.returnedClients}"),
                  if (s.totalSent > 0) ...[
                    const Divider(color: AppColors.border, height: 14),
                    _SummaryRow(
                        label: tr(ref, 'mobile.barber.stats.smsConversion',
                            "Konversiya"),
                        value:
                            "${((s.returnedClients / s.totalSent) * 100).round()}%"),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
