import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openManualBookingSheet(context, ref, barberId, dateStr),
        icon: const Icon(Icons.add),
        label: const Text("Qo'lda bron"),
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
    final dateCtrl = TextEditingController(text: b.date);
    final timeCtrl = TextEditingController(text: b.time);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
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
            TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(hintText: "Sana (YYYY-MM-DD)")),
            const SizedBox(height: 10),
            TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(hintText: "Soat (HH:MM)")),
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
    );
    if (saved != true) return;
    try {
      await ref.read(barberPanelRepositoryProvider).reschedule(
            b.id,
            date: dateCtrl.text.trim(),
            time: timeCtrl.text.trim(),
          );
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: oldDateStr)));
      ref.invalidate(barberDayBookingsProvider((barberId: barberId, date: dateCtrl.text.trim())));
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

  // ---- Manual booking: barber adds a walk-in client ----
  Future<void> _openManualBookingSheet(BuildContext context, WidgetRef ref,
      String barberId, String dateStr) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '09:00');
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
                TextField(controller: timeCtrl, decoration: const InputDecoration(hintText: "Soat (HH:MM)")),
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
    try {
      await ref.read(barberPanelRepositoryProvider).createManual(
            barberId: barberId,
            date: dateStr,
            time: timeCtrl.text.trim(),
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
