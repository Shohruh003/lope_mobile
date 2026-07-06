import 'package:fl_chart/fl_chart.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/shadcn.dart';
import '../data/shop_repository.dart';

/// Mirrors web `BarbershopDashboard.tsx`:
///   - Salon name + address header with date-range picker
///   - "Bugungi tushum" emerald card (today's revenue, separate from period)
///   - 4 KPI cards: Bookings / Revenue / Unique Clients / New Clients
///   - 4 Shortcut cards: Barbers / Due for reminder / SMS sent / From SMS
///   - Bookings over time area chart
///   - New clients growth line chart
///   - Navigation tile group (existing)
class ShopDashboardScreen extends ConsumerStatefulWidget {
  const ShopDashboardScreen({super.key});
  @override
  ConsumerState<ShopDashboardScreen> createState() =>
      _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends ConsumerState<ShopDashboardScreen> {
  static final _fmtNum = NumberFormat.decimalPattern('ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: _to,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(shopMeProvider);
    final stats = ref.watch(shopStatsFilteredProvider(
        (from: _ymd.format(_from), to: _ymd.format(_to))));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(shopMeProvider);
            ref.invalidate(shopStatsFilteredProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ===== Salon header =====
              me.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (m) => ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const ShadIconBubble(icon: Icons.storefront_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              tr(ref, 'mobile.shop.dashboard.salonLabel',
                                  "Salonim"),
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text((m['name'] ?? '').toString(),
                              style: const TextStyle(
                                  color: AppColors.textBright,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          if ((m['address'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text((m['address']).toString(),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ===== Date range pickers =====
              Row(children: [
                Expanded(child: _DatePill(label: _ymd.format(_from), onTap: _pickFrom)),
                const SizedBox(width: 8),
                const Text("—",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(child: _DatePill(label: _ymd.format(_to), onTap: _pickTo)),
              ]),
              const SizedBox(height: 16),

              // ===== Today's cash card (independent of period) =====
              stats.when(
                loading: () => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSkeleton(height: 110, borderRadius: 12),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                    ]),
                    SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                    ]),
                  ],
                ),
                error: (e, _) => SizedBox(
                  height: 320,
                  child: AppErrorState(
                    message: humanize(e),
                    onRetry: () => ref.invalidate(shopStatsFilteredProvider),
                  ),
                ),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayCashCard(stats: s),
                    const SizedBox(height: 14),

                    // ===== KPI cards row 1 (4 cards: Bookings/Revenue/Unique/New) =====
                    _kpiGrid([
                      _Kpi(
                          icon: Icons.event_available,
                          label: tr(ref, 'shop.stats.bookings', 'Bronlar'),
                          value: _fmtNum.format(s.bookings),
                          color: AppColors.primary),
                      _Kpi(
                          icon: Icons.attach_money,
                          label: tr(ref, 'shop.stats.revenue', 'Daromad'),
                          value:
                              "${_fmtNum.format(s.revenue)} ${tr(ref, 'common.currency', "so'm")}",
                          color: AppColors.success),
                      _Kpi(
                          icon: Icons.people_outline,
                          label: tr(ref, 'shop.stats.uniqueClients',
                              'Mijozlar'),
                          value: _fmtNum.format(s.uniqueClients),
                          color: const Color(0xFF8B5CF6)),
                      _Kpi(
                          icon: Icons.person_add_outlined,
                          label: tr(ref, 'shop.stats.newClients',
                              'Yangi mijozlar'),
                          value: _fmtNum.format(s.newClients),
                          color: AppColors.warning),
                    ]),
                    const SizedBox(height: 10),

                    // ===== KPI cards row 2 (shortcuts) =====
                    _kpiGrid([
                      _Kpi(
                          icon: Icons.content_cut,
                          label: tr(ref, 'shop.nav.barbers', 'Masterlar'),
                          value:
                              "${s.barbersCount} ${tr(ref, 'common.pcs', 'ta')}",
                          color: AppColors.primary,
                          onTap: () => context.go('/shop?tab=1')),
                      _Kpi(
                          icon: Icons.notifications_active_outlined,
                          label: tr(ref, 'shop.stats.dueForReminder',
                              'Eslatma kutilmoqda'),
                          value:
                              "${s.clientsDueForReminder} ${tr(ref, 'common.pcs', 'ta')}",
                          color: const Color(0xFFF97316),
                          onTap: () => context.push('/shop/reminders')),
                      _Kpi(
                          icon: Icons.sms_outlined,
                          label: tr(ref, 'shop.stats.smsSent', 'SMS yuborildi'),
                          value:
                              "${s.messages} ${tr(ref, 'common.pcs', 'ta')}",
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.push('/shop/sms')),
                      _Kpi(
                          icon: Icons.trending_up,
                          label:
                              tr(ref, 'shop.stats.fromSms', "SMS'dan"),
                          value:
                              "${s.fromSmsBookings} ${tr(ref, 'common.pcs', 'ta')}",
                          color: AppColors.success,
                          onTap: () => context.push('/shop/sms')),
                    ]),

                    if (s.daily.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _SectionTitle(
                          icon: Icons.trending_up,
                          label: tr(ref, 'shop.chart.bookingsOverTime',
                              'Bronlar vaqt bo\'yicha')),
                      const SizedBox(height: 8),
                      ShadCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: SizedBox(
                          height: 200,
                          child: _BookingsChart(daily: s.daily),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionTitle(
                          icon: Icons.person_add,
                          label: tr(ref, 'shop.chart.newClientsGrowth',
                              "Yangi mijozlar")),
                      const SizedBox(height: 8),
                      ShadCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: SizedBox(
                          height: 180,
                          child: _NewClientsChart(daily: s.daily),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),
              ShadSectionLabel(tr(ref, 'mobile.shop.dashboard.navManagement',
                  "BOSHQARUV")),
              const SizedBox(height: 8),
              ShadTileGroup(children: [
                ShadTile(
                    icon: Icons.people_alt_outlined,
                    label: tr(ref, 'mobile.shop.dashboard.navMasters',
                        "Mastera (Barberlar)"),
                    onTap: () => context.go('/shop?tab=1')),
                ShadTile(
                    icon: Icons.event_note_outlined,
                    label: tr(ref, 'mobile.shop.dashboard.navBookings',
                        "Salon bronlari"),
                    onTap: () => context.go('/shop?tab=2')),
                ShadTile(
                    icon: Icons.people_outline,
                    label: tr(ref, 'shop.nav.clients', "Mijozlar"),
                    onTap: () => context.push('/shop/clients')),
                ShadTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: tr(ref, 'mobile.shop.dashboard.navTransactions',
                        "Hisob va to'lovlar"),
                    onTap: () => context.push('/shop/transactions')),
                ShadTile(
                    icon: Icons.sms_outlined,
                    label: tr(ref, 'mobile.shop.dashboard.navSms',
                        "SMS tarixi"),
                    onTap: () => context.push('/shop/sms')),
                ShadTile(
                    icon: Icons.storefront_outlined,
                    label: tr(ref, 'profile.barberProfile', "Salon profili"),
                    onTap: () => context.push('/shop/profile')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiGrid(List<_Kpi> items) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: items
          .map((k) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: k.onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: k.color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(k.icon, color: k.color, size: 20),
                      const Spacer(),
                      Text(k.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(k.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textBright,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 220.ms))
          .toList(),
    );
  }
}

class _Kpi {
  _Kpi(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color,
      this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textBright,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _TodayCashCard extends ConsumerWidget {
  const _TodayCashCard({required this.stats});
  final ShopStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.decimalPattern('ru_RU');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.25),
            AppColors.success.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  tr(ref, 'mobile.shop.dashboard.todayCashLabel',
                      "BUGUNGI TUSHUM"),
                  style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                  "${fmt.format(stats.todayRevenue)} ${tr(ref, 'common.currency', "so'm")}",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright)),
              const SizedBox(height: 4),
              Text(
                  tr(ref, 'mobile.shop.dashboard.todayBreakdown',
                      "{{c}} yakunlangan · {{t}} jami buyurtma", {
                    'c': '${stats.todayCompleted}',
                    't': '${stats.todayBookings}',
                  }),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child:
              const Icon(Icons.account_balance_wallet, color: AppColors.success),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 20),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: AppColors.textBright,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3)),
    ]);
  }
}

class _BookingsChart extends StatelessWidget {
  const _BookingsChart({required this.daily});
  final List<ShopDailyPoint> daily;
  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      spots.add(FlSpot(i.toDouble(), daily[i].bookings.toDouble()));
    }
    final maxY = spots.fold<double>(
        0, (m, s) => s.y > m ? s.y : m);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY < 4 ? 4 : maxY).toDouble() + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted))),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (daily.length / 6).clamp(1, 30).toDouble(),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= daily.length) return const SizedBox.shrink();
                final d = daily[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(d.length >= 10 ? d.substring(5) : d,
                      style: const TextStyle(
                          fontSize: 9, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewClientsChart extends StatelessWidget {
  const _NewClientsChart({required this.daily});
  final List<ShopDailyPoint> daily;
  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < daily.length; i++) {
      spots.add(FlSpot(i.toDouble(), daily[i].newClients.toDouble()));
    }
    final maxY = spots.fold<double>(
        0, (m, s) => s.y > m ? s.y : m);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: (maxY < 3 ? 3 : maxY).toDouble() + 1,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted))),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.warning,
            barWidth: 2.5,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
