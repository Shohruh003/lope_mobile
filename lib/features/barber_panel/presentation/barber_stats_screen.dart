import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/stat_charts.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

class BarberStatsScreen extends ConsumerWidget {
  const BarberStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberAllBookingsProvider(barberId));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.refresh(barberAllBookingsProvider(barberId).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
            children: [
              Text(
                tr(ref, 'mobile.barber.stats.title', 'Statistika'),
                style: AppText.titleLg,
              ),
              AppSpacing.gapLg,
              async.when(
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Row(children: [
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                          child: SkeletonRect(
                              height: 96, radius: AppRadius.md)),
                    ]),
                    SizedBox(height: AppSpacing.md),
                    SkeletonRect(height: 220, radius: AppRadius.md),
                    SizedBox(height: AppSpacing.md),
                    SkeletonRect(height: 220, radius: AppRadius.md),
                  ],
                ),
                error: (e, _) => SizedBox(
                  height: 320,
                  child: AppErrorState(
                    message: humanize(e),
                    onRetry: () => ref
                        .invalidate(barberAllBookingsProvider(barberId)),
                  ),
                ),
                data: (list) {
                  final now = DateTime.now();
                  final weekAgo = now.subtract(const Duration(days: 7));
                  final monthAgo =
                      DateTime(now.year, now.month - 1, now.day);

                  int weekCount = 0, monthCount = 0, totalRev = 0;
                  int weekRev = 0, monthRev = 0;
                  int confirmedCount = 0,
                      completedCount = 0,
                      cancelledCount = 0;
                  final serviceAgg =
                      <String, ({String name, int count, int revenue})>{};
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
                      byDow[d.weekday - 1]++;
                    }
                    if (d.isAfter(monthAgo)) {
                      monthCount++;
                      monthRev += b.totalPrice;
                    }
                  }
                  final topServices = serviceAgg.values.toList()
                    ..sort((a, b) => b.count.compareTo(a.count));

                  final todayStr =
                      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                  final todayCount = list
                      .where((b) =>
                          b.date == todayStr && b.status != 'cancelled')
                      .length;
                  // Fall back to the booking's own id when neither the
                  // client phone nor a name is set — otherwise several
                  // anonymous guest bookings all collapse into a single
                  // "Mijoz" entry and the unique-clients count is wrong.
                  final uniqueClients = list
                      .where((b) => b.status != 'cancelled')
                      .map((b) {
                        final phone = b.userPhone ?? b.guestPhone;
                        if (phone != null && phone.isNotEmpty) return phone;
                        if (b.userName.isNotEmpty &&
                            b.userName.toLowerCase() != 'mijoz') {
                          return b.userName;
                        }
                        return 'guest:${b.id}';
                      })
                      .toSet()
                      .length;

                  return Column(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        // Tighter ratios ("1.6" and up) clipped the tile
                        // content by ~4-6px on medium Android phones
                        // (icon + value + label + card padding wouldn't
                        // fit). Give the tile a bit more vertical room.
                        childAspectRatio: 1.35,
                        children: [
                          _StatTile(
                            icon: Icons.event_available,
                            label: tr(
                                ref,
                                'mobile.barber.stats.todayBookings',
                                'Bugungi bronlar'),
                            value: '$todayCount',
                            color: const Color(0xFF3B82F6),
                          ),
                          _StatTile(
                            icon: Icons.trending_up,
                            label: tr(ref,
                                'mobile.barber.stats.month', 'Bu oy'),
                            value: '$monthCount',
                            color: AppColors.success,
                          ),
                          _StatTile(
                            icon: Icons.people_outline,
                            label: tr(
                                ref,
                                'mobile.barber.stats.totalClients',
                                'Jami mijozlar'),
                            value: '$uniqueClients',
                            color: const Color(0xFFA855F7),
                          ),
                          _StatTile(
                            icon: Icons.attach_money,
                            label: tr(
                                ref,
                                'mobile.barber.stats.monthRevenue',
                                'Bu oy daromad'),
                            value:
                                "${_fmt(monthRev)} ${tr(ref, 'common.currency', "so'm")}",
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                      AppSpacing.gapMd,
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.xs,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                  ref,
                                  'mobile.barber.stats.weeklyBookings',
                                  'Haftalik bronlar'),
                              style: AppText.titleSm,
                            ),
                            AppSpacing.gapSm,
                            WeeklyBookingsBarChart(
                              counts: byDow,
                              dayLabels: trList(
                                  ref,
                                  'mobile.dates.weekDaysShort',
                                  const [
                                    'Du',
                                    'Se',
                                    'Ch',
                                    'Pa',
                                    'Ju',
                                    'Sh',
                                    'Ya'
                                  ]),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapMd,
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: AppSpacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(ref, 'mobile.barber.stats.summary',
                                  'Umumiy hisob'),
                              style: AppText.titleSm,
                            ),
                            AppSpacing.gapSm,
                            _SummaryRow(
                              label: tr(ref,
                                  'mobile.barber.stats.week', 'Bu hafta'),
                              value:
                                  "$weekCount ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')} В· ${_fmt(weekRev)} ${tr(ref, 'common.currency', "so'm")}",
                            ),
                            Divider(
                                color: context.colors.border, height: 14),
                            _SummaryRow(
                              label: tr(
                                  ref,
                                  'mobile.barber.stats.totalBookings',
                                  'Jami bronlar'),
                              value:
                                  "${list.length} ${tr(ref, 'mobile.barber.stats.countSuffix', 'ta')}",
                            ),
                            Divider(
                                color: context.colors.border, height: 14),
                            _SummaryRow(
                              label: tr(ref,
                                  'mobile.barber.stats.total',
                                  'Jami daromad'),
                              value:
                                  "${_fmt(totalRev)} ${tr(ref, 'common.currency', "so'm")}",
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapMd,
                      AppCard(
                        variant: AppCardVariant.outlined,
                        padding: AppSpacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(ref, 'barberApp.bookingsByStatus',
                                  "Bronlar holati bo'yicha"),
                              style: AppText.titleSm,
                            ),
                            AppSpacing.gapMd,
                            _StatusRow(
                              color: const Color(0xFF3B82F6),
                              label: tr(ref, 'status.confirmed',
                                  'Tasdiqlangan'),
                              count: confirmedCount,
                            ),
                            AppSpacing.gapSm,
                            _StatusRow(
                              color: AppColors.success,
                              label: tr(ref, 'status.completed',
                                  'Yakunlangan'),
                              count: completedCount,
                            ),
                            AppSpacing.gapSm,
                            _StatusRow(
                              color: AppColors.danger,
                              label: tr(ref, 'status.cancelled',
                                  'Bekor qilingan'),
                              count: cancelledCount,
                            ),
                          ],
                        ),
                      ),
                      if (topServices.isNotEmpty) ...[
                        AppSpacing.gapMd,
                        AppCard(
                          variant: AppCardVariant.outlined,
                          padding: AppSpacing.cardPadding,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                    ref,
                                    'barberApp.topServices',
                                    "Eng ko'p so'ralgan xizmatlar"),
                                style: AppText.titleSm,
                              ),
                              AppSpacing.gapMd,
                              ...topServices
                                  .take(5)
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.only(
                                            bottom: AppSpacing.sm),
                                        child: _TopServiceRow(
                                          rank: e.key + 1,
                                          name: e.value.name,
                                          count: e.value.count,
                                          revenue: e.value.revenue,
                                          currency: tr(ref,
                                              'common.currency', "so'm"),
                                          fmt: _fmt,
                                        ),
                                      )),
                            ],
                          ),
                        ),
                      ],
                      AppSpacing.gapMd,
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
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.titleMd.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(label, style: AppText.caption),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: AppText.bodySm),
        ),
        AppSpacing.hGapSm,
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppText.body.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.color,
    required this.label,
    required this.count,
  });
  final Color color;
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 6,
            ),
          ],
        ),
      ),
      AppSpacing.hGapSm,
      Expanded(child: Text(label, style: AppText.body)),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: context.colors.border),
        ),
        child: Text('$count',
            style: AppText.caption.copyWith(
              color: context.colors.textBright,
              fontWeight: FontWeight.w800,
            )),
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
        width: 24,
        child: Text(
          '#$rank',
          style: AppText.caption.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            color: context.colors.textMuted,
          ),
        ),
      ),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body,
        ),
      ),
      AppSpacing.hGapSm,
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          '${count}x',
          style: AppText.caption.copyWith(
            color: context.colors.textBright,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      AppSpacing.hGapSm,
      Text(
        '${fmt(revenue)} $currency',
        style: AppText.caption,
      ),
    ]);
  }
}

class _SmsStatsCard extends ConsumerStatefulWidget {
  const _SmsStatsCard({required this.barberId});
  final String barberId;
  @override
  ConsumerState<_SmsStatsCard> createState() => _SmsStatsCardState();
}

class _SmsStatsCardState extends ConsumerState<_SmsStatsCard> {
  DateTime? _from;
  DateTime? _to;

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDate(bool isFrom) async {
    AppHaptics.light();
    final now = DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

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
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final effFrom = _from ?? firstOfMonth;
    final effTo = _to ?? DateTime(now.year, now.month, now.day);
    final customRange =
        _from != null || (_to != null && _to!.day != now.day);
    final async = ref.watch(barberSmsStatsProvider(
        (barberId: widget.barberId, from: _ymd(effFrom), to: _ymd(effTo))));

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: AppRadius.rSm,
              ),
              child: const Icon(Icons.sms_outlined,
                  size: 18, color: AppColors.primary),
            ),
            AppSpacing.hGapSm,
            Text(tr(ref, 'mobile.barber.stats.smsTitle', 'SMS xizmat'),
                style: AppText.titleSm),
          ]),
          AppSpacing.gapSm,
          Row(children: [
            Expanded(
              child: _MiniDate(
                label: _dmy(effFrom),
                onTap: () => _pickDate(true),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child:
                  Text('—', style: TextStyle(color: context.colors.textMuted)),
            ),
            Expanded(
              child: _MiniDate(
                label: _dmy(effTo),
                onTap: () => _pickDate(false),
              ),
            ),
            if (customRange) ...[
              AppSpacing.hGapXs,
              TapScale(
                onTap: () => setState(() {
                  _from = null;
                  _to = null;
                }),
                scale: 0.85,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close,
                      size: 14, color: context.colors.textMuted),
                ),
              ),
            ],
          ]),
          AppSpacing.gapSm,
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}",
                style: AppText.caption,
              ),
            ),
            data: (s) => Column(
              children: [
                _SummaryRow(
                  label: tr(ref, 'mobile.barber.stats.smsTotal', 'Jami SMS'),
                  value:
                      "${s.totalSent} В· ${_fmt(s.totalCost)} ${tr(ref, 'common.currency', "so'm")}",
                ),
                Divider(color: context.colors.border, height: 14),
                _SummaryRow(
                  label: tr(ref, 'mobile.barber.stats.smsConfirmation',
                      'Tasdiqlash'),
                  value:
                      "${s.confirmationRegistered + s.confirmationGuest} В· ${_fmt(s.confirmationRegisteredCost + s.confirmationGuestCost)} ${tr(ref, 'common.currency', "so'm")}",
                ),
                Divider(color: context.colors.border, height: 14),
                _SummaryRow(
                  label: tr(ref, 'mobile.barber.stats.smsReminder',
                      'Eslatma'),
                  value:
                      "${s.reminderCount} В· ${_fmt(s.reminderCost)} ${tr(ref, 'common.currency', "so'm")}",
                ),
                Divider(color: context.colors.border, height: 14),
                _SummaryRow(
                  label: tr(ref, 'mobile.barber.stats.smsRetention',
                      'Reklama'),
                  value:
                      "${s.retentionCount} В· ${_fmt(s.retentionCost)} ${tr(ref, 'common.currency', "so'm")}",
                ),
                if (s.returnedClients > 0) ...[
                  Divider(color: context.colors.border, height: 14),
                  _SummaryRow(
                    label: tr(ref, 'mobile.barber.stats.smsReturned',
                        'Qaytib kelganlar'),
                    value: '${s.returnedClients}',
                  ),
                  if (s.totalSent > 0) ...[
                    Divider(color: context.colors.border, height: 14),
                    _SummaryRow(
                      label: tr(ref, 'mobile.barber.stats.smsConversion',
                          'Konversiya'),
                      value:
                          "${((s.returnedClients / s.totalSent) * 100).round()}%",
                    ),
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

class _MiniDate extends StatelessWidget {
  const _MiniDate({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 12, color: context.colors.textMuted),
          AppSpacing.hGapXs,
          Expanded(child: Text(label, style: AppText.caption)),
        ]),
      ),
    );
  }
}
