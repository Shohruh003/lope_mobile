import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/barber_panel_repository.dart';

/// Mirrors `BarberClientsScreen.tsx` exactly:
///   - Date filter row: chevronLeft + date input + chevronRight + "Today" pill
///   - Search bar
///   - Status tabs: 3 pills (Confirmed/Completed/Cancelled) each showing the
///     count, active tab gets a colored background (blue/green/red)
///   - "X ta bron" counter
///   - List of booking cards
class BarberBookingsScreen extends ConsumerStatefulWidget {
  const BarberBookingsScreen({super.key});

  @override
  ConsumerState<BarberBookingsScreen> createState() => _BarberBookingsScreenState();
}

class _BarberBookingsScreenState extends ConsumerState<BarberBookingsScreen> {
  late DateTime _selectedDate;
  String _activeTab = 'confirmed'; // 'confirmed' | 'completed' | 'cancelled'
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String _toDateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final async = ref.watch(barberDayBookingsProvider(
        (barberId: user.id, date: _toDateStr(_selectedDate))));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ===== Date filter row =====
            Row(children: [
              _IconBtn(
                icon: Icons.chevron_left,
                onTap: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _pickDate,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        _toDateStr(_selectedDate),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.chevron_right,
                onTap: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1))),
              ),
              if (!_isToday) ...[
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedDate = DateTime.now()),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr(ref, 'mobile.barber.bookingsAll.today', "Bugun"),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 12),

            // ===== Search =====
            SizedBox(
              height: 44,
              child: TextField(
                onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 16),
                  prefixIconConstraints: const BoxConstraints(minWidth: 36),
                  hintText: tr(ref, 'mobile.barber.bookings.searchPlaceholder', "Mijoz nomi yoki telefon"),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ===== Status tabs =====
            async.when(
              loading: () => _tabsRow(0, 0, 0),
              error: (_, _) => _tabsRow(0, 0, 0),
              data: (list) {
                final c = list.where((b) => b.status == 'confirmed').length;
                final co = list.where((b) => b.status == 'completed').length;
                final ca = list.where((b) => b.status == 'cancelled').length;
                return _tabsRow(c, co, ca);
              },
            ),

            const SizedBox(height: 16),

            // ===== List =====
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
              ),
              data: (list) {
                final filtered = list.where((b) {
                  if (b.status != _activeTab) return false;
                  if (_search.isEmpty) return true;
                  final name = (b.guestName?.isNotEmpty == true ? b.guestName! : b.userName).toLowerCase();
                  final phone = (b.guestPhone ?? b.userPhone ?? '').toLowerCase();
                  return name.contains(_search) || phone.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      const Icon(Icons.people_outline, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(tr(ref, 'myBookings.empty', "Bron yo'q"),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
                    ]),
                  );
                }

                return Column(children: [
                  // Count
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text("${filtered.length} ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')}",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ]),
                  ),
                  ...filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final b = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _BookingTile(b: b).animate().fadeIn(duration: 200.ms, delay: (i * 25).ms),
                    );
                  }),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabsRow(int confirmed, int completed, int cancelled) {
    return Row(children: [
      _StatusTab(
        label: tr(ref, 'myBookings.statusConfirmed', "Tasdiqlangan"),
        count: confirmed,
        on: _activeTab == 'confirmed',
        onColor: const Color(0xFF3B82F6), // blue-500
        onTap: () => setState(() => _activeTab = 'confirmed'),
      ),
      const SizedBox(width: 8),
      _StatusTab(
        label: tr(ref, 'myBookings.statusCompleted', "Yakunlangan"),
        count: completed,
        on: _activeTab == 'completed',
        onColor: const Color(0xFF22C55E), // green-500
        onTap: () => setState(() => _activeTab = 'completed'),
      ),
      const SizedBox(width: 8),
      _StatusTab(
        label: tr(ref, 'profile.cancelled', "Bekor"),
        count: cancelled,
        on: _activeTab == 'cancelled',
        onColor: const Color(0xFFEF4444), // red-500
        onTap: () => setState(() => _activeTab = 'cancelled'),
      ),
    ]);
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: AppColors.textMuted, size: 16),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.on,
    required this.onColor,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool on;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: on ? onColor.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(color: on ? onColor : AppColors.border),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? onColor : AppColors.textMuted,
                )),
            const SizedBox(height: 4),
            Text("$count",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: on ? onColor : AppColors.textBright,
                )),
          ]),
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.b});
  final BarberBooking b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = b.guestName?.isNotEmpty == true
        ? b.guestName!
        : (b.userName.isNotEmpty ? b.userName : tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz"));
    final phone = b.guestPhone ?? b.userPhone ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            (name.isNotEmpty ? name[0] : '?').toUpperCase(),
            style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBright)),
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(phone,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(b.time,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (b.totalDuration > 0) ...[
                  const SizedBox(width: 6),
                  Text("(${b.totalDuration} ${tr(ref, 'booking.duration', 'daq')})",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
                if (b.isManual) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                        tr(ref, 'mobile.shop.bookings.manualBadge',
                            "Qo'lda"),
                        style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if (b.notes != null && b.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic)),
                  ),
                ]),
              ],
            ],
          ),
        ),
        if (b.totalPrice > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: Text("${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        if (phone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 18),
            onPressed: () async {
              final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
              final uri = Uri(scheme: 'tel', path: clean);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
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
      ]),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    int? overrideTotal;
    final priceCtrl = TextEditingController(
        text: b.totalPrice > 0 ? b.totalPrice.toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'myBookings.completeConfirmTitle',
            "Bronni yakunlash?")),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(ref, 'myBookings.completeConfirmMsg',
              "Bron yakunlangan deb belgilanadi.")),
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
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () {
                overrideTotal = int.tryParse(priceCtrl.text.trim());
                Navigator.pop(dCtx, true);
              },
              child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(bookingRepositoryProvider)
          .complete(b.id, totalPrice: overrideTotal);
      ref.invalidate(barberAllBookingsProvider);
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
      ref.invalidate(barberAllBookingsProvider);
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
