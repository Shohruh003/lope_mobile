import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../barbers/data/barber_repository.dart';
import '../../barbers/domain/barber.dart';
import '../data/booking_repository.dart';

/// Three-step booking flow on a single scroll: pick services, pick a date,
/// pick a time. The CTA at the bottom shows total price + duration and
/// posts the booking when everything is filled.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final Set<String> _selectedServiceIds = {};
  DateTime? _selectedDate;
  String? _selectedTime;
  bool _submitting = false;

  // Generated 14-day strip starting today.
  late final List<DateTime> _days = List.generate(14, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _submit(Barber barber) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (_selectedDate == null || _selectedTime == null || _selectedServiceIds.isEmpty) return;

    final picked = barber.services.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final totalPrice = picked.fold<int>(0, (a, b) => a + b.price);
    final totalDuration = picked.fold<int>(0, (a, b) => a + b.duration);

    setState(() => _submitting = true);
    try {
      await ref.read(bookingRepositoryProvider).create(
            userId: user.id,
            barberId: barber.id,
            date: _dateStr(_selectedDate!),
            time: _selectedTime!,
            totalPrice: totalPrice,
            totalDuration: totalDuration,
            services: picked
                .map((s) => {
                      'id': s.id,
                      'name': s.name,
                      'nameUz': s.name,
                      'nameRu': s.name,
                      'price': s.price,
                      'duration': s.duration,
                      'icon': s.icon,
                    })
                .toList(),
          );
      ref.invalidate(myBookingsProvider);
      if (!mounted) return;
      // Success — pop to root tabs and switch to the bookings tab.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bron tasdiqlandi ✓")),
      );
      context.go('/home');
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik: ${e.toString().substring(0, e.toString().length.clamp(0, 80))}")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberDetailProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(title: const Text("Bron qilish")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Yuklab bo'lmadi: $e")),
        data: (barber) => _Content(
          barber: barber,
          days: _days,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          selectedServiceIds: _selectedServiceIds,
          dateStr: _dateStr,
          submitting: _submitting,
          onPickService: (id) {
            setState(() {
              if (_selectedServiceIds.contains(id)) {
                _selectedServiceIds.remove(id);
              } else {
                _selectedServiceIds.add(id);
              }
            });
          },
          onPickDate: (d) => setState(() {
            _selectedDate = d;
            _selectedTime = null;
          }),
          onPickTime: (t) => setState(() => _selectedTime = t),
          onSubmit: () => _submit(barber),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.barber,
    required this.days,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedServiceIds,
    required this.dateStr,
    required this.submitting,
    required this.onPickService,
    required this.onPickDate,
    required this.onPickTime,
    required this.onSubmit,
  });
  final Barber barber;
  final List<DateTime> days;
  final DateTime? selectedDate;
  final String? selectedTime;
  final Set<String> selectedServiceIds;
  final String Function(DateTime) dateStr;
  final bool submitting;
  final void Function(String) onPickService;
  final void Function(DateTime) onPickDate;
  final void Function(String) onPickTime;
  final VoidCallback onSubmit;

  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPrice = barber.services
        .where((s) => selectedServiceIds.contains(s.id))
        .fold<int>(0, (a, b) => a + b.price);
    final totalDuration = barber.services
        .where((s) => selectedServiceIds.contains(s.id))
        .fold<int>(0, (a, b) => a + b.duration);
    final canSubmit = selectedServiceIds.isNotEmpty && selectedDate != null && selectedTime != null && !submitting;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Step 1: services ----
              const _StepLabel(num: 1, text: "Xizmatni tanlang"),
              const SizedBox(height: 12),
              if (barber.services.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("Xizmatlar yo'q", style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ...barber.services.map((s) {
                  final on = selectedServiceIds.contains(s.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onPickService(s.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: on ? AppColors.primary : AppColors.border,
                            width: on ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(s.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text("${s.duration} daq • ${_fmt(s.price)} so'm",
                                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            AnimatedScale(
                              scale: on ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // ---- Step 2: date ----
              const _StepLabel(num: 2, text: "Sanani tanlang"),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final on = selectedDate != null &&
                        selectedDate!.year == d.year &&
                        selectedDate!.month == d.month &&
                        selectedDate!.day == d.day;
                    return GestureDetector(
                      onTap: () => onPickDate(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: on ? AppColors.primary : AppColors.border),
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

              // ---- Step 3: time ----
              if (selectedDate != null) ...[
                const SizedBox(height: 24),
                const _StepLabel(num: 3, text: "Vaqtni tanlang"),
                const SizedBox(height: 12),
                _TimeGrid(
                  barberId: barber.id,
                  dateStr: dateStr(selectedDate!),
                  selected: selectedTime,
                  onPick: onPickTime,
                ),
              ],
            ],
          ),
        ),

        // ---- Floating CTA with summary ----
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalPrice == 0 ? "—" : "${_fmt(totalPrice)} so'm",
                          style:
                              const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        Text(
                          totalDuration == 0 ? "Xizmat tanlang" : "$totalDuration daqiqa",
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canSubmit ? onSubmit : null,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        child: submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text("Tasdiqlash",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
        ),
      ],
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

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.num, required this.text});
  final int num;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text("$num",
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// Pulls the barber's day-schedule + already-booked slots from the backend.
/// Schedule may be empty if the barber hasn't generated one for that date —
/// we surface a friendly message in that case.
class _TimeGrid extends ConsumerWidget {
  const _TimeGrid({
    required this.barberId,
    required this.dateStr,
    required this.selected,
    required this.onPick,
  });
  final String barberId;
  final String dateStr;
  final String? selected;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(_daySlotsProvider((barberId: barberId, date: dateStr)));
    return scheduleAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text("Slotlarni yuklab bo'lmadi: $e",
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
      data: (data) {
        if (data.slots.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text("Bu kunda bo'sh vaqt yo'q",
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: data.slots.map((time) {
            final taken = data.booked.contains(time);
            final on = selected == time;
            return GestureDetector(
              onTap: taken ? null : () => onPick(time),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: on
                      ? AppColors.primary
                      : taken
                          ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                          : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: on
                        ? Colors.white
                        : taken
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                    decoration: taken ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SlotsResult {
  _SlotsResult({required this.slots, required this.booked});
  final List<String> slots;
  final Set<String> booked;
}

/// Combined slots + booked-slots fetch as one provider — the screen needs
/// both, in one frame, to render the disabled state correctly.
final _daySlotsProvider =
    FutureProvider.family<_SlotsResult, ({String barberId, String date})>((ref, key) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final results = await Future.wait([
    repo.daySchedule(barberId: key.barberId, date: key.date),
    repo.bookedSlots(barberId: key.barberId, date: key.date),
  ]);
  return _SlotsResult(slots: results[0], booked: results[1].toSet());
});
