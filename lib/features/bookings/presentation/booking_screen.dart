import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../barbers/data/barber_repository.dart';
import '../../barbers/domain/barber.dart';
import '../data/booking_repository.dart';

/// Mirrors `CustomerBookingPage.tsx` 1:1:
///   Step 1 — Service selector (icon + name + price/duration row each)
///   Step 2 — Date strip (14 days, disabled when no slots) + 3-col time grid
///   Step 3 — Summary card + notes input + Confirm
///   Plus a circular step indicator (1 → 2 → 3) at the top of each step.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _step = 1;
  final Set<String> _selectedServiceIds = {};
  DateTime? _selectedDate;
  String? _selectedTime;
  // ignore: unused_field
  String _notes = '';
  bool _submitting = false;
  bool _confirmed = false;

  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _months = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];

  late final List<DateTime> _days = List.generate(14, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    // Guest guard — mirrors web's `requireLogin` flow. Guests landing on the
    // booking page see an explanatory dialog and a single CTA to sign in,
    // instead of a broken form.
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLoginRequired());
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final barberAsync = ref.watch(barberDetailProvider(widget.barberId));

    return Scaffold(
      body: SafeArea(
        child: barberAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
            ),
          ),
          data: (barber) {
            if (_confirmed) return _ConfirmedView(barber: barber);

            return Column(children: [
              // ===== Sticky header =====
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20),
                    onPressed: () => context.pop(),
                  ),
                  Text(tr(ref, 'booking.title', "Bron qilish"),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textBright)),
                ]),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    // ===== Step indicator =====
                    _StepIndicator(current: _step),

                    const SizedBox(height: 22),

                    if (_step == 1) _stepServices(barber),
                    if (_step == 2) _stepDateTime(barber),
                    if (_step == 3) _stepConfirm(barber),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  // ============ STEP 1 ============
  Widget _stepServices(Barber barber) {
    final hasNoServices = barber.services.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr(ref, 'booking.selectService', "Xizmatlarni tanlang"),
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textBright)),
      const SizedBox(height: 14),

      if (hasNoServices)
        ShadCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(ref, 'booking.noServicesTitle', "Xizmatlar belgilanmagan"),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBright,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(tr(ref, 'booking.agreedOnSite', "Sartarosh bilan kelishasiz"),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
        )
      else
        ...barber.services.map((s) {
          final on = _selectedServiceIds.contains(s.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                if (on) {
                  _selectedServiceIds.remove(s.id);
                } else {
                  _selectedServiceIds.add(s.id);
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: on
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: on ? AppColors.primary : AppColors.border),
                ),
                child: Row(children: [
                  Text(s.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textBright)),
                        Text("${s.duration} ${tr(ref, 'booking.duration', 'daq')}",
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text("${_fmt(s.price)} ${tr(ref, 'common.currency', "so'm")}",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                          color: on ? AppColors.primary : AppColors.border),
                    ),
                    child: on
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 12)
                        : null,
                  ),
                ]),
              ),
            ),
          );
        }),

      const SizedBox(height: 14),
      SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: (!hasNoServices && _selectedServiceIds.isEmpty)
              ? null
              : () => setState(() => _step = 2),
          child: Text(tr(ref, 'common.continue', "Davom etish")),
        ),
      ),
    ]);
  }

  // ============ STEP 2 ============
  Widget _stepDateTime(Barber barber) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final dateKey = _selectedDate == null
        ? null
        : (barberId: barber.id, date: _dateStr(_selectedDate!));
    final slotsAsync = dateKey == null ? null : ref.watch(daySlotsProvider(dateKey));
    final bookedAsync = dateKey == null ? null : ref.watch(bookedTimesProvider(dateKey));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Date pick
      Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textBright),
        const SizedBox(width: 6),
        Text(tr(ref, 'booking.selectDate', "Sanani tanlang"),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textBright)),
      ]),
      const SizedBox(height: 10),

      SizedBox(
        height: 76,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _days.length,
          itemBuilder: (context, i) {
            final d = _days[i];
            final isSelected = _selectedDate != null &&
                d.year == _selectedDate!.year &&
                d.month == _selectedDate!.month &&
                d.day == _selectedDate!.day;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _selectedDate = d;
                  _selectedTime = null;
                }),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(trList(ref, 'mobile.dates.weekDaysShort', _weekDays)[d.weekday - 1].toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textMuted)),
                      const SizedBox(height: 3),
                      Text("${d.day}",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textBright)),
                      const SizedBox(height: 2),
                      Text(_months[d.month - 1],
                          style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white70
                                  : AppColors.textMuted)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 18),

      // Time grid (only if date selected)
      if (_selectedDate != null) ...[
        Row(children: [
          const Icon(Icons.access_time, size: 18, color: AppColors.textBright),
          const SizedBox(width: 6),
          Text(tr(ref, 'booking.selectTime', "Vaqtni tanlang"),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textBright)),
        ]),
        const SizedBox(height: 10),

        slotsAsync?.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                  style: const TextStyle(color: AppColors.textMuted)),
              data: (slots) {
                if (slots.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(tr(ref, 'common.noSlots', "Bu kunda bo'sh vaqt yo'q"),
                        style: const TextStyle(color: AppColors.textMuted)),
                  );
                }
                final booked = bookedAsync?.maybeWhen(
                        data: (v) => v, orElse: () => <String>[]) ??
                    [];
                // Filter past times for today
                final now = DateTime.now();
                final isToday = _selectedDate!.year == now.year &&
                    _selectedDate!.month == now.month &&
                    _selectedDate!.day == now.day;
                final nowMin = now.hour * 60 + now.minute;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final t = slots[i];
                    final parts = t.split(':');
                    final slotMin =
                        int.parse(parts[0]) * 60 + int.parse(parts[1]);
                    final isPast = isToday && slotMin <= nowMin;
                    final isBooked = booked.contains(t);
                    final disabled = isPast || isBooked;
                    final isOn = _selectedTime == t;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: disabled
                          ? null
                          : () => setState(() => _selectedTime = t),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isOn ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isOn
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Center(
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isOn
                                  ? Colors.white
                                  : disabled
                                      ? AppColors.textMuted
                                          .withValues(alpha: 0.4)
                                      : AppColors.textBright,
                              decoration: disabled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ) ??
            const SizedBox.shrink(),
      ],

      const SizedBox(height: 18),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(tr(ref, 'common.back', "Orqaga")),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed:
                  (_selectedDate == null || _selectedTime == null) ? null : () => setState(() => _step = 3),
              child: Text(tr(ref, 'common.continue', "Davom etish")),
            ),
          ),
        ),
      ]),
    ]);
  }

  // ============ STEP 3 ============
  Widget _stepConfirm(Barber barber) {
    final selectedServices =
        barber.services.where((s) => _selectedServiceIds.contains(s.id)).toList();
    final totalPrice = selectedServices.fold<int>(0, (a, s) => a + s.price);
    final totalDuration = selectedServices.fold<int>(0, (a, s) => a + s.duration);
    final hasNoServices = barber.services.isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.credit_card_outlined, size: 18, color: AppColors.textBright),
        const SizedBox(width: 6),
        Text(tr(ref, 'booking.confirmBooking', "Bronni tasdiqlash"),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textBright)),
      ]),
      const SizedBox(height: 14),

      // Summary
      ShadCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // Barber
          Row(children: [
            ClipOval(
              child: barber.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: barber.avatar,
                      width: 40, height: 40,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 40, height: 40,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Text(barber.name.isNotEmpty ? barber.name[0] : '?',
                          style: const TextStyle(
                              color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(barber.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textBright)),
                  if (barber.location.isNotEmpty)
                    Text(barber.location,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const Divider(color: AppColors.border, height: 18),

          // Services
          if (hasNoServices)
            _SummaryRow(
                label: tr(ref, 'booking.service', "Xizmat"),
                value: tr(ref, 'booking.agreedOnSite', "Sartarosh bilan kelishasiz"))
          else
            ...selectedServices.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SummaryRow(
                    label: "${s.icon} ${s.name}",
                    value: "${_fmt(s.price)} ${tr(ref, 'common.currency', "so'm")}",
                  ),
                )),
          const Divider(color: AppColors.border, height: 18),

          _SummaryRow(
              label: tr(ref, 'booking.date', "Sana"),
              value: _dateStr(_selectedDate!)),
          const SizedBox(height: 6),
          _SummaryRow(
            label: tr(ref, 'booking.time', "Vaqt"),
            value: hasNoServices
                ? (_selectedTime ?? '')
                : "${_selectedTime ?? ''} ($totalDuration ${tr(ref, 'booking.duration', 'daq')})",
          ),

          const Divider(color: AppColors.border, height: 18),

          Row(children: [
            Text(tr(ref, 'booking.price', "Narx"),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright)),
            const Spacer(),
            Text(
              hasNoServices
                  ? tr(ref, 'booking.agreedOnSite', "Sartarosh bilan kelishasiz")
                  : "${_fmt(totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ]),
        ]),
      ),

      const SizedBox(height: 14),

      // Notes
      ShadLabel(tr(ref, 'booking.notes', "Izoh")),
      const SizedBox(height: 6),
      TextField(
        onChanged: (v) => _notes = v,
        decoration: InputDecoration(
            hintText: tr(ref, 'booking.notesPlaceholder',
                "Qo'shimcha ma'lumot (ixtiyoriy)")),
      ),

      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => setState(() => _step = 2),
              child: Text(tr(ref, 'common.back', "Orqaga")),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(barber),
              child: _submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(tr(ref, 'common.confirm', "Tasdiqlash")),
            ),
          ),
        ),
      ]),
    ]);
  }

  bool _loginPromptShown = false;
  Future<void> _showLoginRequired() async {
    if (_loginPromptShown || !mounted) return;
    _loginPromptShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'booking.accountNeeded', "Akkaunt kerak")),
        content: Text(tr(ref, 'booking.accountNeededHint',
            "Bron qilish uchun avval ro'yxatdan o'ting yoki tizimga kiring.")),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dCtx).pop();
              if (mounted) context.pop();
            },
            child: Text(tr(ref, 'common.cancel', "Bekor")),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dCtx).pop();
              if (mounted) context.go('/login');
            },
            child: Text(tr(ref, 'auth.login', "Kirish")),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(Barber barber) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    // ===== Gender restriction guard =====
    // If the barber only accepts one gender, refuse the booking up-front so
    // the user gets an immediate explanation instead of an opaque 403 from
    // the backend.
    final tg = barber.targetGender;
    if (tg == 'MALE_ONLY' || tg == 'FEMALE_ONLY') {
      // Mobile doesn't currently carry the user's gender in the local
      // user object — fetch from settings or rely on the backend's reject.
      // We still show a heads-up modal so the customer knows why.
      final needFemale = tg == 'FEMALE_ONLY';
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(needFemale
              ? tr(ref, 'booking.femaleOnlyTitle', "Faqat ayollar uchun")
              : tr(ref, 'booking.maleOnlyTitle', "Faqat erkaklar uchun")),
          content: Text(needFemale
              ? tr(ref, 'booking.femaleOnlyMsg',
                  "Bu sartarosh faqat ayol mijozlarni qabul qiladi. Davom etishni xohlaysizmi?")
              : tr(ref, 'booking.maleOnlyMsg',
                  "Bu sartarosh faqat erkak mijozlarni qabul qiladi. Davom etishni xohlaysizmi?")),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dCtx).pop(false),
                child: Text(tr(ref, 'common.cancel', "Bekor"))),
            TextButton(
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: Text(tr(ref, 'common.continue', "Davom")),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _submitting = true);
    try {
      final picked = barber.services
          .where((s) => _selectedServiceIds.contains(s.id))
          .toList();
      final totalPrice = picked.fold<int>(0, (a, s) => a + s.price);
      final totalDuration = picked.fold<int>(0, (a, s) => a + s.duration);
      await ref.read(bookingRepositoryProvider).create(
            userId: user.id,
            barberId: barber.id,
            date: _dateStr(_selectedDate!),
            time: _selectedTime!,
            services: picked
                .map((s) => {
                      'id': s.id,
                      'nameUz': s.name,
                      'name': s.name,
                      'price': s.price,
                      'duration': s.duration,
                      'icon': s.icon,
                    })
                .toList(),
            totalPrice: totalPrice,
            totalDuration: totalDuration,
          );
      if (mounted) setState(() => _confirmed = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final stepNum = i + 1;
        final isActive = stepNum <= current;
        return Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text("$stepNum",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textMuted)),
          ),
          if (stepNum < 3)
            Container(
              width: 40, height: 2,
              color: stepNum < current ? AppColors.primary : AppColors.border,
            ),
        ]);
      }),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
      Text(value,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textBright)),
    ]);
  }
}

class _ConfirmedView extends ConsumerWidget {
  const _ConfirmedView({required this.barber});
  final Barber barber;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: AppColors.success, size: 36),
        ).animate().scale(
            begin: const Offset(0.4, 0.4),
            duration: 400.ms,
            curve: Curves.easeOutBack),
        const SizedBox(height: 14),
        Text(tr(ref, 'booking.bookingConfirmed', "Bron tasdiqlandi"),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textBright)),
        const SizedBox(height: 4),
        Text(tr(ref, 'booking.barberAwaits', "{{name}} sizni kutadi",
                {'name': barber.name}),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/home'),
            child: Text(tr(ref, 'booking.myBookings', "Mening bronlarim")),
          ),
        ),
      ]),
    );
  }
}

// === Providers for day slots and booked times ===
final daySlotsProvider = FutureProvider.family<List<String>, ({String barberId, String date})>(
  (ref, key) async {
    // Reuse barber-panel logic via repo (web fetches /schedule/:id/:date).
    final dio = ref.watch(barberRepositoryProvider);
    return dio.scheduleSlots(barberId: key.barberId, date: key.date);
  },
);

final bookedTimesProvider = FutureProvider.family<List<String>, ({String barberId, String date})>(
  (ref, key) async {
    final repo = ref.watch(barberRepositoryProvider);
    return repo.bookedTimes(barberId: key.barberId, date: key.date);
  },
);
