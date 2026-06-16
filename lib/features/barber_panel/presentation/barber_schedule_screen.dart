import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart' show BarberBooking, barberDayBookingsProvider;

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
                          child: _BookingTile(booking: b)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                              .slideY(begin: 0.1, end: 0),
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
