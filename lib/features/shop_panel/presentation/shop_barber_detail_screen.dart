import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../barber_panel/data/barber_panel_repository.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/shop_repository.dart';
import 'shop_bookings_screen.dart' show shopBookingsFilteredProvider;

/// Shop-owner view of a single barber inside their salon. Mirrors the
/// web `BarbershopBarberDetail.tsx` flow — header with master info,
/// switchable Schedule / Clients tabs, date picker on the schedule
/// tab and the day's bookings. Mobile leaves the booking-row write
/// actions (reschedule / extend / cancel) for a follow-up; this is
/// the read-side first.
class ShopBarberDetailScreen extends ConsumerStatefulWidget {
  const ShopBarberDetailScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<ShopBarberDetailScreen> createState() =>
      _ShopBarberDetailScreenState();
}

class _ShopBarberDetailScreenState
    extends ConsumerState<ShopBarberDetailScreen> {
  int _tab = 0; // 0 = schedule, 1 = clients
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _call(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final barberAsync = ref.watch(_shopBarberByIdProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.shop.barberDetail.title', "Sartarosh")),
      ),
      body: barberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (b) {
          final phone = (b.phone ?? '');
          final showPhone = phone.isNotEmpty && !phone.startsWith('shop:');
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_shopBarberByIdProvider(widget.barberId));
              ref.invalidate(
                  _shopBarberBookingsProvider((id: widget.barberId, date: _dateStr(_date))));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ===== Header =====
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipOval(
                    child: (b.avatar?.isNotEmpty ?? false)
                        ? CachedNetworkImage(
                            imageUrl: assetUrl(b.avatar),
                            width: 64, height: 64, fit: BoxFit.cover)
                        : Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (b.name.isNotEmpty ? b.name[0] : '?').toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppColors.textBright)),
                        if (b.experience.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(b.experience,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                        if (showPhone) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _call(phone),
                            child: Row(children: [
                              const Icon(Icons.phone,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(phone,
                                  style: const TextStyle(
                                      color: AppColors.primary, fontSize: 13)),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // ===== Tabs =====
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    _TabBtn(
                      label: tr(ref, 'mobile.barber.schedule.title', "Jadval"),
                      on: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _TabBtn(
                      label: tr(ref, 'shop.nav.clients', "Mijozlar"),
                      on: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                if (_tab == 0)
                  _ScheduleTab(
                    barberId: widget.barberId,
                    date: _date,
                    onPickDate: _pickDate,
                  )
                else
                  _ClientsTab(barberId: widget.barberId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.background : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: on ? Border.all(color: AppColors.border) : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? AppColors.textBright : AppColors.textMuted)),
        ),
      ),
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab(
      {required this.barberId, required this.date, required this.onPickDate});
  final String barberId;
  final DateTime date;
  final VoidCallback onPickDate;
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final async =
        ref.watch(_shopBarberBookingsProvider((id: barberId, date: dateStr)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPickDate,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(_df.format(date),
                  style: const TextStyle(
                      color: AppColors.textBright, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted))),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                      tr(ref, 'mobile.shop.bookings.emptyForDay',
                          "Bu sanada bronlar yo'q"),
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
              );
            }
            final sorted = [...list]..sort((a, b) => a.time.compareTo(b.time));
            return Column(
              children: sorted
                  .asMap()
                  .entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BookingRow(b: e.value, dateStr: dateStr)
                            .animate()
                            .fadeIn(duration: 200.ms, delay: (e.key * 25).ms),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _BookingRow extends ConsumerWidget {
  const _BookingRow({required this.b, required this.dateStr});
  final ShopBooking b;
  final String dateStr;

  String _statusLabel(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return tr(ref, 'myBookings.statusCompleted', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'profile.cancelled', 'Bekor');
      default:
        return tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan');
    }
  }

  Color _statusColor() {
    switch (b.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return const Color(0xFF3B82F6);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(b.time,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_statusLabel(ref),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                if (b.totalPrice > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                      "${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)),
                ],
              ]),
            ],
          ),
        ),
        if (b.status == 'confirmed' && b.id.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textMuted, size: 20),
            onSelected: (value) async {
              switch (value) {
                case 'reschedule':
                  await _reschedule(context, ref);
                  break;
                case 'extend':
                  await _extend(context, ref);
                  break;
                case 'cancel':
                  await _cancel(context, ref);
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reschedule',
                child: Row(children: [
                  const Icon(Icons.event_repeat,
                      size: 16, color: AppColors.textBright),
                  const SizedBox(width: 8),
                  Text(tr(ref, 'mobile.shop.barber.reschedule',
                      "Boshqa vaqtga ko'chirish")),
                ]),
              ),
              PopupMenuItem(
                value: 'extend',
                child: Row(children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: AppColors.textBright),
                  const SizedBox(width: 8),
                  Text(tr(ref, 'mobile.shop.barber.extend',
                      "Vaqtni uzaytirish")),
                ]),
              ),
              PopupMenuItem(
                value: 'cancel',
                child: Row(children: [
                  const Icon(Icons.close,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Text(tr(ref, 'myBookings.cancel', "Bekor qilish"),
                      style: const TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
      ]),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'myBookings.cancelConfirmTitle',
            "Bronni bekor qilasizmi?")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(tr(ref, 'myBookings.cancel', "Bekor qilish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final initial = DateTime.tryParse(dateStr) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;
    final parts = b.time.split(':');
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
          .reschedule(b.id, date: newDate, time: newTime);
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    int minutes = 30;
    final ok = await showDialog<int>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
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
          .extendDuration(b.id, ok);
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }
}

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab({required this.barberId});
  final String barberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shopBarberClientsProvider(barberId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                  tr(ref, 'mobile.shop.barberDetail.noClients',
                      "Mijozlar topilmadi"),
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return Column(
          children: list
              .asMap()
              .entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ((e.value['name'] ?? '?').toString().isNotEmpty
                                    ? (e.value['name'] as String)[0]
                                    : '?')
                                .toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((e.value['name'] ?? '').toString().isEmpty
                                      ? (e.value['phone'] ?? '').toString()
                                      : (e.value['name'] ?? '').toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              if ((e.value['phone'] ?? '').toString().isNotEmpty)
                                Text((e.value['phone'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        if ((e.value['bookingsCount'] ?? 0) is num &&
                            ((e.value['bookingsCount'] ?? 0) as num) > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                                "${(e.value['bookingsCount'] as num).toInt()}",
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11)),
                          ),
                      ]),
                    ).animate().fadeIn(duration: 200.ms, delay: (e.key * 25).ms),
                  ))
              .toList(),
        );
      },
    );
  }
}

final _shopBarberByIdProvider =
    FutureProvider.family<ShopBarber, String>((ref, id) async {
  return ref.watch(shopRepositoryProvider).getBarber(id);
});

typedef _BookingsKey = ({String id, String date});

final _shopBarberBookingsProvider =
    FutureProvider.family<List<ShopBooking>, _BookingsKey>((ref, k) async {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.bookings(barberId: k.id, date: k.date, limit: 100);
});

final _shopBarberClientsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.barberClients(id);
});
