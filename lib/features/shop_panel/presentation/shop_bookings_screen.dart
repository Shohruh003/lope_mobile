import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
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
            const Text("Salon bronlari",
                style: TextStyle(
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
                  const Text("Sana:",
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
                    tooltip: 'Bugun',
                  ),
                ]),
              ),
            ),

            const SizedBox(height: 10),

            // ===== Barber filter =====
            mastersAsync.maybeWhen(
              data: (masters) => _filterDropdown<String>(
                label: "Master",
                value: _barberId,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text("Barchasi")),
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
              label: "Status",
              value: _status,
              items: const [
                DropdownMenuItem(value: 'all', child: Text("Barchasi")),
                DropdownMenuItem(value: 'confirmed', child: Text("Tasdiqlangan")),
                DropdownMenuItem(value: 'completed', child: Text("Yakunlangan")),
                DropdownMenuItem(value: 'cancelled', child: Text("Bekor qilingan")),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'all'),
            ),

            const SizedBox(height: 14),

            // ===== Count =====
            bookingsAsync.maybeWhen(
              data: (list) => Row(children: [
                const Icon(Icons.event_note, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text("${list.length} ta bron",
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
                child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text("Bu sanada bronlar yo'q",
                          style: TextStyle(color: AppColors.textMuted)),
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

class _BookingCard extends StatelessWidget {
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

  String get _statusText {
    switch (b.status) {
      case 'completed':
        return 'Yakunlangan';
      case 'cancelled':
        return 'Bekor';
      default:
        return 'Tasdiqlangan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadCard(
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

        // Barber avatar fallback (36px)
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            b.barberName.isNotEmpty ? b.barberName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ),
        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.barberName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textBright)),
              const SizedBox(height: 2),
              Text(b.userName,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_statusText,
                      style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                if (b.totalPrice > 0)
                  Text("${_fmt(b.totalPrice)} so'm",
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
              ]),
            ],
          ),
        ),
      ]),
    );
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
