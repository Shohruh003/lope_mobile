import 'package:dio/dio.dart';
import '../../../core/errors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../bookings/data/booking_repository.dart';
import '../../shop_panel/data/shop_repository.dart';
import '../data/barber_panel_repository.dart';

class BarberScheduleScreen extends ConsumerStatefulWidget {
  const BarberScheduleScreen({super.key, this.barberId});

  /// Explicit barber to view вЂ” null means "use the logged-in user's
  /// id" (self-view for a barber). Populated when a barbershop admin
  /// opens `/shop/barbers/:id` and drills into a specific barber's
  /// schedule; the whole screen is reused so the shop admin gets the
  /// same voice-input, date strip, close-day / add-schedule and slot
  /// grid as the barber themselves.
  final String? barberId;

  @override
  ConsumerState<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends ConsumerState<BarberScheduleScreen>
    with WidgetsBindingObserver {
  late DateTime _selectedDate;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final id = _resolveBarberId();
    if (id == null) return;
    final key = (barberId: id, date: _dateStr(_selectedDate));
    ref.invalidate(scheduleSlotsProvider(key));
    ref.invalidate(bookedSlotsProvider(key));
    ref.invalidate(blockedSlotsProvider(key));
  }

  /// Explicit `widget.barberId` wins (shop admin viewing a specific
  /// master); otherwise fall back to the logged-in user's id (barber
  /// self-view).
  String? _resolveBarberId() {
    final override = widget.barberId;
    if (override != null && override.isNotEmpty) return override;
    return ref.read(authControllerProvider).user?.id;
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
          // Backend returns the parsed intent — mobile was throwing
          // the result away and just toasting 'Ovoz qabul qilindi',
          // so the barber recorded a booking and nothing happened.
          // Handle the 'booking' intent (most common: 'ertaga soat
          // 3 da Ali') by opening the manual booking sheet pre-filled
          // with the parsed name/phone/time. Other intents (schedule,
          // single_slot, delete_slots) surface a snack asking the
          // barber to use the buttons — full parity with the web
          // frontend can come later.
          final result = await ref
              .read(barberPanelRepositoryProvider)
              .parseVoiceBooking(barberId: barberId, audioPath: path);
          if (!mounted) return;
          setState(() => _voiceLoading = false);
          final intent = (result['intent'] ?? '').toString();
          if (intent == 'booking') {
            final name = (result['name'] ?? '').toString();
            final phone = (result['phone'] ?? '').toString();
            final date = (result['date'] ?? '').toString();
            final time = (result['time'] ?? '').toString();
            if (name.isEmpty && phone.isEmpty && time.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr(ref,
                      'mobile.barber.schedule.voiceEmpty',
                      "Ovozdan mijoz aniqlanmadi"))));
              return;
            }
            final targetDate = date.isNotEmpty ? date : _dateStr(_selectedDate);
            final targetTime = time.isNotEmpty ? time : '10:00';
            // Sync visible day to the parsed date so, once the sheet
            // closes and we refresh, the barber sees the new booking.
            if (date.isNotEmpty) {
              final parts = date.split('-');
              if (parts.length == 3) {
                final y = int.tryParse(parts[0]);
                final m = int.tryParse(parts[1]);
                final d = int.tryParse(parts[2]);
                if (y != null && m != null && d != null) {
                  setState(() => _selectedDate = DateTime(y, m, d));
                }
              }
            }
            // Normalize '998...' phone from Gemini into '+998...'.
            final normalizedPhone = phone.startsWith('998')
                ? '+$phone'
                : phone;
            await _openManualBookingDialog(barberId, targetDate, targetTime,
                prefillName: name.isEmpty ? null : name,
                prefillPhone: normalizedPhone.isEmpty ? null : normalizedPhone);
            if (!mounted) return;
            _refreshDay(barberId);
            return;
          }
          // Non-booking intents — MVP surfaces a helpful hint instead
          // of silently claiming success.
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(ref,
                  'mobile.barber.schedule.voiceUnsupported',
                  "Ovoz qabul qilindi, lekin faqat mijoz yozish ishlaydi. Jadval qo'shish uchun '+' tugmasidan foydalaning."))));
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
          }
        }
      }
      if (!mounted) return;
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
      // Web has no filesystem so `getTemporaryDirectory` throws a
      // MissingPluginException there. On web `record` writes to an
      // in-memory Blob and returns the URL from `stop()`, so we skip
      // the temp path entirely; on mobile we still write to a real
      // file so upload can stream it.
      final String path;
      if (kIsWeb) {
        path = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        final dir = await getTemporaryDirectory();
        path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
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
    AppHaptics.selection();
    // If the slot is booked, pre-fetch the booking so we can render
    // client name / phone / services right in the sheet header вЂ”
    // otherwise the barber had no way to see WHO was booked at that
    // time without cancelling first.
    BarberBooking? booking;
    if (status == 'booked') {
      try {
        final list = await ref
            .read(barberPanelRepositoryProvider)
            .byDay(barberId: barberId, date: _dateStr(_selectedDate));
        for (final b in list) {
          if (b.time == time && b.status != 'cancelled') {
            booking = b;
            break;
          }
        }
      } catch (_) {
        // Non-fatal вЂ” sheet still opens with the action buttons.
      }
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      // isScrollControlled + inner SingleChildScrollView so the sheet
      // grows past its default half-screen limit when the booked
      // client card is stacked on top of every action tile. Without
      // this the tall booking sheet clipped its last action (Yopish)
      // and Flutter painted the yellow/black overflow ribbon.
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: AppSpacing.md),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(Icons.schedule, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(time, style: AppText.titleMd)),
            ]),
          ),
          if (booking != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl),
              child: _BookedClientCard(booking: booking),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (status == 'available')
            _SheetAction(
              icon: Icons.person_add_alt_1,
              tint: AppColors.primary,
              title: tr(ref, 'mobile.barber.schedule.addClient', "Mijoz qo'shish"),
              subtitle: tr(ref, 'mobile.barber.schedule.manualBooking', "Mijoz yozish"),
              onTap: () => Navigator.of(sheetCtx).pop('book'),
            ),
          if (status == 'booked') ...[
            _SheetAction(
              icon: Icons.check_circle_outline,
              tint: AppColors.success,
              title: tr(ref, 'myBookings.complete', "Yakunlash"),
              onTap: () => Navigator.of(sheetCtx).pop('complete'),
            ),
            _SheetAction(
              icon: Icons.event_repeat,
              tint: AppColors.primary,
              title: tr(ref, 'mobile.shop.barber.reschedule', "Boshqa vaqtga ko'chirish"),
              onTap: () => Navigator.of(sheetCtx).pop('reschedule'),
            ),
            _SheetAction(
              icon: Icons.timer_outlined,
              tint: AppColors.primary,
              title: tr(ref, 'mobile.shop.barber.extend', "Vaqtni uzaytirish"),
              onTap: () => Navigator.of(sheetCtx).pop('extend'),
            ),
            _SheetAction(
              icon: Icons.close,
              tint: AppColors.danger,
              title: tr(ref, 'myBookings.cancel', "Bekor qilish"),
              onTap: () => Navigator.of(sheetCtx).pop('cancelBooking'),
            ),
          ],
          if (status != 'blocked' && status != 'booked')
            _SheetAction(
              icon: Icons.lock_outline,
              tint: AppColors.danger,
              title: tr(ref, 'mobile.barber.schedule.blockSlot', "Slotni bloklash"),
              onTap: () => Navigator.of(sheetCtx).pop('block'),
            ),
          if (status == 'blocked')
            _SheetAction(
              icon: Icons.lock_open,
              tint: AppColors.success,
              title: tr(ref, 'mobile.barber.schedule.unblockSlot', "Blokni olib tashlash"),
              onTap: () => Navigator.of(sheetCtx).pop('unblock'),
            ),
          _SheetAction(
            icon: Icons.delete_outline,
            tint: AppColors.danger,
            title: tr(ref, 'mobile.barber.schedule.deleteSlot', "Slotni o'chirish"),
            onTap: () => Navigator.of(sheetCtx).pop('delete'),
          ),
          _SheetAction(
            icon: Icons.close,
            tint: context.colors.textMuted,
            title: tr(ref, 'common.close', "Yopish"),
            onTap: () => Navigator.of(sheetCtx).pop(null),
          ),
          const SizedBox(height: AppSpacing.md),
        ]),
        ),
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
        // Confirm before removing the slot вЂ” the previous flow
        // deleted it immediately with no undo, easy to mis-tap on.
        if (!mounted) return;
        final ok = await _confirmDeleteSlot(time);
        if (ok != true) return;
        final current = await repo.getDaySchedule(barberId, dateStr);
        final updated = current.where((t) => t != time).toList();
        await repo.saveDaySchedule(
            barberId: barberId, date: dateStr, slots: updated);
      }
      _refreshDay(barberId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  /// Confirm-before-delete dialog for a single schedule slot. Same
  /// visual language as the gallery / booking cancel dialogs so
  /// destructive actions share one confirmation UI.
  Future<bool?> _confirmDeleteSlot(String time) {
    AppHaptics.light();
    return showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 22),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Text(
                    tr(
                        ref,
                        'mobile.barber.schedule.deleteSlotTitle',
                        "Slotni o'chirish?"),
                    style: AppText.titleMd,
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              Text(
                tr(
                    ref,
                    'mobile.barber.schedule.deleteSlotBody',
                    "{{time}} vaqti jadvaldan olib tashlanadi. Bu jarayonni bekor qilib bo'lmaydi.",
                    {'time': time}),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx, false),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.delete', "O'chirish"),
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.pop(dCtx, true),
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

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
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            isComplete
                ? tr(ref, 'myBookings.completeConfirmTitle', "Bronni yakunlash?")
                : tr(ref, 'myBookings.cancelConfirmTitle', "Bronni bekor qilasizmi?"),
            style: AppText.titleMd),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              isComplete
                  ? tr(ref, 'myBookings.completeConfirmMsg', "Bron yakunlangan deb belgilanadi.")
                  : tr(ref, 'myBookings.cancelConfirmMsg', "Bekor qilingach, qaytarib bo'lmaydi."),
              style: AppText.body),
          if (isComplete) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr(ref, 'myBookings.totalPriceLabel', "Olingan summa (ixtiyoriy)"),
                hintText: '0',
                suffixText: tr(ref, 'common.currency', "so'm"),
              ),
            ),
          ],
        ]),
        actions: [
          // "Yo'q" (no) / "Ha" (yes) instead of the confusing double-
          // "Bekor qilish" pair вЂ” one meant close-the-dialog and the
          // other meant cancel-the-booking, and they read identically.
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.no', "Yo'q"))),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: isComplete ? null : AppColors.danger),
              onPressed: () {
                if (isComplete) {
                  overrideTotal = int.tryParse(priceCtrl.text.trim());
                }
                Navigator.pop(dCtx, true);
              },
              child: Text(tr(ref, 'common.yes', 'Ha'))),
        ],
      ),
    );
    try {
      if (ok != true) return;
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
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      priceCtrl.dispose();
    }
  }

  Future<void> _rescheduleBooking(
      BarberBooking booking, String currentDate, String barberId) async {
    final initialDate = DateTime.tryParse(currentDate) ?? DateTime.now();
    final pickedDate = await AppDatePicker.show(
      context,
      ref: ref,
      initial: initialDate,
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
        await AppTimePicker.show(context, ref: ref, initial: initTime);
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
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final msg = code == 'SLOT_TAKEN' || e.response?.statusCode == 409
          ? tr(ref, 'booking.slotTaken', "Bu vaqt allaqachon band qilingan")
          : tr(ref, 'common.error', 'Xatolik');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  /// Humanises a minute delta ("+15 daq", "-1 soat", "+2 soat 30 daq")
  /// for the extend wheel picker so the labels stay readable when the
  /// delta grows past an hour.
  String _extendLabel(int m, WidgetRef ref) {
    final sign = m < 0 ? '-' : '+';
    final abs = m.abs();
    final h = abs ~/ 60;
    final rem = abs % 60;
    final soat = tr(ref, 'common.hourShort', 'soat');
    final daq = tr(ref, 'booking.duration', 'daq');
    if (h == 0) return '$sign$abs $daq';
    if (rem == 0) return '$sign$h $soat';
    return '$sign$h $soat $rem $daq';
  }

  Future<void> _extendBooking(BarberBooking booking, String barberId) async {
    // Wheel picker over 15-minute steps вЂ” matches the AppTimePicker /
    // AppDatePicker widget-family so all pickers in the app feel like
    // one system. Values run from -120 to +180 in 15-min increments;
    // the barber scrolls the wheel to pick either a shrink (negative)
    // or extend (positive) delta.
    final values = <int>[];
    for (var v = -120; v <= 180; v += 15) {
      if (v == 0) continue;
      values.add(v);
    }
    // Start at +30 (the default extend), or clamp to a value that
    // wouldn't push the booking below 15 min.
    int minutes = 30;
    final initialIndex = values.indexOf(minutes);
    final ok = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final colors = sheetCtx.colors;
        final controller =
            FixedExtentScrollController(initialItem: initialIndex);
        return StatefulBuilder(builder: (sCtx, setSt) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 12, AppSpacing.lg, AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.rMd,
                        ),
                        child: const Icon(Icons.timer_outlined,
                            color: AppColors.primary, size: 22),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Text(
                          tr(ref, 'mobile.shop.barber.extendTitle',
                              "Vaqtni sozlash"),
                          style: AppText.titleMd,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                          ref,
                          'mobile.shop.barber.extendHint',
                          "Bronni cho'zish yoki qisqartirish uchun vaqtni tanlang"),
                      style: AppText.bodySm
                          .copyWith(color: colors.textMuted),
                    ),
                    AppSpacing.gapLg,
                    SizedBox(
                      height: 216,
                      child: Stack(children: [
                        // Cupertino-style center highlight bar so the
                        // currently-selected delta stands out at a
                        // glance вЂ” matches the AppDatePicker wheel.
                        IgnorePointer(
                          ignoring: true,
                          child: Center(
                            child: Container(
                              height: 44,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xxl),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: AppRadius.rMd,
                              ),
                            ),
                          ),
                        ),
                        ListWheelScrollView.useDelegate(
                          controller: controller,
                          itemExtent: 44,
                          perspective: 0.005,
                          diameterRatio: 1.4,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (i) => setSt(() {
                            minutes = values[i];
                          }),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: values.length,
                            builder: (context, index) {
                              final v = values[index];
                              final selected = v == minutes;
                              final label = _extendLabel(v, ref);
                              return Center(
                                child: Text(
                                  label,
                                  style: AppText.body.copyWith(
                                    fontSize: selected ? 22 : 20,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: selected
                                        ? (v < 0
                                            ? AppColors.danger
                                            : AppColors.primary)
                                        : colors.textMuted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
                    AppSpacing.gapLg,
                    Row(children: [
                      Expanded(
                        child: AppButton(
                          label: tr(ref, 'common.cancel', 'Bekor'),
                          variant: AppButtonVariant.secondary,
                          onPressed: () =>
                              Navigator.of(sheetCtx).pop(),
                          fullWidth: true,
                        ),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: AppButton(
                          label:
                              tr(ref, 'common.confirm', 'Tasdiqlash'),
                          variant: AppButtonVariant.primary,
                          onPressed: () =>
                              Navigator.of(sheetCtx).pop(minutes),
                          fullWidth: true,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
    if (ok == null) return;
    // Guard: refuse deltas that would drop the booking below 15
    // minutes total вЂ” otherwise the barber can shrink a 30-min
    // booking by -45 and end up with a negative duration.
    if (booking.totalDuration + ok < 15) {
      if (!mounted) return;
      AppSnack.warning(
          context,
          tr(ref, 'mobile.shop.barber.extendTooShort',
              "Bron davomiyligi juda qisqarib ketadi"));
      return;
    }
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
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final minMinutes = body is Map ? body['minMinutes'] : null;
      String msg;
      if (code == 'MIN_DURATION' && minMinutes is num) {
        msg = tr(ref, 'barberApp.shrinkMinError',
            'Davomiyligi {{min}} daqiqadan kam bo\'lmasligi kerak',
            {'min': '${minMinutes.toInt()}'});
      } else if (code == 'SLOT_TAKEN' || e.response?.statusCode == 409) {
        msg = tr(ref, 'booking.slotTaken', "Bu vaqt allaqachon band qilingan");
      } else {
        msg = tr(ref, 'common.error', 'Xatolik');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  Future<void> _openManualBookingDialog(String barberId, String dateStr, String time,
      {String? prefillName, String? prefillPhone}) async {
    final nameCtrl = TextEditingController(text: prefillName ?? '');
    final phoneCtrl = TextEditingController(text: prefillPhone ?? '');
    final services =
        await ref.read(barberPanelRepositoryProvider).servicesForBarber(barberId);
    if (!mounted) return;
    final selected = <String>{};

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.lg,
            bottom: AppSpacing.xl + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: context.colors.border,
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: Text(
                        tr(ref, 'mobile.barber.schedule.addClientForTime',
                            "{{time}} uchun mijoz qo'shish",
                            {'time': time}),
                        style: AppText.titleMd),
                  ),
                  TapScale(
                    onTap: () async {
                      final picked = await _pickContact();
                      if (picked == null) return;
                      setSheet(() {
                        if (picked.name.isNotEmpty) nameCtrl.text = picked.name;
                        if (picked.phone.isNotEmpty) {
                          // Route the imported number through the phone
                          // field's normaliser so it lands as the same
                          // canonical +998 XX-XXX-XX-XX display,
                          // regardless of the format the contact was
                          // stored in.
                          final digits = AppPhoneField.extractDigits(
                              picked.phone);
                          final formatted =
                              AppPhoneField.formatDisplay(digits);
                          phoneCtrl.text = formatted.isEmpty
                              ? '+998'
                              : '+998 $formatted';
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.rMd,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.perm_contact_calendar_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                            tr(ref, 'mobile.barber.schedule.contact', "Kontakt"),
                            style: AppText.button.copyWith(
                                color: AppColors.primary, fontSize: 12)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.barber.schedule.clientName', "Mijoz ismi")),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppPhoneField(
                  controller: phoneCtrl,
                  hintText: tr(ref,
                      'mobile.barber.schedule.phoneOptional',
                      "Telefon (ixtiyoriy)"),
                  onChanged: (_) async {
                    // Auto-fill the name from an existing client match
                    // once we have the full 9-digit local part. The
                    // display is formatted, so read the raw digits
                    // through the widget's helper instead of stripping
                    // by hand.
                    final digits =
                        AppPhoneField.extractDigits(phoneCtrl.text);
                    if (digits.length != 9) return;
                    if (nameCtrl.text.trim().isNotEmpty) return;
                    final hit = await ref
                        .read(barberPanelRepositoryProvider)
                        .lookupClientByPhone(
                            barberId: barberId, phone: '+998$digits');
                    if (hit != null &&
                        hit.name.isNotEmpty &&
                        nameCtrl.text.trim().isEmpty) {
                      setSheet(() => nameCtrl.text = hit.name);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                if (services.isEmpty)
                  Text(
                      tr(ref, 'mobile.barber.schedule.noServicesSet', "Xizmatlar belgilanmagan"),
                      style: AppText.caption)
                else ...[
                  Text(tr(ref, 'booking.service', "Xizmat"),
                      style: AppText.overline
                          .copyWith(color: context.colors.textSecondary)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: services.map((s) {
                      final id = s['id'] as String;
                      final name = (s['nameUz'] ?? s['name'] ?? '').toString();
                      final on = selected.contains(id);
                      return AppChip(
                        label: name,
                        selected: on,
                        onTap: () => setSheet(() {
                          if (on) {
                            selected.remove(id);
                          } else {
                            selected.add(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: tr(ref, 'common.save', "Saqlash"),
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      if (saved != true) return;
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
            // Send the canonical `+998XXXXXXXXX` string instead of the
            // display value ('+998 90-123-45-67') вЂ” the phone field
            // now renders with spaces and dashes so the raw controller
            // text isn't a valid E.164 number by itself.
            guestPhone: AppPhoneField.rawPhone(phoneCtrl.text),
          );
      _refreshDay(barberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(ref, 'mobile.barber.schedule.clientAdded', "Mijoz qo'shildi"))));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final msg = code == 'SLOT_TAKEN' || e.response?.statusCode == 409
          ? tr(ref, 'booking.slotTaken', "Bu vaqt allaqachon band qilingan")
          : tr(ref, 'common.error', 'Xatolik');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  Future<void> _confirmCloseDay(String barberId) async {
    final dateStr = _dateStr(_selectedDate);
    final repo = ref.read(barberPanelRepositoryProvider);

    int activeBookings = 0;
    try {
      final bookings = await repo.byDay(barberId: barberId, date: dateStr);
      activeBookings = bookings.where((b) => b.status == 'confirmed').length;
    } catch (_) {}

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'mobile.barber.schedule.closeDayTitle', "Kunni yopamizmi?"),
            style: AppText.titleMd),
        content: Text(
          activeBookings > 0
              ? tr(
                  ref,
                  'mobile.barber.schedule.closeDayWithBookings',
                  "Bu kunda {{count}} ta bron bor. Ular bekor qilinadi va mijozlarga SMS/xabar boradi. Davom etamizmi?",
                  {'count': '$activeBookings'},
                )
              : tr(
                  ref,
                  'mobile.barber.schedule.closeDayNoBookings',
                  "Bu kundagi barcha slotlar o'chiriladi. Davom etamizmi?",
                ),
          style: AppText.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: Text(tr(ref, 'common.cancel', "Bekor")),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'mobile.barber.schedule.closeDay', "Kunni yopish")),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final cancelled = await repo.closeDay(barberId: barberId, date: dateStr);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          cancelled > 0
              ? tr(
                  ref,
                  'mobile.barber.schedule.closedWithCancels',
                  "Kun yopildi. {{count}} ta bron bekor qilindi.",
                  {'count': '$cancelled'},
                )
              : tr(ref, 'mobile.barber.schedule.closed', "Kun yopildi"),
        ),
      ));
      _refreshDay(barberId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}"),
      ));
    }
  }

  Future<void> _openAddSchedule(String barberId) async {
    AppHaptics.selection();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      // Bump the minimum height so the sheet occupies ~35% of the
      // screen instead of hugging the two tiles. User feedback: the
      // sheet felt cramped at the bottom edge and easy to miss.
      builder: (sheetCtx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(sheetCtx).size.height * 0.35,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl),
                  child: Text(
                      tr(ref, 'mobile.barber.schedule.addSchedule',
                          "Jadval qo'shish"),
                      style: AppText.titleMd),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SheetAction(
                  icon: Icons.auto_awesome_motion,
                  tint: AppColors.primary,
                  title: tr(ref, 'mobile.barber.schedule.autoInterval',
                      "Avtomatik (vaqt oralig'i)"),
                  subtitle: tr(ref, 'mobile.barber.schedule.autoIntervalHint',
                      "Boshlanish va tugash vaqtidan slotlar generatsiya"),
                  onTap: () => Navigator.of(sheetCtx).pop('generator'),
                ),
                _SheetAction(
                  icon: Icons.add,
                  tint: AppColors.primary,
                  title: tr(ref, 'mobile.barber.schedule.singleSlot',
                      "Bitta slot qo'shish"),
                  subtitle: tr(ref,
                      'mobile.barber.schedule.singleSlotHint',
                      "Aniq bir HH:MM vaqtni qo'shish"),
                  onTap: () => Navigator.of(sheetCtx).pop('single'),
                ),
                const SizedBox(height: AppSpacing.xl),
              ]),
        ),
      ),
    );
    if (choice == 'single') {
      if (!mounted) return;
      final picked = await AppTimePicker.show(context,
          ref: ref, initial: const TimeOfDay(hour: 9, minute: 0));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } else if (choice == 'generator') {
      if (!mounted) return;
      final dateStr = _dateStr(_selectedDate);
      // Prefill the generator with the currently viewed date so the
      // default range is that single day (previously todayв†’today+7,
      // silently creating a week when the barber only wanted one).
      // Awaiting the push lets us invalidate the slot provider on
      // return so the freshly generated schedule renders immediately.
      final result = await context.push<bool>(
          '/barber/schedule-generator?date=$dateStr');
      if (result == true && mounted) {
        _refreshDay(barberId);
      }
    }
  }

  /// AppBar only shown in the shop-admin push case. Uses the shop's
  /// barber list to render the master's avatar + name inline with the
  /// back button. Falls back to a generic 'Sartarosh' title while the
  /// list is still loading so the user isn't stuck on a blank bar.
  PreferredSizeWidget _buildShopAdminAppBar(
      BuildContext context, WidgetRef ref) {
    final id = widget.barberId!;
    final async = ref.watch(shopBarbersProvider);
    final barber = async.maybeWhen(
      data: (list) {
        for (final b in list) {
          if (b.id == id) return b;
        }
        return null;
      },
      orElse: () => null,
    );
    return AppBar(
      titleSpacing: 0,
      title: Row(children: [
        ClientAvatar(
          name: barber?.name ?? '',
          avatar: barber?.avatar,
          size: 32,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                barber?.name ??
                    tr(ref, 'mobile.shop.barberDetail.title',
                        'Sartarosh'),
                style: AppText.titleSm.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((barber?.phone ?? '').isNotEmpty &&
                  !(barber!.phone!.startsWith('shop:'))) ...[
                const SizedBox(height: 1),
                Text(
                  barber.phone!,
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barberId = _resolveBarberId();
    if (barberId == null) return const Scaffold(body: AppListSkeleton());
    final dateStr = _dateStr(_selectedDate);
    final key = (barberId: barberId, date: dateStr);

    final slotsAsync = ref.watch(scheduleSlotsProvider(key));
    final bookedAsync = ref.watch(bookedSlotsProvider(key));
    final blockedAsync = ref.watch(blockedSlotsProvider(key));
    // Full-booking data (with client name / phone / services) so the
    // slot tile can render "Shohruh Azimov" inline instead of just a
    // "BAND" badge that gives no idea who is booked.
    final dayBookingsAsync = ref.watch(barberDayBookingsProvider(key));

    final months = trList(ref, 'mobile.dates.months', _months);
    final weekDays = trList(ref, 'mobile.dates.weekDaysShort', _weekDays);
    final weekDaysLong = trList(ref, 'mobile.dates.weekDaysLong', _weekDaysLong);
    final selectedWeekday = weekDaysLong[_selectedDate.weekday - 1];
    final dateHeader =
        "${_selectedDate.day}-${months[_selectedDate.month - 1].toLowerCase()}, ${selectedWeekday.toLowerCase()}";

    // Shop admin viewing a specific master: show an AppBar with a
    // back button + the barber's name so the admin knows whose grid
    // this is and can pop back to the masters list. Barber self-view
    // keeps the previous headerless layout (this screen sits inside
    // the barber shell's tab, no AppBar needed).
    final isPushedView = widget.barberId != null;
    return Scaffold(
      appBar: isPushedView ? _buildShopAdminAppBar(context, ref) : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
        children: [
          _VoiceBookingCard(
            isRecording: _isRecording,
            loading: _voiceLoading,
            onTap: _voiceLoading ? null : () => _toggleRecording(barberId),
            titleIdle: tr(ref, 'mobile.barber.schedule.voiceTitle', "Ovoz bilan bron"),
            titleRecording: tr(ref, 'mobile.barber.schedule.voiceRecording', "Yozilmoqda..."),
            titleAnalysing: tr(ref, 'mobile.barber.schedule.voiceAnalysing', "Tahlil qilinmoqda..."),
            subtitleIdle: tr(ref, 'mobile.barber.schedule.voiceSubIdle',
                "Mikrofonni bosib, ismni, vaqtni ayting"),
            subtitleRecording: tr(ref, 'mobile.barber.schedule.voiceSubRec',
                "To'xtatish uchun yana bosing"),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, i) {
                final d = DateTime.now().add(Duration(days: i));
                final dateOnly = DateTime(d.year, d.month, d.day);
                final selectedOnly =
                    DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                final isSelected = dateOnly.isAtSameMomentAs(selectedOnly);
                final isToday = i == 0;

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _DatePill(
                    weekday: weekDays[d.weekday - 1],
                    day: d.day.toString(),
                    month: months[d.month - 1].substring(0, 3).toLowerCase(),
                    selected: isSelected,
                    today: isToday,
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => _selectedDate = dateOnly);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(dateHeader, style: AppText.titleSm),
          const SizedBox(height: AppSpacing.md),
          slotsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSkeleton(height: 56, borderRadius: AppRadius.md),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(height: 56, borderRadius: AppRadius.md),
                  SizedBox(height: AppSpacing.sm),
                  AppSkeleton(height: 56, borderRadius: AppRadius.md),
                ],
              ),
            ),
            error: (e, _) => SizedBox(
              height: 240,
              child: AppErrorState(message: humanize(e)),
            ),
            data: (slots) {
              if (slots.isEmpty) {
                return _EmptyState(onAdd: () => _openAddSchedule(barberId));
              }

              final booked = bookedAsync.maybeWhen(
                  data: (v) => v, orElse: () => <String>[]);
              final blocked = blockedAsync.maybeWhen(
                  data: (v) => v, orElse: () => <String>[]);
              // Full-booking list for the "Bugungi bronlar" card block
              // rendered below the slot grid.
              final bookings = dayBookingsAsync.maybeWhen(
                  data: (v) => v, orElse: () => <BarberBooking>[]);

              return Column(children: [
                AppCard(
                  variant: AppCardVariant.flat,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  // Legend on its own row (kept together, scales if
                  // ever too tight); action buttons below. Prior
                  // Row(Expanded(Wrap), action, action) let the Wrap
                  // break "Bo'sh Band" onto one line and "Bloklangan"
                  // onto a second line on narrow phones.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _LegendDot(
                              color: AppColors.success,
                              label: tr(ref, 'mobile.barber.schedule.legendFree', "Bo'sh")),
                          const SizedBox(width: AppSpacing.md),
                          _LegendDot(
                              color: AppColors.primary,
                              label: tr(ref, 'mobile.barber.schedule.legendBooked', "Band")),
                          const SizedBox(width: AppSpacing.md),
                          _LegendDot(
                              color: AppColors.danger,
                              label: tr(ref, 'mobile.barber.schedule.legendBlocked', "Bloklangan")),
                        ]),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(
                          child: _TinyAction(
                            icon: Icons.event_busy_outlined,
                            color: AppColors.danger,
                            label: tr(ref, 'mobile.barber.schedule.closeDay', "Kunni yopish"),
                            onTap: () => _confirmCloseDay(barberId),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: _TinyAction(
                            icon: Icons.add,
                            color: AppColors.primary,
                            label: tr(ref, 'mobile.barber.schedule.add', "Qo'shish"),
                            onTap: () => _openAddSchedule(barberId),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final time = slots[i];
                    final status = _slotStatus(time, booked, blocked);
                    return _SlotTile(
                      time: time,
                      status: status,
                      bookedLabel: tr(ref, 'mobile.barber.schedule.legendBooked', "Band"),
                      onTap: () => _openSlotAction(barberId, time, status),
                    ).animate().fadeIn(duration: 150.ms, delay: (i * 15).ms);
                  },
                ),
                // Bugungi bronlar ro'yxati вЂ” jadval ostida chiqadi.
                // Web frontend'dagi todayBookings blokining port'i:
                // barber slot ustiga bosmasidan ham bir qarashda kim
                // qachonga yozilganini ko'radi.
                if (bookings.any((b) => b.status != 'cancelled')) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _TodayBookingsList(
                    bookings: bookings
                        .where((b) => b.status != 'cancelled')
                        .toList()
                      ..sort((a, b) => a.time.compareTo(b.time)),
                    onTapBooking: (b) =>
                        _openSlotAction(barberId, b.time, 'booked'),
                  ),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }

  Future<_PickedContact?> _pickContact() async {
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
            content: Text("${tr(ref, 'mobile.barber.schedule.contactReadError', "Kontaktni o'qib bo'lmadi")}: ${humanize(e)}")));
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

/// Voice booking hero card with pulsing mic when recording.
class _VoiceBookingCard extends StatelessWidget {
  const _VoiceBookingCard({
    required this.isRecording,
    required this.loading,
    required this.onTap,
    required this.titleIdle,
    required this.titleRecording,
    required this.titleAnalysing,
    required this.subtitleIdle,
    required this.subtitleRecording,
  });

  final bool isRecording;
  final bool loading;
  final VoidCallback? onTap;
  final String titleIdle;
  final String titleRecording;
  final String titleAnalysing;
  final String subtitleIdle;
  final String subtitleRecording;

  @override
  Widget build(BuildContext context) {
    final gradient = isRecording
        ? LinearGradient(
            colors: [
              AppColors.danger.withValues(alpha: 0.18),
              AppColors.danger.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.14),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = isRecording
        ? AppColors.danger.withValues(alpha: 0.4)
        : AppColors.primary.withValues(alpha: 0.25);
    final micColor = isRecording ? AppColors.danger : AppColors.primary;

    final title = loading
        ? titleAnalysing
        : (isRecording ? titleRecording : titleIdle);
    final subtitle = isRecording ? subtitleRecording : subtitleIdle;

    Widget micBtn = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: micColor,
        shape: BoxShape.circle,
        boxShadow: AppShadows.primaryGlow(micColor),
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white)),
            )
          : Icon(isRecording ? Icons.mic_off : Icons.mic,
              color: Colors.white, size: 24),
    );
    if (isRecording) {
      micBtn = micBtn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
              duration: 700.ms,
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
              curve: Curves.easeInOut);
    }

    return AppCard(
      onTap: onTap,
      gradient: gradient,
      borderColor: borderColor,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: micColor.withValues(alpha: 0.15),
            borderRadius: AppRadius.rMd,
          ),
          child: Icon(Icons.graphic_eq, color: micColor, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleSm),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppText.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        micBtn,
      ]),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.weekday,
    required this.day,
    required this.month,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = selected ? AppColors.primaryGradient : null;
    final borderColor = selected
        ? Colors.transparent
        : (today
            ? AppColors.primary.withValues(alpha: 0.4)
            : context.colors.border);
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.none,
      child: Container(
        width: 62,
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          gradient: gradient,
          color: selected ? null : context.colors.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: borderColor),
          boxShadow: selected
              ? AppShadows.primaryGlow(AppColors.primary)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday,
                style: AppText.overline.copyWith(
                    fontSize: 10,
                    color: selected ? Colors.white70 : context.colors.textMuted)),
            const SizedBox(height: 2),
            Text(day,
                style: AppText.numeric.copyWith(
                    fontSize: 20,
                    color: selected ? Colors.white : context.colors.textBright)),
            const SizedBox(height: 2),
            Text(month,
                style: AppText.overline.copyWith(
                    fontSize: 10,
                    color: selected ? Colors.white70 : context.colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.time,
    required this.status,
    required this.bookedLabel,
    required this.onTap,
  });

  final String time;
  final String status;
  final String bookedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'booked' => AppColors.primary,
      'blocked' => AppColors.danger,
      _ => AppColors.success,
    };
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.rMd,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Stack(children: [
          Center(
            child: Text(time,
                style: AppText.titleSm.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
          if (status == 'blocked')
            Positioned(
              top: 4,
              right: 6,
              child: Icon(Icons.lock,
                  size: 11, color: color.withValues(alpha: 0.7)),
            ),
          if (status == 'booked')
            Positioned(
              top: 4,
              right: 6,
              child: Text(bookedLabel.toUpperCase(),
                  style: AppText.overline.copyWith(
                      fontSize: 9,
                      color: color,
                      letterSpacing: 0.5)),
            ),
        ]),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      color: context.colors.surfaceElevated.withValues(alpha: 0.3),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.access_time,
              color: AppColors.primary, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(tr(ref, 'mobile.barber.schedule.empty', "Jadval yo'q"),
            style: AppText.titleSm),
        const SizedBox(height: AppSpacing.xs),
        Text(tr(ref, 'mobile.barber.schedule.emptyHint', "Ish vaqtingizni belgilang"),
            style: AppText.bodySm, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: tr(ref, 'mobile.barber.schedule.addSchedule', "Jadval qo'shish"),
          leadingIcon: Icons.add,
          onPressed: onAdd,
          fullWidth: true,
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
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 0.5),
            ],
          )),
      const SizedBox(width: AppSpacing.xs),
      Text(label, style: AppText.caption.copyWith(fontSize: 10)),
    ]);
  }
}

class _TinyAction extends StatelessWidget {
  const _TinyAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.rSm,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: AppText.button.copyWith(color: color, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.titleSm.copyWith(fontSize: 15)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: AppText.caption),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Shown at the top of the booked-slot action sheet вЂ” surfaces the
/// client's name, phone, and their service list so the barber can see
/// WHO is booked at that time without having to cancel first.
class _BookedClientCard extends ConsumerWidget {
  const _BookedClientCard({required this.booking});
  final BarberBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = booking.guestName?.isNotEmpty == true
        ? booking.guestName!
        : (booking.userName.isNotEmpty
            ? booking.userName
            : tr(ref, 'mobile.barber.bookingsAll.client', 'Mijoz'));
    final phone = booking.guestPhone ?? booking.userPhone ?? '';
    final services = booking.services.map((s) => s.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.rLg,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClientAvatar(
                name: name, avatar: booking.userAvatar, size: 40),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.titleSm, maxLines: 1),
                  if (phone.isNotEmpty)
                    Text(phone,
                        style: AppText.caption, maxLines: 1),
                ],
              ),
            ),
            if (booking.totalPrice > 0)
              Text(
                "${booking.totalPrice} ${tr(ref, 'common.currency', "so'm")}",
                style: AppText.body.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ]),
          if (services.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(services,
                style: AppText.bodySm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// Vertical list of today's bookings shown below the slot grid.
/// Ported from the web `todayBookings` block вЂ” the barber can see
/// every scheduled client at a glance (time, avatar, name, phone,
/// services, price, status badge) without tapping into individual
/// slot tiles. Tapping a card opens the same slot-action sheet as
/// tapping the grid tile so completing / cancelling still lives in
/// one place.
class _TodayBookingsList extends ConsumerWidget {
  const _TodayBookingsList({
    required this.bookings,
    required this.onTapBooking,
  });

  final List<BarberBooking> bookings;
  final ValueChanged<BarberBooking> onTapBooking;

  String _endTime(String start, int durationMin) {
    final parts = start.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final total = h * 60 + m + durationMin;
    final eh = (total ~/ 60) % 24;
    final em = total % 60;
    return '${eh.toString().padLeft(2, '0')}:${em.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final totalRevenue = bookings
        .where((b) => b.status != 'cancelled')
        .fold<int>(0, (a, b) => a + b.totalPrice);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(children: [
            Text(
              tr(ref, 'mobile.barber.schedule.todayBookings',
                  "Bugungi bronlar"),
              style: AppText.titleSm,
            ),
            AppSpacing.hGapXs,
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.rPill,
              ),
              child: Text(
                '${bookings.length}',
                style: AppText.overline.copyWith(
                    color: AppColors.primary, fontSize: 11),
              ),
            ),
          ]),
        ),
        AppSpacing.gapSm,
        for (final b in bookings)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BookingRow(
              booking: b,
              endTime: _endTime(b.time, b.totalDuration),
              onTap: () => onTapBooking(b),
            ),
          ),
        if (totalRevenue > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tr(ref, 'admin.totalRevenue', 'Umumiy daromad')}:',
                  style: AppText.bodySm
                      .copyWith(color: palette.textSecondary),
                ),
                Text(
                  '$totalRevenue ${tr(ref, 'common.currency', "so'm")}',
                  style: AppText.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BookingRow extends ConsumerWidget {
  const _BookingRow({
    required this.booking,
    required this.endTime,
    required this.onTap,
  });

  final BarberBooking booking;
  final String endTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final name = booking.guestName?.isNotEmpty == true
        ? booking.guestName!
        : (booking.userName.isNotEmpty
            ? booking.userName
            : tr(ref, 'barberApp.client', 'Mijoz'));
    final phone = booking.guestPhone ?? booking.userPhone ?? '';
    final services = booking.services.map((s) => s.name).join(', ');
    final statusColor = switch (booking.status) {
      'completed' => AppColors.success,
      'cancelled' => AppColors.danger,
      _ => AppColors.primary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            '${booking.time} вЂ“ $endTime',
            style: AppText.caption.copyWith(
              color: palette.textBright,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        TapScale(
          onTap: onTap,
          scale: 0.98,
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ClientAvatar(
                      name: name, avatar: booking.userAvatar, size: 36),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppText.titleSm, maxLines: 1),
                        if (phone.isNotEmpty)
                          Text(phone,
                              style: AppText.caption, maxLines: 1),
                      ],
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Text(
                      booking.isManual
                          ? tr(ref, 'barberApp.manual', 'Qo\'lda')
                          : tr(ref, 'status.${booking.status}',
                              booking.status),
                      style: AppText.overline.copyWith(
                        color: statusColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ]),
                if (services.isNotEmpty) ...[
                  AppSpacing.gapSm,
                  Text(
                    services,
                    style: AppText.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (booking.totalDuration > 0 || booking.totalPrice > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${booking.totalDuration} ${tr(ref, 'booking.duration', 'daq')}',
                        style: AppText.caption,
                      ),
                      if (booking.totalPrice > 0)
                        Text(
                          '${booking.totalPrice} ${tr(ref, 'common.currency', "so'm")}',
                          style: AppText.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

