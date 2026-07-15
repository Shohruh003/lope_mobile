import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

class ShopDashboardScreen extends ConsumerStatefulWidget {
  const ShopDashboardScreen({super.key});
  @override
  ConsumerState<ShopDashboardScreen> createState() =>
      _ShopDashboardScreenState();
}

class _ShopDashboardScreenState extends ConsumerState<ShopDashboardScreen> {
  // Locale-neutral number formatter (spaces as thousands separator
  // via the intl default), and an ISO formatter kept only for the
  // backend query params — never surfaced to the user (display uses
  // `_pretty`).
  static final _fmtNum = NumberFormat.decimalPattern();
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('dd.MM.yyyy');
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();

  Future<void> _pickFrom() async {
    AppHaptics.light();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: _from,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: _to,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    AppHaptics.light();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: _to,
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              me.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (m) {
                  final address = (m['address'] ?? '').toString();
                  return AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md + 2),
                    // Icon dropped at user request — cleaner typography-
                    // led card with an accent bar on the left instead of
                    // a boxed logo. Salon name is the hero, address sits
                    // underneath with a pin glyph for context.
                    child: IntrinsicHeight(
                      child: Row(children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(ref,
                                    'mobile.shop.dashboard.salonLabel',
                                    'Salonim'),
                                style: AppText.overline.copyWith(
                                    color: AppColors.primary,
                                    letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                (m['name'] ?? '').toString(),
                                style: AppText.titleLg.copyWith(
                                    fontSize: 18,
                                    height: 1.15,
                                    letterSpacing: -0.2),
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Row(children: [
                                  Icon(Icons.place_outlined,
                                      size: 13,
                                      color: context.colors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: AppText.caption,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
              AppSpacing.gapMd,
              Row(children: [
                Expanded(
                    child: _DatePill(
                        label: _pretty.format(_from),
                        onTap: _pickFrom)),
                AppSpacing.hGapSm,
                Text('—',
                    style: TextStyle(color: context.colors.textMuted)),
                AppSpacing.hGapSm,
                Expanded(
                    child: _DatePill(
                        label: _pretty.format(_to), onTap: _pickTo)),
              ]),
              AppSpacing.gapLg,
              stats.when(
                loading: () => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SkeletonRect(height: 120, radius: AppRadius.xl),
                    SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                    ]),
                    SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                    ]),
                  ],
                ),
                error: (e, _) => SizedBox(
                  height: 320,
                  child: AppErrorState(
                    message: humanize(e),
                    onRetry: () =>
                        ref.invalidate(shopStatsFilteredProvider),
                  ),
                ),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TodayCashCard(stats: s),
                    AppSpacing.gapLg,
                    _kpiGrid([
                      _Kpi(
                        icon: Icons.event_available,
                        label: tr(ref, 'shop.stats.bookings', 'Bronlar'),
                        value: _fmtNum.format(s.bookings),
                        color: AppColors.primary,
                      ),
                      _Kpi(
                        icon: Icons.attach_money,
                        label: tr(ref, 'shop.stats.revenue', 'Daromad'),
                        value:
                            "${_fmtNum.format(s.revenue)} ${tr(ref, 'common.currency', "so'm")}",
                        color: AppColors.success,
                      ),
                      _Kpi(
                        icon: Icons.people_outline,
                        label: tr(ref, 'shop.stats.uniqueClients',
                            'Mijozlar'),
                        value: _fmtNum.format(s.uniqueClients),
                        color: const Color(0xFF8B5CF6),
                      ),
                      _Kpi(
                        icon: Icons.person_add_outlined,
                        label: tr(ref, 'shop.stats.newClients',
                            'Yangi mijozlar'),
                        value: _fmtNum.format(s.newClients),
                        color: AppColors.warning,
                      ),
                    ]),
                    AppSpacing.gapMd,
                    _kpiGrid([
                      _Kpi(
                        icon: Icons.content_cut,
                        label:
                            tr(ref, 'shop.nav.barbers', 'Masterlar'),
                        value:
                            "${s.barbersCount} ${tr(ref, 'common.pcs', 'ta')}",
                        color: AppColors.primary,
                        onTap: () => context.go('/shop?tab=1'),
                      ),
                      _Kpi(
                        icon: Icons.notifications_active_outlined,
                        label: tr(ref, 'shop.stats.dueForReminder',
                            'Eslatma kutilmoqda'),
                        value:
                            "${s.clientsDueForReminder} ${tr(ref, 'common.pcs', 'ta')}",
                        color: const Color(0xFFF97316),
                        onTap: () => context.push('/shop/reminders'),
                      ),
                      _Kpi(
                        icon: Icons.sms_outlined,
                        label: tr(
                            ref, 'shop.stats.smsSent', 'SMS yuborildi'),
                        value:
                            "${s.messages} ${tr(ref, 'common.pcs', 'ta')}",
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.push('/shop/sms'),
                      ),
                      _Kpi(
                        icon: Icons.trending_up,
                        label: tr(ref, 'shop.stats.fromSms', "SMS'dan"),
                        value:
                            "${s.fromSmsBookings} ${tr(ref, 'common.pcs', 'ta')}",
                        color: AppColors.success,
                        onTap: () => context.push('/shop/sms'),
                      ),
                    ]),
                    if (s.daily.isNotEmpty) ...[
                      AppSpacing.gapXl,
                      _SectionTitle(
                          icon: Icons.trending_up,
                          label: tr(
                              ref,
                              'shop.chart.bookingsOverTime',
                              "Bronlar vaqt bo'yicha")),
                      AppSpacing.gapSm,
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: SizedBox(
                          height: 200,
                          child: _BookingsChart(daily: s.daily),
                        ),
                      ),
                      AppSpacing.gapMd,
                      _SectionTitle(
                          icon: Icons.person_add,
                          label: tr(ref,
                              'shop.chart.newClientsGrowth',
                              'Yangi mijozlar')),
                      AppSpacing.gapSm,
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.sm,
                        ),
                        child: SizedBox(
                          height: 180,
                          child: _NewClientsChart(daily: s.daily),
                        ),
                      ),
                    ],

                    // Top masters — mirrors web dashboard's "topBarbers"
                    // section. Each row is tappable and drills into the
                    // barber's detail screen.
                    if (s.topBarbers.isNotEmpty) ...[
                      AppSpacing.gapXl,
                      _SectionTitle(
                          icon: Icons.content_cut,
                          label: tr(ref, 'shop.chart.topBarbers',
                              'Eng yaxshi masterlar')),
                      AppSpacing.gapSm,
                      _TopBarbersCard(
                        barbers: s.topBarbers.take(6).toList(),
                        currency: tr(ref, 'common.currency', "so'm"),
                        pcs: tr(ref, 'common.pcs', 'ta'),
                      ),
                    ],

                    // SMS breakdown (Tasdiqlash / Eslatma / Qaytarish) —
                    // three horizontal bars normalized against the
                    // largest bucket. Matches the web BarChart shape.
                    if ((s.smsConfirmation +
                            s.smsReminder +
                            s.smsRetention) >
                        0) ...[
                      AppSpacing.gapXl,
                      _SectionTitle(
                          icon: Icons.sms_outlined,
                          label: tr(ref, 'shop.chart.smsBreakdown',
                              "SMS turlari bo'yicha")),
                      AppSpacing.gapSm,
                      _SmsBreakdownCard(
                        confirmation: s.smsConfirmation,
                        reminder: s.smsReminder,
                        retention: s.smsRetention,
                        labels: (
                          confirmation: tr(ref,
                              'shop.smsTypes.confirmation', 'Tasdiqlash'),
                          reminder: tr(ref, 'shop.smsTypes.reminder',
                              'Eslatma'),
                          retention: tr(ref, 'shop.smsTypes.retention',
                              'Qaytarish'),
                        ),
                        pcs: tr(ref, 'common.pcs', 'ta'),
                      ),
                    ],

                    // Booking sources — Manual / SMS'dan / Ilova.
                    // Client-side derives 'app' = bookings − manual −
                    // fromSms (same math as the web dashboard).
                    if (s.bookings > 0) ...[
                      AppSpacing.gapXl,
                      _SectionTitle(
                          icon: Icons.pie_chart_outline,
                          label: tr(ref, 'shop.chart.bookingSources',
                              'Bronlar manbai')),
                      AppSpacing.gapSm,
                      _BookingSourcesCard(
                        manual: s.manualBookings,
                        fromSms: s.fromSmsBookings,
                        total: s.bookings,
                        labels: (
                          manual: tr(ref, 'shop.stats.manual', "Qo'lda"),
                          fromSms: tr(ref, 'shop.stats.fromSms',
                              "SMS'dan"),
                          app: tr(ref, 'shop.stats.app', 'Ilova'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Removed the "BOSHQARUV" duplicate nav card — every
              // link here also lives in the side drawer, so keeping
              // both was just clutter. Drawer now owns navigation.
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
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.65,
      children: items
          .map((k) => TapScale(
                onTap: k.onTap,
                scale: 0.97,
                child: Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.rLg,
                    border: Border.all(
                      color: k.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: k.color.withValues(alpha: 0.15),
                          borderRadius: AppRadius.rSm,
                        ),
                        child:
                            Icon(k.icon, color: k.color, size: 18),
                      ),
                      const Spacer(),
                      Text(
                        k.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        k.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleMd.copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 220.ms))
          .toList(),
    );
  }
}

class _Kpi {
  _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
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
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined,
              size: 16, color: context.colors.textMuted),
          AppSpacing.hGapSm,
          Text(label, style: AppText.body),
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
    final fmt = NumberFormat.decimalPattern();
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.35),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.shop.dashboard.todayCashLabel',
                    'BUGUNGI TUSHUM'),
                style: AppText.overline.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${fmt.format(stats.todayRevenue)} ${tr(ref, 'common.currency', "so'm")}",
                style: AppText.display.copyWith(
                  color: Colors.white,
                  fontSize: 30,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  ref,
                  'mobile.shop.dashboard.todayBreakdown',
                  '{{c}} yakunlangan · {{t}} jami buyurtma',
                  {
                    'c': '${stats.todayCompleted}',
                    't': '${stats.todayBookings}',
                  },
                ),
                style: AppText.bodySm.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: AppRadius.rLg,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 26),
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
      Icon(icon, color: AppColors.primary, size: 18),
      AppSpacing.hGapSm,
      Text(label, style: AppText.titleSm),
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
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
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
                  style: TextStyle(
                      fontSize: 10, color: context.colors.textMuted)),
            ),
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
                      style: TextStyle(
                          fontSize: 9, color: context.colors.textMuted)),
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
    final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
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
                  style: TextStyle(
                      fontSize: 10, color: context.colors.textMuted)),
            ),
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

/// Ranked list of masters with an inline progress bar per row. Width
/// is proportional to `bookings / topRow.bookings`, so the leader is
/// always full-width. Tap drills into the barber detail screen.
class _TopBarbersCard extends StatelessWidget {
  const _TopBarbersCard({
    required this.barbers,
    required this.currency,
    required this.pcs,
  });
  final List<ShopTopBarber> barbers;
  final String currency;
  final String pcs;

  @override
  Widget build(BuildContext context) {
    final maxBookings = barbers.first.bookings <= 0 ? 1 : barbers.first.bookings;
    final fmt = NumberFormat.decimalPattern();
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Column(
        children: [
          for (var i = 0; i < barbers.length; i++)
            TapScale(
              onTap: () => context.push('/shop/barbers/${barbers[i].id}'),
              scale: 0.98,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xs + 2),
                child: Row(children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: AppText.button.copyWith(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  ClientAvatar(
                    name: barbers[i].name,
                    avatar: barbers[i].avatar,
                    size: 32,
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              barbers[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AppSpacing.hGapSm,
                          Text(
                            '${barbers[i].bookings} $pcs',
                            style: AppText.caption,
                          ),
                          AppSpacing.hGapSm,
                          Text(
                            "${fmt.format(barbers[i].revenue)} $currency",
                            style: AppText.button.copyWith(
                              color: AppColors.success,
                              fontSize: 12,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: barbers[i].bookings / maxBookings,
                            minHeight: 4,
                            backgroundColor: context.colors.border,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// 3-row breakdown of SMS types with horizontal progress bars.
class _SmsBreakdownCard extends StatelessWidget {
  const _SmsBreakdownCard({
    required this.confirmation,
    required this.reminder,
    required this.retention,
    required this.labels,
    required this.pcs,
  });
  final int confirmation;
  final int reminder;
  final int retention;
  final ({String confirmation, String reminder, String retention}) labels;
  final String pcs;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        label: labels.confirmation,
        count: confirmation,
        color: const Color(0xFF3B82F6),
      ),
      (
        label: labels.reminder,
        count: reminder,
        color: const Color(0xFFF97316),
      ),
      (
        label: labels.retention,
        count: retention,
        color: const Color(0xFFA855F7),
      ),
    ];
    final maxCount = rows.map((r) => r.count).fold<int>(0, (a, b) => a > b ? a : b);
    final denom = maxCount == 0 ? 1 : maxCount;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: rows[i].color,
                  shape: BoxShape.circle,
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(rows[i].label, style: AppText.bodySm),
              ),
              Text('${rows[i].count} $pcs',
                  style: AppText.button.copyWith(fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: rows[i].count / denom,
                minHeight: 4,
                backgroundColor: context.colors.border,
                valueColor: AlwaysStoppedAnimation(rows[i].color),
              ),
            ),
            if (i < rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Booking sources — Qo'lda / SMS'dan / Ilova, one column per bucket
/// with an amount, percentage, and horizontal bar.
class _BookingSourcesCard extends StatelessWidget {
  const _BookingSourcesCard({
    required this.manual,
    required this.fromSms,
    required this.total,
    required this.labels,
  });
  final int manual;
  final int fromSms;
  final int total;
  final ({String manual, String fromSms, String app}) labels;

  @override
  Widget build(BuildContext context) {
    final app = (total - manual - fromSms).clamp(0, total);
    final cols = [
      (label: labels.manual, count: manual, color: const Color(0xFF3B82F6)),
      (label: labels.fromSms, count: fromSms, color: const Color(0xFFA855F7)),
      (label: labels.app, count: app, color: AppColors.success),
    ];
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cols.length; i++) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cols[i].label,
                      style: AppText.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${cols[i].count}',
                    style: AppText.titleMd.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : cols[i].count / total,
                      minHeight: 4,
                      backgroundColor: context.colors.border,
                      valueColor: AlwaysStoppedAnimation(cols[i].color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${total == 0 ? 0 : ((cols[i].count / total) * 100).round()}%',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            if (i < cols.length - 1) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
