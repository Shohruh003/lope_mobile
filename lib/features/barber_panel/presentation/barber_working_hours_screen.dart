import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/barber_profile_repository.dart';

/// 7-day schedule + slot-duration picker.
///
/// Backend (PATCH /barbers/:id) expects:
///   workingHours: { monday: {isOpen, open, close}, ... sunday },
///   slotDuration: int in {15, 20, 30, 45, 60, 90}
///
/// The old payload {day, start, end, enabled} doesn't match anything the
/// backend writes — it silently no-op'd Prisma's update.
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
    // Backend stores workingHours as a Map<DayKey, {isOpen, open, close}>.
    // The legacy List<{day, start, end, enabled}> shape is still accepted
    // for older records — parse both.
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
    final current = isOpen ? _config[i].open : _config[i].close;
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
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
    setState(() => _saving = true);
    try {
      final workingHours = <String, dynamic>{
        for (final d in _config)
          d.day: {'isOpen': d.isOpen, 'open': d.open, 'close': d.close}
      };
      await ref.read(barberProfileRepositoryProvider).updateBarber(
          widget.barberId, {
        'workingHours': workingHours,
        'slotDuration': _slotDuration,
      });
      ref.invalidate(barberProfileProvider(widget.barberId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.barberId));
    return Scaffold(
      appBar:
          AppBar(title: Text(tr(ref, 'mobile.barber.hours.title', "Ish soatlari"))),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) =>
            AppErrorState(message: humanize(e)),
        data: (barber) {
          _seedFromBarber(barber);
          final days = trList(ref, 'mobile.dates.weekDaysShort', _days);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(days[i],
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _TimeChip(
                                label: _config[i].open,
                                enabled: _config[i].isOpen,
                                onTap: () => _pickTime(i, true)),
                            const SizedBox(width: 6),
                            const Text("—",
                                style: TextStyle(color: AppColors.textMuted)),
                            const SizedBox(width: 6),
                            _TimeChip(
                                label: _config[i].close,
                                enabled: _config[i].isOpen,
                                onTap: () => _pickTime(i, false)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _config[i].isOpen,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() =>
                            _config[i] = _config[i].copyWith(isOpen: v)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // ===== Slot duration picker (matches web 15/20/30/45/60/90) =====
              Text(
                  tr(ref, 'profile.slotInterval',
                      "Slot oralig'i (daqiqa)"),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textBright)),
              const SizedBox(height: 4),
              Text(
                  tr(ref, 'profile.slotIntervalDescription',
                      "Mijozlar shu oraliqdan vaqt tanlaydi"),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in _slotOptions)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _slotDuration = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _slotDuration == d
                            ? AppColors.primary
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _slotDuration == d
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                      child: Text(
                          "$d ${tr(ref, 'profile.minutesShort', 'daq')}",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _slotDuration == d
                                  ? Colors.white
                                  : AppColors.textBright)),
                    ),
                  ),
              ]),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'mobile.common.save', "Saqlash")),
                ),
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
  const _DayConfig(
      {required this.day,
      required this.open,
      required this.close,
      required this.isOpen});
  _DayConfig copyWith({String? day, String? open, String? close, bool? isOpen}) =>
      _DayConfig(
          day: day ?? this.day,
          open: open ?? this.open,
          close: close ?? this.close,
          isOpen: isOpen ?? this.isOpen);
}

class _TimeChip extends StatelessWidget {
  const _TimeChip(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: enabled ? AppColors.primary : AppColors.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    );
  }
}
