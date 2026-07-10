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
  static final _fmtNum = NumberFormat.decimalPattern('ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  late DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _to = DateTime.now();

  Future<void> _pickFrom() async {
    AppHaptics.light();
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: _to,
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    AppHaptics.light();
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
                data: (m) => AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.rSm,
                        boxShadow:
                            AppShadows.primaryGlow(AppColors.primary),
                      ),
                      child: const Icon(Icons.storefront_outlined,
                          color: Colors.white, size: 22),
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
                            style: AppText.overline,
                          ),
                          const SizedBox(height: 2),
                          Text((m['name'] ?? '').toString(),
                              style: AppText.titleMd),
                          if ((m['address'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text((m['address']).toString(),
                                style: AppText.caption),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              AppSpacing.gapMd,
              Row(children: [
                Expanded(
                    child: _DatePill(
                        label: _ymd.format(_from), onTap: _pickFrom)),
                AppSpacing.hGapSm,
                const Text('—',
                    style: TextStyle(color: AppColors.textMuted)),
                AppSpacing.hGapSm,
                Expanded(
                    child: _DatePill(
                        label: _ymd.format(_to), onTap: _pickTo)),
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
                  ],
                ),
              ),
              AppSpacing.gapXl,
              Text(
                tr(ref, 'mobile.shop.dashboard.navManagement',
                    'BOSHQARUV'),
                style: AppText.overline,
              ),
              AppSpacing.gapSm,
              AppCard(
                variant: AppCardVariant.outlined,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  _NavTile(
                    icon: Icons.people_alt_outlined,
                    color: AppColors.primary,
                    label: tr(ref, 'mobile.shop.dashboard.navMasters',
                        'Mastera (Barberlar)'),
                    onTap: () => context.go('/shop?tab=1'),
                  ),
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.md,
                  ),
                  _NavTile(
                    icon: Icons.event_note_outlined,
                    color: AppColors.warning,
                    label: tr(ref, 'mobile.shop.dashboard.navBookings',
                        'Salon bronlari'),
                    onTap: () => context.go('/shop?tab=2'),
                  ),
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.md,
                  ),
                  _NavTile(
                    icon: Icons.people_outline,
                    color: AppColors.success,
                    label: tr(ref, 'shop.nav.clients', 'Mijozlar'),
                    onTap: () => context.push('/shop/clients'),
                  ),
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.md,
                  ),
                  _NavTile(
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                    label: tr(ref,
                        'mobile.shop.dashboard.navTransactions',
                        "Hisob va to'lovlar"),
                    onTap: () => context.push('/shop/transactions'),
                  ),
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.md,
                  ),
                  _NavTile(
                    icon: Icons.sms_outlined,
                    color: AppColors.primary,
                    label: tr(ref, 'mobile.shop.dashboard.navSms',
                        'SMS tarixi'),
                    onTap: () => context.push('/shop/sms'),
                  ),
                  const Divider(
                    color: AppColors.border,
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.md,
                  ),
                  _NavTile(
                    icon: Icons.storefront_outlined,
                    color: AppColors.primary,
                    label: tr(ref, 'profile.barberProfile',
                        'Salon profili'),
                    onTap: () => context.push('/shop/profile'),
                  ),
                ]),
              ),
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
                    color: AppColors.surface,
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
          color: AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              size: 16, color: AppColors.textMuted),
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
    final fmt = NumberFormat.decimalPattern('ru_RU');
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textBright,
              ),
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
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
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
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
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
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
