import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/barber_profile_repository.dart';

/// 7 day-of-week schedule. For each day: enabled, start, end. The web sends
/// `workingHours` as a list of {day, start, end, enabled} on PATCH /barbers/:id.
class BarberWorkingHoursScreen extends ConsumerStatefulWidget {
  const BarberWorkingHoursScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BarberWorkingHoursScreen> createState() => _BarberWorkingHoursScreenState();
}

class _BarberWorkingHoursScreenState extends ConsumerState<BarberWorkingHoursScreen> {
  static const _days = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  late List<_DayConfig> _config;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _config = List.generate(7, (i) => _DayConfig(day: _dayKeys[i], start: '09:00', end: '20:00', enabled: i < 6));
  }

  void _seedFromBarber(Map<String, dynamic> barber) {
    final raw = barber['workingHours'];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final dk = item['day']?.toString();
        final idx = _dayKeys.indexOf(dk ?? '');
        if (idx >= 0) {
          _config[idx] = _DayConfig(
            day: _dayKeys[idx],
            start: item['start']?.toString() ?? '09:00',
            end: item['end']?.toString() ?? '20:00',
            enabled: item['enabled'] == true,
          );
        }
      }
    }
  }

  Future<void> _pickTime(int i, bool isStart) async {
    final current = isStart ? _config[i].start : _config[i].end;
    final parts = current.split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _config[i] = _config[i].copyWith(start: isStart ? s : _config[i].start, end: isStart ? _config[i].end : s);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(widget.barberId, {
        'workingHours': _config
            .map((d) => {'day': d.day, 'start': d.start, 'end': d.end, 'enabled': d.enabled})
            .toList(),
      });
      ref.invalidate(barberProfileProvider(widget.barberId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.hours.title', "Ish soatlari"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (barber) {
          // One-time seed.
          if (_config.every((d) => d.start == '09:00' && d.end == '20:00')) {
            _seedFromBarber(barber);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (var i = 0; i < 7; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(_days[i],
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            _TimeChip(label: _config[i].start, enabled: _config[i].enabled, onTap: () => _pickTime(i, true)),
                            const SizedBox(width: 6),
                            const Text("—", style: TextStyle(color: AppColors.textMuted)),
                            const SizedBox(width: 6),
                            _TimeChip(label: _config[i].end, enabled: _config[i].enabled, onTap: () => _pickTime(i, false)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _config[i].enabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _config[i] = _config[i].copyWith(enabled: v)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
  final String start;
  final String end;
  final bool enabled;
  const _DayConfig({required this.day, required this.start, required this.end, required this.enabled});
  _DayConfig copyWith({String? day, String? start, String? end, bool? enabled}) =>
      _DayConfig(day: day ?? this.day, start: start ?? this.start, end: end ?? this.end, enabled: enabled ?? this.enabled);
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.enabled, required this.onTap});
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
          color: enabled ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: enabled ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: enabled ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }
}
