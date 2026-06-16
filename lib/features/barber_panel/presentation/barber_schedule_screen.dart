import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart'
    show BarberBooking, BarberBookingActions, barberDayBookingsProvider, barberAllBookingsProvider, barberPanelRepositoryProvider;
import '../data/barber_profile_repository.dart';

/// Today's schedule view for a barber. Shows the date strip at the top + a
/// list of today's bookings sorted by time.
class BarberScheduleScreen extends ConsumerStatefulWidget {
  const BarberScheduleScreen({super.key});

  @override
  ConsumerState<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends ConsumerState<BarberScheduleScreen> {
  late DateTime _selectedDate;
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    // Strip: 7 days back + today + 14 days forward — common barber view.
    _days = List.generate(22, (i) {
      final base = DateTime(now.year, now.month, now.day);
      return base.add(Duration(days: i - 7));
    });
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _months = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
  ];

  @override
  Widget build(BuildContext context) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final dateStr = _dateStr(_selectedDate);
    final async = ref.watch(
      barberDayBookingsProvider((barberId: barberId, date: dateStr)),
    );

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'voiceFab',
            backgroundColor: AppColors.warning,
            onPressed: () => _openVoiceBookingSheet(context, ref, barberId, dateStr),
            child: const Icon(Icons.mic),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'genFab',
            backgroundColor: AppColors.primaryDark,
            onPressed: () => context.push('/barber/schedule-generator'),
            child: const Icon(Icons.auto_awesome_motion),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'manualFab',
            backgroundColor: AppColors.primary,
            onPressed: () => _openManualBookingSheet(context, ref, barberId, dateStr),
            icon: const Icon(Icons.add),
            label: const Text("Qo'lda bron"),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(
            barberDayBookingsProvider((barberId: barberId, date: dateStr)).future,
          ),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Jadval",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 4),
                    Text(
                      "${_selectedDate.day}-${_months[_selectedDate.month - 1]} ${_selectedDate.year}",
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ).animate().fadeIn(duration: 400.ms, delay: 60.ms),
                  ],
                ),
              ),

              // Date strip
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _days.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = _days[i];
                    final on = d.day == _selectedDate.day &&
                        d.month == _selectedDate.month &&
                        d.year == _selectedDate.year;
                    final isToday = d.day == DateTime.now().day &&
                        d.month == DateTime.now().month &&
                        d.year == DateTime.now().year;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDate = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on ? AppColors.primary : (isToday ? AppColors.primary : AppColors.border),
                            width: isToday && !on ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _weekDays[d.weekday - 1],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: on ? Colors.white70 : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${d.day}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: on ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Today's bookings
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("Xato: $e",
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_available, size: 48, color: AppColors.textMuted),
                            SizedBox(height: 12),
                            Text("Bu kunda bron yo'q",
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          ],
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      children: list.asMap().entries.map((e) {
                        final i = e.key;
                        final b = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GestureDetector(
                            onTap: () => _openActionSheet(context, ref, b, barberId, dateStr),
                            child: _BookingTile(booking: b)
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                                .slideY(begin: 0.1, end: 0),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Action sheet on an existing booking: cancel / mark complete ----
  Future<void> _openActionSheet(BuildContext context, WidgetRef ref,
      BarberBooking b, String barberId, String dateStr) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                "${b.time}  •  ${(b.guestName?.isNotEmpty == true ? b.guestName! : (b.userName.isNotEmpty ? b.userName : 'Mijoz'))}",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            if (b.status != 'completed')
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                title: const Text("Yakunlangan deb belgilash"),
                onTap: () => Navigator.of(sheetCtx).pop('complete'),
              ),
            if (b.status != 'cancelled' && b.status != 'completed') ...[
              ListTile(
                leading: const Icon(Icons.schedule, color: AppColors.primary),
                title: const Text("Vaqtni o'zgartirish"),
                onTap: () => Navigator.of(sheetCtx).pop('reschedule'),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse, color: AppColors.warning),
                title: const Text("Vaqtni uzaytirish"),
                onTap: () => Navigator.of(sheetCtx).pop('extend'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                title: const Text("Bekor qilish"),
                onTap: () => Navigator.of(sheetCtx).pop('cancel'),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.textMuted),
              title: const Text("Yopish"),
              onTap: () => Navigator.of(sheetCtx).pop(null),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final repo = ref.read(barberPanelRepositoryProvider);
    try {
      if (picked == 'complete') {
        await repo.markComplete(b.id);
      } else if (picked == 'reschedule') {
        if (!context.mounted) return;
        await _openRescheduleSheet(context, ref, b, barberId, dateStr);
        return;
      } else if (picked == 'extend') {
        if (!context.mounted) return;
        await _openExtendSheet(context, ref, b, barberId, dateStr);
        return;
      } else if (picked == 'cancel') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text("Bronni bekor qilasizmi?"),
            content: const Text("Bekor qilingan bronni qaytarib bo'lmaydi."),
            actions: [
              TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text("Yo'q")),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => Navigator.of(dCtx).pop(true),
                child: const Text("Bekor qilish"),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await repo.cancel(b.id);
      }
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateStr)));
      ref.invalidate(barberAllBookingsProvider(barberId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  Future<void> _openRescheduleSheet(BuildContext context, WidgetRef ref,
      BarberBooking b, String barberId, String oldDateStr) async {
    // Use native pickers — text-input was a UX bug (allowed any string).
    DateTime selectedDate = DateTime.tryParse(b.date) ?? DateTime.now();
    final timeParts = b.time.split(':');
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.tryParse(timeParts.isNotEmpty ? timeParts[0] : '9') ?? 9,
      minute: int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0,
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Vaqtni o'zgartirish",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _PickerRow(
                icon: Icons.calendar_today,
                label: "Sana",
                value: "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setSheet(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: 10),
              _PickerRow(
                icon: Icons.access_time,
                label: "Soat",
                value: "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                onTap: () async {
                  final picked = await showTimePicker(context: sheetCtx, initialTime: selectedTime);
                  if (picked != null) setSheet(() => selectedTime = picked);
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  child: const Text("Saqlash"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true) return;
    final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
    final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

    try {
      await ref.read(barberPanelRepositoryProvider).reschedule(
            b.id,
            date: dateStr,
            time: timeStr,
          );
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: oldDateStr)));
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateStr)));
      ref.invalidate(barberAllBookingsProvider(barberId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O'zgartirildi")));
      }
    } catch (e) {
      if (context.mounted) {
        final s = e.toString();
        final msg = s.contains('409') ? "Bu vaqt allaqachon band" : "Xato: $e";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _openExtendSheet(BuildContext context, WidgetRef ref,
      BarberBooking b, String barberId, String dateStr) async {
    int minutes = 15;
    final saved = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Vaqtni uzaytirish",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [10, 15, 20, 30, 45, 60].map((m) => ChoiceChip(
                  label: Text("+$m daq"),
                  selected: minutes == m,
                  onSelected: (_) => setSheet(() => minutes = m),
                )).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(minutes),
                  child: const Text("Saqlash"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == null) return;
    try {
      await ref.read(barberPanelRepositoryProvider).extendDuration(b.id, saved);
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateStr)));
      ref.invalidate(barberAllBookingsProvider(barberId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vaqt uzaytirildi")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  // ---- Voice booking: hold mic to record, release to send ----
  Future<void> _openVoiceBookingSheet(BuildContext context, WidgetRef ref,
      String barberId, String dateStr) async {
    final recorder = AudioRecorder();
    bool recording = false;
    bool processing = false;
    Map<String, dynamic>? parsed;
    String? error;
    String? filePath;

    // Permission check upfront. Skip with friendly message if denied.
    if (!await recorder.hasPermission()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Mikrofon ruxsati berilmadi")));
      }
      return;
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ovoz bilan bron",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                "Mikrofonni bosing va aytib bering: ism, telefon, soat",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTapDown: (_) async {
                  if (recording || processing) return;
                  try {
                    final dir = await getTemporaryDirectory();
                    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
                    await recorder.start(
                      const RecordConfig(encoder: AudioEncoder.aacLc),
                      path: path,
                    );
                    filePath = path;
                    setSheet(() {
                      recording = true;
                      error = null;
                    });
                  } catch (e) {
                    setSheet(() => error = "Yozib bo'lmadi: $e");
                  }
                },
                onTapUp: (_) async {
                  if (!recording) return;
                  final path = await recorder.stop();
                  filePath = path ?? filePath;
                  setSheet(() {
                    recording = false;
                    processing = true;
                  });
                  if (filePath == null) {
                    setSheet(() {
                      processing = false;
                      error = "Yozma topilmadi";
                    });
                    return;
                  }
                  try {
                    final res = await ref.read(barberPanelRepositoryProvider)
                        .parseVoiceBooking(barberId: barberId, audioPath: filePath!);
                    setSheet(() {
                      parsed = res;
                      processing = false;
                    });
                  } catch (e) {
                    setSheet(() {
                      processing = false;
                      error = "Tahlil bo'lmadi: $e";
                    });
                  }
                },
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: recording ? AppColors.danger : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (recording ? AppColors.danger : AppColors.primary).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: recording ? 6 : 0,
                      ),
                    ],
                  ),
                  child: Icon(recording ? Icons.stop : Icons.mic, color: Colors.white, size: 56),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                recording
                    ? "Yozilmoqda... qo'lni qo'yib yuborganda yuboriladi"
                    : (processing ? "Tahlil qilinmoqda..." : "Bosib turing"),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              if (parsed != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tahlil natijasi", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(parsed.toString(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text("Yopish"),
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
    await recorder.dispose();
    ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateStr)));
  }

  // ---- Manual booking: barber adds a walk-in client ----
  Future<void> _openManualBookingSheet(BuildContext context, WidgetRef ref,
      String barberId, String dateStr) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final notesCtrl = TextEditingController();
    final services = await ref.read(barberServicesProvider(barberId).future);
    if (!context.mounted) return;
    final selected = <String>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Qo'lda bron qo'shish",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: "Mijoz ismi")),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: "Telefon (ixtiyoriy)")),
                const SizedBox(height: 10),
                _PickerRow(
                  icon: Icons.access_time,
                  label: "Soat",
                  value: "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}",
                  onTap: () async {
                    final picked = await showTimePicker(context: sheetCtx, initialTime: selectedTime);
                    if (picked != null) setSheet(() => selectedTime = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(controller: notesCtrl, decoration: const InputDecoration(hintText: "Izoh (ixtiyoriy)")),
                const SizedBox(height: 14),
                if (services.isEmpty)
                  const Text("Avval xizmatlar qo'shing — yo'q",
                      style: TextStyle(color: AppColors.danger, fontSize: 13))
                else ...[
                  const Text("Xizmatlar",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: services.map((s) {
                      final id = s['id'] as String;
                      final name = (s['nameUz'] ?? s['name'] ?? '').toString();
                      final on = selected.contains(id);
                      return FilterChip(
                        label: Text(name),
                        selected: on,
                        onSelected: (v) => setSheet(() {
                          if (v) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: services.isEmpty || selected.isEmpty
                        ? null
                        : () => Navigator.of(sheetCtx).pop(true),
                    child: const Text("Saqlash"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";
    try {
      await ref.read(barberPanelRepositoryProvider).createManual(
            barberId: barberId,
            date: dateStr,
            time: timeStr,
            serviceIds: selected.toList(),
            guestName: nameCtrl.text.trim(),
            guestPhone: phoneCtrl.text.trim(),
            notes: notesCtrl.text.trim(),
          );
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateStr)));
      ref.invalidate(barberAllBookingsProvider(barberId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bron qo'shildi")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }
}

/// Tappable row that opens a native date/time picker. Used inside the
/// reschedule + manual booking sheets so the barber can never type garbage
/// into the time field.
class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.icon, required this.label, required this.value, required this.onTap});
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textBright)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});
  final BarberBooking booking;

  Color get _statusColor {
    switch (booking.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = booking.guestName?.isNotEmpty == true
        ? booking.guestName!
        : (booking.userName.isNotEmpty ? booking.userName : 'Mijoz');
    final phone = booking.guestPhone ?? booking.userPhone ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  booking.time,
                  style: TextStyle(
                      color: _statusColor, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (booking.totalDuration > 0)
                  Text(
                    "${booking.totalDuration} daq",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(phone,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
                if (booking.totalPrice > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    "${_fmt(booking.totalPrice)} so'm",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
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
