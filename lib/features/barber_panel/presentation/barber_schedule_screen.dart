import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/barber_panel_repository.dart';

/// Mirrors the web `BarberScheduleScreen.tsx` 1:1:
///   1. Voice booking card at the top (hold-to-record mic button)
///   2. Horizontal 30-day date scroller — selected pill = primary bg, days
///      with slots = normal border, empty days = opacity 40%
///   3. Day header "12-yanvar, dushanba"
///   4. Either empty state with "Jadval yaratish" CTA OR a 3-column slot
///      grid with status-tinted buttons (green=available, blue=booked,
///      red=blocked) — lock icon top-right on blocked
class BarberScheduleScreen extends ConsumerStatefulWidget {
  const BarberScheduleScreen({super.key});

  @override
  ConsumerState<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends ConsumerState<BarberScheduleScreen>
    with WidgetsBindingObserver {
  late DateTime _selectedDate;

  // Voice recording state
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _voiceLoading = false;

  static const _months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];
  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _weekDaysLong = [
    'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recorder.dispose();
    super.dispose();
  }

  /// When the app returns to the foreground, refetch bookings + blocked
  /// slots so a customer's cancel/reschedule that happened while we were
  /// backgrounded shows up immediately. Mirrors web fix d080184 which
  /// added the same visibilitychange listener for the WebView case.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final key = (barberId: user.id, date: _dateStr(_selectedDate));
    ref.invalidate(scheduleSlotsProvider(key));
    ref.invalidate(bookedSlotsProvider(key));
    ref.invalidate(blockedSlotsProvider(key));
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _slotStatus(String time, List<String> booked, List<String> blocked) {
    if (blocked.contains(time)) return 'blocked';
    if (booked.contains(time)) return 'booked';
    return 'available';
  }

  Future<void> _toggleRecording(String barberId) async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _voiceLoading = true;
      });
      if (path != null) {
        try {
          await ref.read(barberPanelRepositoryProvider).parseVoiceBooking(
                barberId: barberId,
                audioPath: path,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(ref, 'mobile.barber.schedule.voiceReceived', "Ovoz qabul qilindi"))));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
          }
        }
      }
      setState(() => _voiceLoading = false);
      _refreshDay(barberId);
    } else {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr(ref, 'mobile.barber.schedule.micDenied', "Mikrofon ruxsati berilmadi"))));
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _isRecording = true);
    }
  }

  void _refreshDay(String barberId) {
    final key = (barberId: barberId, date: _dateStr(_selectedDate));
    ref.invalidate(scheduleSlotsProvider(key));
    ref.invalidate(bookedSlotsProvider(key));
    ref.invalidate(blockedSlotsProvider(key));
  }

  Future<void> _openSlotAction(String barberId, String time, String status) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Text(time,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textBright)),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (status == 'available')
            ListTile(
              leading: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
              title: Text(tr(ref, 'mobile.barber.schedule.addClient', "Mijoz qo'shish"),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(tr(ref, 'mobile.barber.schedule.manualBooking', "Mijoz yozish"),
                  style: const TextStyle(fontSize: 12)),
              onTap: () => Navigator.of(sheetCtx).pop('book'),
            ),
          if (status == 'booked') ...[
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
              title: Text(tr(ref, 'myBookings.complete', "Yakunlash"),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop('complete'),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat, color: AppColors.primary),
              title: Text(
                  tr(ref, 'mobile.shop.barber.reschedule',
                      "Boshqa vaqtga ko'chirish"),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop('reschedule'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined,
                  color: AppColors.primary),
              title: Text(
                  tr(ref, 'mobile.shop.barber.extend',
                      "Vaqtni uzaytirish"),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop('extend'),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.danger),
              title: Text(tr(ref, 'myBookings.cancel', "Bekor qilish"),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetCtx).pop('cancelBooking'),
            ),
          ],
          if (status != 'blocked' && status != 'booked')
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.danger),
              title: Text(tr(ref, 'mobile.barber.schedule.blockSlot', "Slotni bloklash")),
              onTap: () => Navigator.of(sheetCtx).pop('block'),
            ),
          if (status == 'blocked')
            ListTile(
              leading: const Icon(Icons.lock_open, color: AppColors.success),
              title: Text(tr(ref, 'mobile.barber.schedule.unblockSlot', "Blokni olib tashlash")),
              onTap: () => Navigator.of(sheetCtx).pop('unblock'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text(tr(ref, 'mobile.barber.schedule.deleteSlot', "Slotni o'chirish")),
            onTap: () => Navigator.of(sheetCtx).pop('delete'),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: AppColors.textMuted),
            title: Text(tr(ref, 'common.close', "Yopish")),
            onTap: () => Navigator.of(sheetCtx).pop(null),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    try {
      final dateStr = _dateStr(_selectedDate);
      final repo = ref.read(barberPanelRepositoryProvider);
      if (picked == 'book') {
        if (!mounted) return;
        await _openManualBookingDialog(barberId, dateStr, time);
        return;
      }
      if (picked == 'complete' ||
          picked == 'cancelBooking' ||
          picked == 'reschedule' ||
          picked == 'extend') {
        await _handleBookingAction(barberId, dateStr, time, picked);
        return;
      }
      if (picked == 'block' || picked == 'unblock') {
        await repo.toggleSlotBlock(barberId, dateStr, time);
      } else if (picked == 'delete') {
        final current = await repo.getDaySchedule(barberId, dateStr);
        final updated = current.where((t) => t != time).toList();
        await repo.saveDaySchedule(barberId: barberId, date: dateStr, slots: updated);
      }
      _refreshDay(barberId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  /// Look up the booking that owns [time] on [dateStr] and ask the
  /// barber to confirm before completing or cancelling it. Falls back
  /// to a SnackBar if the booking can't be found (e.g. stale cache).
  Future<void> _handleBookingAction(
      String barberId, String dateStr, String time, String action) async {
    final repo = ref.read(barberPanelRepositoryProvider);
    final bookings = await repo.byDay(barberId: barberId, date: dateStr);
    final booking = bookings.firstWhere(
      (b) => b.time == time && b.status != 'cancelled',
      orElse: () => BarberBooking(
          id: '', date: '', time: '', status: '', userName: '',
          totalPrice: 0, totalDuration: 0, services: const []),
    );
    if (booking.id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.error', 'Xatolik'))));
      return;
    }
    if (!mounted) return;

    // Reschedule + extend take their own dedicated flows — short-circuit
    // before the complete/cancel dialog below.
    if (action == 'reschedule') {
      await _rescheduleBooking(booking, dateStr, barberId);
      return;
    }
    if (action == 'extend') {
      await _extendBooking(booking, barberId);
      return;
    }

    final isComplete = action == 'complete';
    int? overrideTotal;
    final priceCtrl = TextEditingController(
        text: booking.totalPrice > 0 ? booking.totalPrice.toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(isComplete
            ? tr(ref, 'myBookings.completeConfirmTitle', "Bronni yakunlash?")
            : tr(ref, 'myBookings.cancelConfirmTitle',
                "Bronni bekor qilasizmi?")),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isComplete
              ? tr(ref, 'myBookings.completeConfirmMsg',
                  "Bron yakunlangan deb belgilanadi.")
              : tr(ref, 'myBookings.cancelConfirmMsg',
                  "Bekor qilingach, qaytarib bo'lmaydi.")),
          // Optional total override on complete — mirrors web (tip/discount).
          if (isComplete) ...[
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr(ref, 'myBookings.totalPriceLabel',
                    "Olingan summa (ixtiyoriy)"),
                hintText: '0',
                suffixText: tr(ref, 'common.currency', "so'm"),
              ),
            ),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: isComplete ? null : AppColors.danger),
              onPressed: () {
                if (isComplete) {
                  overrideTotal = int.tryParse(priceCtrl.text.trim());
                }
                Navigator.pop(dCtx, true);
              },
              child: Text(isComplete
                  ? tr(ref, 'common.confirm', "Tasdiqlash")
                  : tr(ref, 'myBookings.cancel', "Bekor qilish"))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (isComplete) {
        await repo.markComplete(booking.id, totalPrice: overrideTotal);
      } else {
        await repo.cancel(booking.id);
      }
      _refreshDay(barberId);
      ref.invalidate(barberAllBookingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isComplete
                ? tr(ref, 'common.saved', "Saqlandi")
                : tr(ref, 'myBookings.cancelled', "Bron bekor qilindi"))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _rescheduleBooking(
      BarberBooking booking, String currentDate, String barberId) async {
    final initialDate = DateTime.tryParse(currentDate) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final parts = booking.time.split(':');
    final initTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final pickedTime =
        await showTimePicker(context: context, initialTime: initTime);
    if (pickedTime == null) return;
    final newDate =
        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    final newTime =
        "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
    try {
      await ref
          .read(bookingRepositoryProvider)
          .reschedule(booking.id, date: newDate, time: newTime);
      _refreshDay(barberId);
      ref.invalidate(barberAllBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', "Saqlandi"))));
    } on DioException catch (e) {
      if (!mounted) return;
      // Backend reschedule throws ConflictException with
      // {code: 'SLOT_TAKEN'} when the new slot is already booked.
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final msg = code == 'SLOT_TAKEN' || e.response?.statusCode == 409
          ? tr(ref, 'booking.slotTaken', "Bu vaqt allaqachon band qilingan")
          : tr(ref, 'common.error', 'Xatolik');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  Future<void> _extendBooking(BarberBooking booking, String barberId) async {
    int minutes = 30;
    final ok = await showDialog<int>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'mobile.shop.barber.extendTitle',
            "Vaqtni uzaytirish (daqiqa)")),
        content: StatefulBuilder(builder: (sCtx, setSt) {
          return DropdownButtonFormField<int>(
            initialValue: minutes,
            items: const [
              DropdownMenuItem(value: 15, child: Text("+15")),
              DropdownMenuItem(value: 30, child: Text("+30")),
              DropdownMenuItem(value: 45, child: Text("+45")),
              DropdownMenuItem(value: 60, child: Text("+60")),
              DropdownMenuItem(value: 90, child: Text("+90")),
            ],
            onChanged: (v) => setSt(() => minutes = v ?? 30),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, minutes),
              child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
        ],
      ),
    );
    if (ok == null) return;
    try {
      await ref
          .read(barberPanelRepositoryProvider)
          .extendDuration(booking.id, ok);
      _refreshDay(barberId);
      ref.invalidate(barberAllBookingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', "Saqlandi"))));
    } on DioException catch (e) {
      if (!mounted) return;
      // Backend extend throws {code: 'MIN_DURATION', minMinutes: N} when
      // the extra-minutes value would shrink the booking below the
      // barber's slot duration (bookings.service.ts:1645). Surface the
      // limit so the barber knows why the extend didn't apply.
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final minMinutes = body is Map ? body['minMinutes'] : null;
      String msg;
      if (code == 'MIN_DURATION' && minMinutes is num) {
        msg = tr(ref, 'barberApp.shrinkMinError',
            'Davomiyligi {{min}} daqiqadan kam bo\'lmasligi kerak',
            {'min': '${minMinutes.toInt()}'});
      } else if (code == 'SLOT_TAKEN' || e.response?.statusCode == 409) {
        msg = tr(ref, 'booking.slotTaken',
            "Bu vaqt allaqachon band qilingan");
      } else {
        msg = tr(ref, 'common.error', 'Xatolik');
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  /// Manual booking dialog — barber types client name + phone, selects
  /// services from their list, and submits POST /bookings/manual with the
  /// pre-filled time.
  Future<void> _openManualBookingDialog(String barberId, String dateStr, String time) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final services =
        await ref.read(barberPanelRepositoryProvider).servicesForBarber(barberId);
    if (!mounted) return;
    final selected = <String>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                Row(children: [
                  Expanded(
                    child: Text(
                        tr(ref, 'mobile.barber.schedule.addClientForTime',
                            "{{time}} uchun mijoz qo'shish",
                            {'time': time}),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textBright)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await _pickContact();
                      if (picked == null) return;
                      setSheet(() {
                        if (picked.name.isNotEmpty) nameCtrl.text = picked.name;
                        if (picked.phone.isNotEmpty) phoneCtrl.text = picked.phone;
                      });
                    },
                    icon: const Icon(Icons.perm_contact_calendar_outlined, size: 16),
                    label: Text(tr(ref, 'mobile.barber.schedule.contact', "Kontakt")),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.barber.schedule.clientName', "Mijoz ismi")),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.barber.schedule.phoneOptional', "Telefon (ixtiyoriy)")),
                  onChanged: (v) async {
                    final cleaned = v.replaceAll(RegExp(r'[^\d+]'), '');
                    // Mirror web: only probe when we have a plausibly
                    // complete phone (8+ digits / +998xxxxxxxxx).
                    if (cleaned.length < 8) return;
                    if (nameCtrl.text.trim().isNotEmpty) return;
                    final hit = await ref
                        .read(barberPanelRepositoryProvider)
                        .lookupClientByPhone(
                            barberId: barberId, phone: cleaned);
                    if (hit != null && hit.name.isNotEmpty &&
                        nameCtrl.text.trim().isEmpty) {
                      setSheet(() => nameCtrl.text = hit.name);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  Text(tr(ref, 'mobile.barber.schedule.noServicesSet', "Xizmatlar belgilanmagan"),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12))
                else ...[
                  Text(tr(ref, 'booking.service', "Xizmat"),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
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
                    onPressed: () => Navigator.of(sheetCtx).pop(true),
                    child: Text(tr(ref, 'common.save', "Saqlash")),
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
      // Snapshot the FULL service rows the backend expects (price + duration
      // come from these, not from a lookup). Sending just IDs left
      // totalPrice/totalDuration at 0 and the booking with empty service rows.
      final picked = services
          .where((s) => selected.contains((s['id'] ?? '').toString()))
          .toList();
      final fullServices = picked
          .map((s) => {
                'id': s['id'],
                'name': s['name'] ?? s['nameUz'] ?? '',
                'nameUz': s['nameUz'] ?? s['name'] ?? '',
                'nameRu': s['nameRu'] ?? '',
                'price': s['price'] ?? 0,
                'duration': s['duration'] ?? 30,
                'icon': s['icon'] ?? '',
              })
          .toList();
      final totalPrice = picked.fold<int>(
          0, (a, s) => a + ((s['price'] ?? 0) as num).toInt());
      final totalDuration = picked.fold<int>(
          0, (a, s) => a + ((s['duration'] ?? 30) as num).toInt());
      await ref.read(barberPanelRepositoryProvider).createManual(
            barberId: barberId,
            date: dateStr,
            time: time,
            services: fullServices,
            totalPrice: totalPrice,
            totalDuration: totalDuration,
            guestName: nameCtrl.text.trim(),
            guestPhone: phoneCtrl.text.trim(),
          );
      _refreshDay(barberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'mobile.barber.schedule.clientAdded', "Mijoz qo'shildi"))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _openAddSchedule(String barberId) async {
    // Pick: generator or single slot
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(tr(ref, 'mobile.barber.schedule.addSchedule', "Jadval qo'shish"),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textBright)),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.auto_awesome_motion, color: AppColors.primary),
            title: Text(tr(ref, 'mobile.barber.schedule.autoInterval', "Avtomatik (vaqt oralig'i)")),
            subtitle: Text(tr(ref, 'mobile.barber.schedule.autoIntervalHint', "Boshlanish va tugash vaqtidan slotlar generatsiya")),
            onTap: () => Navigator.of(sheetCtx).pop('generator'),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: AppColors.primary),
            title: Text(tr(ref, 'mobile.barber.schedule.singleSlot', "Bitta slot qo'shish")),
            subtitle: Text(tr(ref, 'mobile.barber.schedule.singleSlotHint', "Aniq bir HH:MM vaqtni qo'shish")),
            onTap: () => Navigator.of(sheetCtx).pop('single'),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (choice == 'single') {
      if (!mounted) return;
      final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (picked == null) return;
      final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      try {
        final dateStr = _dateStr(_selectedDate);
        final current = await ref.read(barberPanelRepositoryProvider).getDaySchedule(barberId, dateStr);
        if (current.contains(time)) return;
        final updated = [...current, time]..sort();
        await ref.read(barberPanelRepositoryProvider)
            .saveDaySchedule(barberId: barberId, date: dateStr, slots: updated);
        _refreshDay(barberId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } else if (choice == 'generator') {
      if (mounted) context.push('/barber/schedule-generator');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final barberId = user.id;
    final dateStr = _dateStr(_selectedDate);
    final key = (barberId: barberId, date: dateStr);

    final slotsAsync = ref.watch(scheduleSlotsProvider(key));
    final bookedAsync = ref.watch(bookedSlotsProvider(key));
    final blockedAsync = ref.watch(blockedSlotsProvider(key));

    final months = trList(ref, 'mobile.dates.months', _months);
    final weekDays = trList(ref, 'mobile.dates.weekDaysShort', _weekDays);
    final weekDaysLong = trList(ref, 'mobile.dates.weekDaysLong', _weekDaysLong);
    final selectedWeekday = weekDaysLong[_selectedDate.weekday - 1];
    final dateHeader = "${_selectedDate.day}-${months[_selectedDate.month - 1].toLowerCase()}, ${selectedWeekday.toLowerCase()}";

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ===== Voice booking card =====
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _voiceLoading ? null : () => _toggleRecording(barberId),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isRecording
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRecording
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isRecording
                            ? "Yozilmoqda..."
                            : (_voiceLoading ? "Tahlil qilinmoqda..." : "Ovoz bilan bron"),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBright),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isRecording
                            ? "To'xtatish uchun yana bosing"
                            : "Mikrofonni bosib, ismni, vaqtni ayting",
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording ? AppColors.danger : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _voiceLoading
                      ? const Center(
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        )
                      : Icon(_isRecording ? Icons.mic_off : Icons.mic, color: Colors.white, size: 22),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 14),

          // ===== Date scroller (30 days) =====
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, i) {
                final d = DateTime.now().add(Duration(days: i));
                final dateOnly = DateTime(d.year, d.month, d.day);
                final selectedOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                final isSelected = dateOnly.isAtSameMomentAs(selectedOnly);
                final isToday = i == 0;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _selectedDate = dateOnly),
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isToday ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekDays[d.weekday - 1].toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white70 : AppColors.textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.day.toString(),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : AppColors.textBright),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            months[d.month - 1].substring(0, 3).toLowerCase(),
                            style: TextStyle(
                                fontSize: 10,
                                color: isSelected ? Colors.white70 : AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // ===== Day header =====
          Text(dateHeader,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textBright)),
          const SizedBox(height: 10),

          // ===== Slot grid OR empty state =====
          slotsAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
            ),
            data: (slots) {
              if (slots.isEmpty) {
                // Empty state — dashed box + button
                return _EmptyState(onAdd: () => _openAddSchedule(barberId));
              }

              final booked = bookedAsync.maybeWhen(data: (v) => v, orElse: () => <String>[]);
              final blocked = blockedAsync.maybeWhen(data: (v) => v, orElse: () => <String>[]);

              return Column(children: [
                // Legend + Add button
                Row(children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      children: [
                        _LegendDot(
                            color: const Color(0xFF22C55E),
                            label: tr(ref, 'mobile.barber.schedule.legendFree', "Bo'sh")),
                        _LegendDot(
                            color: const Color(0xFF3B82F6),
                            label: tr(ref, 'mobile.barber.schedule.legendBooked', "Band")),
                        _LegendDot(
                            color: const Color(0xFFEF4444),
                            label: tr(ref, 'mobile.barber.schedule.legendBlocked', "Bloklangan")),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _openAddSchedule(barberId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(tr(ref, 'mobile.barber.schedule.add', "Qo'shish"),
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),

                const SizedBox(height: 10),

                // 3-column slot grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final time = slots[i];
                    final status = _slotStatus(time, booked, blocked);
                    final color = status == 'booked'
                        ? const Color(0xFF3B82F6)
                        : status == 'blocked'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF22C55E);
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _openSlotAction(barberId, time, status),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Stack(children: [
                          Center(
                            child: Text(time,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                          ),
                          if (status == 'blocked')
                            Positioned(
                              top: 2, right: 4,
                              child: Icon(Icons.lock, size: 11, color: color.withValues(alpha: 0.7)),
                            ),
                          if (status == 'booked')
                            Positioned(
                              top: 2, right: 4,
                              child: Text(
                                  tr(ref, 'mobile.barber.schedule.legendBooked', "Band").toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 8, fontWeight: FontWeight.w800, color: color)),
                            ),
                        ]),
                      ),
                    ).animate().fadeIn(duration: 150.ms, delay: (i * 15).ms);
                  },
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  /// Open the OS contact picker and return the first chosen contact's
  /// (name, phone) tuple. Returns `null` on cancel or denied permission.
  /// Phone is normalised to digits-only with optional leading "+".
  Future<_PickedContact?> _pickContact() async {
    // The picker itself is permissionless on both platforms, BUT to read the
    // chosen contact's phone numbers on Android we need READ_CONTACTS.
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    final hasPerm = status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'mobile.barber.schedule.contactsDenied',
                "Kontaktlarga ruxsat berilmadi"))));
      }
      return null;
    }
    try {
      final c = await FlutterContacts.native
          .showPicker(properties: {ContactProperty.name, ContactProperty.phone});
      if (c == null) return null;
      final name = (c.displayName ?? '').trim();
      final phone = (c.phones.isNotEmpty ? c.phones.first.number : '')
          .replaceAll(RegExp(r'[^\d+]'), '');
      return _PickedContact(name: name, phone: phone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'mobile.barber.schedule.contactReadError', "Kontaktni o'qib bo'lmadi")}: $e")));
      }
      return null;
    }
  }
}

class _PickedContact {
  const _PickedContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(children: [
        const Icon(Icons.access_time, color: AppColors.textMuted, size: 40),
        const SizedBox(height: 8),
        Text(tr(ref, 'mobile.barber.schedule.empty', "Jadval yo'q"),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textBright)),
        const SizedBox(height: 4),
        Text(tr(ref, 'mobile.barber.schedule.emptyHint', "Ish vaqtingizni belgilang"),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(tr(ref, 'mobile.barber.schedule.addSchedule', "Jadval qo'shish")),
            onPressed: onAdd,
          ),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
    ]);
  }
}
