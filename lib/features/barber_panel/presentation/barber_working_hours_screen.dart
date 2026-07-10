import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/barber_profile_repository.dart';

class BarberWorkingHoursScreen extends ConsumerStatefulWidget {
  const BarberWorkingHoursScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BarberWorkingHoursScreen> createState() =>
      _BarberWorkingHoursScreenState();
}

class _BarberWorkingHoursScreenState
    extends ConsumerState<BarberWorkingHoursScreen> {
  static const _days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];
  static const _slotOptions = [15, 20, 30, 45, 60, 90];

  late List<_DayConfig> _config;
  int _slotDuration = 30;
  bool _seeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = List.generate(
      7,
      (i) => _DayConfig(
          day: _dayKeys[i], open: '09:00', close: '20:00', isOpen: i < 6),
    );
  }

  void _seedFromBarber(Map<String, dynamic> barber) {
    if (_seeded) return;
    _seeded = true;
    final raw = barber['workingHours'];
    if (raw is Map) {
      for (var i = 0; i < _dayKeys.length; i++) {
        final v = raw[_dayKeys[i]];
        if (v is Map) {
          _config[i] = _DayConfig(
            day: _dayKeys[i],
            open: (v['open'] ?? v['start'] ?? '09:00').toString(),
            close: (v['close'] ?? v['end'] ?? '20:00').toString(),
            isOpen: v['isOpen'] == true || v['enabled'] == true,
          );
        }
      }
    } else if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final dk = item['day']?.toString();
        final idx = _dayKeys.indexOf(dk ?? '');
        if (idx >= 0) {
          _config[idx] = _DayConfig(
            day: _dayKeys[idx],
            open: (item['open'] ?? item['start'] ?? '09:00').toString(),
            close: (item['close'] ?? item['end'] ?? '20:00').toString(),
            isOpen: item['isOpen'] == true || item['enabled'] == true,
          );
        }
      }
    }
    final sd = barber['slotDuration'];
    if (sd is num) {
      final clamped = sd.toInt();
      _slotDuration = _slotOptions.contains(clamped) ? clamped : 30;
    }
  }

  Future<void> _pickTime(int i, bool isOpen) async {
    AppHaptics.light();
    final current = isOpen ? _config[i].open : _config[i].close;
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked =
        await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _config[i] = _config[i].copyWith(
          open: isOpen ? s : _config[i].open,
          close: isOpen ? _config[i].close : s);
    });
  }

  Future<void> _save() async {
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      final workingHours = <String, dynamic>{
        for (final d in _config)
          d.day: {'isOpen': d.isOpen, 'open': d.open, 'close': d.close}
      };
      await ref.read(barberProfileRepositoryProvider).updateBarber(
        widget.barberId,
        {
          'workingHours': workingHours,
          'slotDuration': _slotDuration,
        },
      );
      ref.invalidate(barberProfileProvider(widget.barberId));
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.hours.title', 'Ish soatlari'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (barber) {
          _seedFromBarber(barber);
          final days = trList(ref, 'mobile.dates.weekDaysShort', _days);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    color: _config[i].isOpen
                        ? null
                        : AppColors.surfaceElevated
                            .withValues(alpha: 0.4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            days[i],
                            style: AppText.titleSm.copyWith(
                              color: _config[i].isOpen
                                  ? AppColors.textBright
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        AppSpacing.hGapSm,
                        Expanded(
                          child: Row(
                            children: [
                              _TimeChip(
                                label: _config[i].open,
                                enabled: _config[i].isOpen,
                                onTap: () => _pickTime(i, true),
                              ),
                              AppSpacing.hGapXs,
                              const Text('—',
                                  style: TextStyle(
                                      color: AppColors.textMuted)),
                              AppSpacing.hGapXs,
                              _TimeChip(
                                label: _config[i].close,
                                enabled: _config[i].isOpen,
                                onTap: () => _pickTime(i, false),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _config[i].isOpen,
                          activeThumbColor: AppColors.primary,
                          onChanged: (v) {
                            AppHaptics.selection();
                            setState(() => _config[i] =
                                _config[i].copyWith(isOpen: v));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              AppSpacing.gapXl,
              AppCard(
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
                          color: AppColors.warning
                              .withValues(alpha: 0.15),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: const Icon(Icons.timer_outlined,
                            color: AppColors.warning, size: 18),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          tr(ref, 'profile.slotInterval',
                              "Slot oralig'i (daqiqa)"),
                          style: AppText.titleSm,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      tr(ref, 'profile.slotIntervalDescription',
                          'Mijozlar shu oraliqdan vaqt tanlaydi'),
                      style: AppText.bodySm,
                    ),
                    AppSpacing.gapMd,
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final d in _slotOptions)
                          AppChip(
                            label:
                                "$d ${tr(ref, 'profile.minutesShort', 'daq')}",
                            selected: _slotDuration == d,
                            onTap: () =>
                                setState(() => _slotDuration = d),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: tr(ref, 'mobile.common.save', 'Saqlash'),
                leadingIcon: Icons.check,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayConfig {
  final String day;
  final String open;
  final String close;
  final bool isOpen;
  const _DayConfig({
    required this.day,
    required this.open,
    required this.close,
    required this.isOpen,
  });
  _DayConfig copyWith(
          {String? day, String? open, String? close, bool? isOpen}) =>
      _DayConfig(
          day: day ?? this.day,
          open: open ?? this.open,
          close: close ?? this.close,
          isOpen: isOpen ?? this.isOpen);
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: enabled ? onTap : null,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceElevated,
          borderRadius: AppRadius.rSm,
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: enabled ? AppColors.primary : AppColors.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
