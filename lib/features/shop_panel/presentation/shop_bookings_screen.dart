import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/shop_repository.dart';

/// Mirrors `BarbershopBookings.tsx` 1:1.
///   - Title "Salon bronlari"
///   - Filter row: Date picker tile + Barber dropdown + Status dropdown +
///     "X ta bron" counter
///   - List of cards: time pill + 36px avatar + barber name + client +
///     services line + total + cancel button (only for confirmed)
class ShopBookingsScreen extends ConsumerStatefulWidget {
  const ShopBookingsScreen({super.key});
  @override
  ConsumerState<ShopBookingsScreen> createState() => _ShopBookingsScreenState();
}

class _ShopBookingsScreenState extends ConsumerState<ShopBookingsScreen> {
  DateTime _date = DateTime.now();
  String _barberId = 'all';
  String _status = 'all';

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final mastersAsync = ref.watch(shopBarbersProvider);
    final bookingsAsync = ref.watch(shopBookingsFilteredProvider((
      date: _dateStr(_date),
      barberId: _barberId == 'all' ? null : _barberId,
      status: _status == 'all' ? null : _status,
    )));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(shopBarbersProvider);
            ref.invalidate(shopBookingsFilteredProvider);
            await ref.read(shopBookingsFilteredProvider((
              date: _dateStr(_date),
              barberId: _barberId == 'all' ? null : _barberId,
              status: _status == 'all' ? null : _status,
            )).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
            // ===== Title =====
            Text(tr(ref, 'mobile.shop.bookings.title', "Salon bronlari"),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright)),
            const SizedBox(height: 14),

            // ===== Date row =====
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text("${tr(ref, 'booking.date', 'Sana')}:",
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  Text(_dateStr(_date),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBright)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.today_outlined, size: 16, color: AppColors.primary),
                    onPressed: () => setState(() => _date = DateTime.now()),
                    tooltip: tr(ref, 'barberApp.today', 'Bugun'),
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 10),

            // ===== Barber filter =====
            mastersAsync.maybeWhen(
              data: (masters) => _filterDropdown<String>(
                label: tr(ref, 'mobile.shop.bookings.masterLabel', "Master"),
                value: _barberId,
                items: [
                  DropdownMenuItem(value: 'all', child: Text(tr(ref, 'common.all', "Barchasi"))),
                  ...masters.map((b) =>
                      DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (v) => setState(() => _barberId = v ?? 'all'),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 10),

            // ===== Status filter =====
            _filterDropdown<String>(
              label: tr(ref, 'mobile.shop.bookings.statusLabel', "Status"),
              value: _status,
              items: [
                DropdownMenuItem(value: 'all', child: Text(tr(ref, 'common.all', "Barchasi"))),
                DropdownMenuItem(value: 'confirmed', child: Text(tr(ref, 'myBookings.statusConfirmed', "Tasdiqlangan"))),
                DropdownMenuItem(value: 'completed', child: Text(tr(ref, 'myBookings.statusCompleted', "Yakunlangan"))),
                DropdownMenuItem(value: 'cancelled', child: Text(tr(ref, 'myBookings.statusCancelled', "Bekor qilingan"))),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'all'),
            ),

            const SizedBox(height: 14),

            // ===== Count =====
            bookingsAsync.maybeWhen(
              data: (list) => Row(children: [
                const Icon(Icons.event_note, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text("${list.length} ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')}",
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ]),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 10),

            // ===== Bookings list =====
            bookingsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(tr(ref, 'mobile.shop.bookings.emptyForDay',
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
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BookingCard(b: e.value)
                                .animate()
                                .fadeIn(duration: 200.ms, delay: (e.key * 20).ms),
                          ))
                      .toList(),
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Text("$label:",
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(width: 6),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: onChanged,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright),
              dropdownColor: AppColors.background,
              icon: const Icon(Icons.expand_more, size: 18, color: AppColors.textMuted),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.b});
  final ShopBooking b;

  Color get _statusColor {
    switch (b.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String _statusText(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return tr(ref, 'myBookings.statusCompleted', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'profile.cancelled', 'Bekor');
      default:
        return tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: b.barberId.isEmpty
          ? null
          : () => GoRouter.of(context).push('/shop/barbers/${b.barberId}'),
      child: ShadCard(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Time pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(b.time,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBright)),
        ),
        const SizedBox(width: 10),

        // Barber avatar — image if present, otherwise initial fallback (36px)
        ClipOval(
          child: (b.barberAvatar?.isNotEmpty ?? false)
              ? CachedNetworkImage(
                  imageUrl: b.barberAvatar!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      _avatarFallback(b.barberName),
                )
              : _avatarFallback(b.barberName),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textBright)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 11, color: AppColors.textMuted),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(b.barberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ),
                if (b.userPhone != null && b.userPhone!.isNotEmpty) ...[
                  const Text("  •  ",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Flexible(
                    child: Text(b.userPhone!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ),
                ],
                if (b.totalDuration > 0) ...[
                  const Text("  •  ",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const Icon(Icons.access_time,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text("${b.totalDuration}m",
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusText(ref),
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (b.totalPrice > 0)
                  Text("${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
              ]),
              if (b.status == 'confirmed') ...[
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 11),
                      label: Text(tr(ref, 'myBookings.complete', "Yakunlash"),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _complete(context, ref),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close,
                          size: 11, color: AppColors.danger),
                      label: Text(tr(ref, 'myBookings.cancel', "Bekor qilish"),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        side: BorderSide(
                            color: AppColors.danger.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => _cancel(context, ref),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ]),
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      );

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'myBookings.completeConfirmTitle',
            "Bronni yakunlash?")),
        content: Text(tr(ref, 'myBookings.completeConfirmMsg',
            "Bron yakunlangan deb belgilanadi.")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).complete(b.id);
      ref.invalidate(shopBookingsFilteredProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'myBookings.cancelConfirmTitle',
            "Bronni bekor qilasizmi?")),
        content: Text(tr(ref, 'myBookings.cancelConfirmMsg',
            "Bekor qilingach, qaytarib bo'lmaydi.")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.close', "Yopish"))),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(tr(ref, 'myBookings.cancel', "Bekor qilish"))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(shopBookingsFilteredProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'myBookings.cancelled',
                "Bron bekor qilindi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
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

/// Provider matching the same query the web sends, so we can filter
/// per-date and per-master without burning extra round-trips.
final shopBookingsFilteredProvider = FutureProvider.family<List<ShopBooking>,
    ({String? date, String? barberId, String? status})>((ref, key) async {
  return ref.watch(shopRepositoryProvider).bookings(
        date: key.date,
        barberId: key.barberId,
        status: key.status,
      );
});
