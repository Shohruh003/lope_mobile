import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart'
    show BarberBookingActions, barberPanelRepositoryProvider;

class ScheduleGeneratorScreen extends ConsumerStatefulWidget {
  const ScheduleGeneratorScreen({super.key, this.initialDate});

  /// Optional pre-selected date passed via `?date=YYYY-MM-DD` from the
  /// schedule screen. When set, the generator defaults `_from` and
  /// `_to` to this single day — matches the barber's mental model
  /// where they tap "Jadval qo'shish → Avtomatik" on a specific date
  /// and expect the schedule to cover only that day (previously the
  /// default was today→today+7, silently creating a week's worth).
  final DateTime? initialDate;

  @override
  ConsumerState<ScheduleGeneratorScreen> createState() =>
      _ScheduleGeneratorScreenState();
}

class _ScheduleGeneratorScreenState
    extends ConsumerState<ScheduleGeneratorScreen> {
  late DateTime _from = widget.initialDate ?? DateTime.now();
  late DateTime _to = widget.initialDate ??
      DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dayStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _dayEnd = const TimeOfDay(hour: 20, minute: 0);
  int _slotMinutes = 30;
  bool _lunchEnabled = true;
  TimeOfDay _lunchStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _lunchEnd = const TimeOfDay(hour: 14, minute: 0);
  bool _busy = false;

  /// ISO string sent to the backend (unchanged shape).
  String _d(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static const _monthsUz = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];

  /// Humanized label shown on the date-range picker cards. Uses
  /// "Bugun / Ertaga / 11 iyl" so the barber can read the range at a
  /// glance instead of parsing a raw ISO string.
  String _dLabel(DateTime d, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.tomorrow', 'Ertaga');
    final month = _monthsUz[d.month - 1];
    // Include year when the target is in a different calendar year.
    if (d.year != now.year) return '${d.day} $month ${d.year}';
    return '${d.day} $month';
  }

  String _t(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<void> _pickDate(bool start) async {
    AppHaptics.light();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: start ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => start ? _from = picked : _to = picked);
    }
  }

  Future<void> _pickTime(int which) async {
    AppHaptics.light();
    final initial = switch (which) {
      0 => _dayStart,
      1 => _dayEnd,
      2 => _lunchStart,
      _ => _lunchEnd,
    };
    final picked =
        await AppTimePicker.show(context, ref: ref, initial: initial);
    if (picked == null) return;
    setState(() {
      switch (which) {
        case 0:
          _dayStart = picked;
          break;
        case 1:
          _dayEnd = picked;
          break;
        case 2:
          _lunchStart = picked;
          break;
        case 3:
          _lunchEnd = picked;
          break;
      }
    });
  }

  Future<void> _generate() async {
    AppHaptics.medium();
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (_to.isBefore(_from)) {
      AppHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.scheduleGen.invalidRange',
              "Sana oralig'i noto'g'ri"))));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(barberPanelRepositoryProvider).generateSchedule(
            barberId: user.id,
            dateFrom: _d(_from),
            dateTo: _d(_to),
            dayStart: _t(_dayStart),
            dayEnd: _t(_dayEnd),
            slotMinutes: _slotMinutes,
            lunchStart: _lunchEnabled ? _t(_lunchStart) : null,
            lunchEnd: _lunchEnabled ? _t(_lunchEnd) : null,
          );
      if (mounted) {
        AppHaptics.success();
        // Pop with `true` so the schedule screen can invalidate its
        // slot provider immediately — the previous flow relied on the
        // provider auto-refreshing, which felt like the schedule
        // "appeared late" after the snackbar.
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _to.difference(_from).inDays + 1;
    final slotsPerDay = _approxSlotsPerDay();
    final total = (dayCount > 0 ? dayCount : 1) * slotsPerDay;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.scheduleGen.title', 'Avtomatik jadval'),
          style: AppText.titleMd,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          _SectionTitle(
            icon: Icons.calendar_month,
            title: tr(ref, 'mobile.barber.scheduleGen.dateRange',
                "Sana oralig'i"),
          ),
          AppSpacing.gapMd,
          Row(children: [
            Expanded(
              child: _Picker(
                icon: Icons.calendar_today,
                label: tr(ref, 'mobile.barber.scheduleGen.start',
                    'Boshlanish'),
                value: _dLabel(_from, ref),
                onTap: () => _pickDate(true),
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: _Picker(
                icon: Icons.event,
                label: tr(
                    ref, 'mobile.barber.scheduleGen.end', 'Tugash'),
                value: _dLabel(_to, ref),
                onTap: () => _pickDate(false),
              ),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionTitle(
            icon: Icons.access_time,
            title: tr(ref, 'profile.workingHours', 'Ish soatlari'),
          ),
          AppSpacing.gapMd,
          Row(children: [
            Expanded(
              child: _Picker(
                icon: Icons.wb_sunny_outlined,
                label: tr(ref, 'profile.openTime', 'Ochilish'),
                value: _t(_dayStart),
                onTap: () => _pickTime(0),
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: _Picker(
                icon: Icons.nightlight_outlined,
                label: tr(ref, 'profile.closeTime', 'Yopilish'),
                value: _t(_dayEnd),
                onTap: () => _pickTime(1),
              ),
            ),
          ]),
          AppSpacing.gapXl,
          _SectionTitle(
            icon: Icons.timer,
            title: tr(ref, 'mobile.barber.scheduleGen.slotDuration',
                'Bir slot davomiyligi'),
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [15, 20, 30, 45, 60, 90]
                .map((m) => AppChip(
                      label:
                          "$m ${tr(ref, 'booking.duration', 'daq')}",
                      selected: _slotMinutes == m,
                      onTap: () => setState(() => _slotMinutes = m),
                    ))
                .toList(),
          ),
          AppSpacing.gapXl,
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadius.rSm,
                ),
                child: const Icon(Icons.restaurant_outlined,
                    color: AppColors.warning, size: 20),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  tr(ref, 'mobile.barber.scheduleGen.lunchBreak',
                      'Tushlik tanaffusi'),
                  style: AppText.titleSm,
                ),
              ),
              Switch(
                value: _lunchEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) {
                  AppHaptics.selection();
                  setState(() => _lunchEnabled = v);
                },
              ),
            ]),
          ),
          if (_lunchEnabled) ...[
            AppSpacing.gapSm,
            Row(children: [
              Expanded(
                child: _Picker(
                  icon: Icons.restaurant_outlined,
                  label: tr(ref, 'mobile.barber.scheduleGen.start',
                      'Boshlanish'),
                  value: _t(_lunchStart),
                  onTap: () => _pickTime(2),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: _Picker(
                  icon: Icons.restaurant,
                  label: tr(ref,
                      'mobile.barber.scheduleGen.end', 'Tugash'),
                  value: _t(_lunchEnd),
                  onTap: () => _pickTime(3),
                ),
              ),
            ]),
          ],
          AppSpacing.gapXl,
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            color: AppColors.primary.withValues(alpha: 0.08),
            borderColor: AppColors.primary.withValues(alpha: 0.3),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.rSm,
                ),
                child: const Icon(Icons.info_outline,
                    color: AppColors.primary, size: 22),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  tr(
                      ref,
                      'mobile.barber.scheduleGen.summary',
                      'Taxminan {{days}} kun × {{slots}} slot = {{total}} slot yaratiladi',
                      {
                        'days': '$dayCount',
                        'slots': '$slotsPerDay',
                        'total': '$total',
                      }),
                  style: AppText.bodySm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          AppSpacing.gapXl,
          AppButton(
            label: tr(ref, 'mobile.barber.scheduleGen.generate',
                'Jadval yaratish'),
            leadingIcon: Icons.event_available,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.lg,
            fullWidth: true,
            loading: _busy,
            onPressed: _busy ? null : _generate,
          ),
        ],
      ),
    );
  }

  int _approxSlotsPerDay() {
    final dayMin = _dayEnd.hour * 60 +
        _dayEnd.minute -
        (_dayStart.hour * 60 + _dayStart.minute);
    final lunchMin = _lunchEnabled
        ? (_lunchEnd.hour * 60 +
            _lunchEnd.minute -
            (_lunchStart.hour * 60 + _lunchStart.minute))
        : 0;
    final usable = dayMin - lunchMin;
    if (usable <= 0) return 0;
    return (usable / _slotMinutes).floor();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: context.colors.textBright),
      AppSpacing.hGapXs,
      Text(title, style: AppText.overline),
    ]);
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
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
          Icon(icon, color: AppColors.primary, size: 18),
          AppSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.colors.textBright,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
