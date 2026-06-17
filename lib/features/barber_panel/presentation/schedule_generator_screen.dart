import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart' show BarberBookingActions, barberPanelRepositoryProvider;

/// Auto-generate slots for a date range. Picks date range, day open/close,
/// slot duration, optional lunch break, and POSTs to the schedule-generate
/// endpoint.
class ScheduleGeneratorScreen extends ConsumerStatefulWidget {
  const ScheduleGeneratorScreen({super.key});
  @override
  ConsumerState<ScheduleGeneratorScreen> createState() => _ScheduleGeneratorScreenState();
}

class _ScheduleGeneratorScreenState extends ConsumerState<ScheduleGeneratorScreen> {
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _dayStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _dayEnd = const TimeOfDay(hour: 20, minute: 0);
  int _slotMinutes = 30;
  bool _lunchEnabled = true;
  TimeOfDay _lunchStart = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _lunchEnd = const TimeOfDay(hour: 14, minute: 0);
  bool _busy = false;

  String _d(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  String _t(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => start ? _from = picked : _to = picked);
  }

  Future<void> _pickTime(int which) async {
    final initial = switch (which) {
      0 => _dayStart,
      1 => _dayEnd,
      2 => _lunchStart,
      _ => _lunchEnd,
    };
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      switch (which) {
        case 0: _dayStart = picked; break;
        case 1: _dayEnd = picked; break;
        case 2: _lunchStart = picked; break;
        case 3: _lunchEnd = picked; break;
      }
    });
  }

  Future<void> _generate() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (_to.isBefore(_from)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sana oralig'i noto'g'ri")));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jadval yaratildi")));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
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
      appBar: AppBar(title: const Text("Avtomatik jadval")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text("Sana oralig'i",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Picker(icon: Icons.calendar_today, label: "Boshlanish", value: _d(_from), onTap: () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _Picker(icon: Icons.event, label: "Tugash", value: _d(_to), onTap: () => _pickDate(false))),
          ]),

          const SizedBox(height: 22),
          const Text("Ish soatlari",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Picker(icon: Icons.wb_sunny_outlined, label: "Ochilish", value: _t(_dayStart), onTap: () => _pickTime(0))),
            const SizedBox(width: 10),
            Expanded(child: _Picker(icon: Icons.nightlight_outlined, label: "Yopilish", value: _t(_dayEnd), onTap: () => _pickTime(1))),
          ]),

          const SizedBox(height: 22),
          const Text("Bir slot davomiyligi",
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [15, 20, 30, 45, 60].map((m) => ChoiceChip(
                  label: Text("$m daq"),
                  selected: _slotMinutes == m,
                  onSelected: (_) => setState(() => _slotMinutes = m),
                )).toList(),
          ),

          const SizedBox(height: 22),
          SwitchListTile(
            value: _lunchEnabled,
            activeThumbColor: AppColors.primary,
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            onChanged: (v) => setState(() => _lunchEnabled = v),
            title: const Text("Tushlik tanaffusi", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (_lunchEnabled) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Picker(icon: Icons.restaurant_outlined, label: "Boshlanish", value: _t(_lunchStart), onTap: () => _pickTime(2))),
              const SizedBox(width: 10),
              Expanded(child: _Picker(icon: Icons.restaurant, label: "Tugash", value: _t(_lunchEnd), onTap: () => _pickTime(3))),
            ]),
          ],

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Taxminan $dayCount kun × $slotsPerDay slot = $total slot yaratiladi",
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _generate,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Jadval yaratish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  int _approxSlotsPerDay() {
    final dayMin = _dayEnd.hour * 60 + _dayEnd.minute - (_dayStart.hour * 60 + _dayStart.minute);
    final lunchMin = _lunchEnabled
        ? (_lunchEnd.hour * 60 + _lunchEnd.minute - (_lunchStart.hour * 60 + _lunchStart.minute))
        : 0;
    final usable = dayMin - lunchMin;
    if (usable <= 0) return 0;
    return (usable / _slotMinutes).floor();
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textBright)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
