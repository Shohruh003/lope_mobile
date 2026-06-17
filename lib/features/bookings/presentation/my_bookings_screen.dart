import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

/// 1:1 port of the web `CustomerBookingsScreen.tsx`:
///   - "Bronlar" title
///   - 3-tab row (Upcoming/Past/Cancelled) with counts in parens
///   - Booking cards: 44px avatar + name + status pill + services line +
///     date/time/price row + (for confirmed) Complete + Cancel buttons
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  int _tab = 0; // 0 = upcoming, 1 = past, 2 = cancelled

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myBookingsProvider);
    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(myBookingsProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text("Bronlar",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright)),
              const SizedBox(height: 14),

              async.when(
                loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("Xato: $e",
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
                data: (list) {
                  final upcoming = list.where((b) => b.status == 'confirmed').toList();
                  final past = list.where((b) => b.status == 'completed').toList();
                  final cancelled = list.where((b) => b.status == 'cancelled').toList();

                  final tabsCounts = [upcoming.length, past.length, cancelled.length];
                  final tabsLabels = ["Kelayotgan", "O'tgan", "Bekor"];
                  final visible = _tab == 0 ? upcoming : (_tab == 1 ? past : cancelled);

                  return Column(children: [
                    // ===== Tabs Row =====
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: List.generate(3, (i) {
                        final on = i == _tab;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: on ? AppColors.background : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: on ? Border.all(color: AppColors.border) : null,
                              ),
                              child: Center(
                                child: Text(
                                  "${tabsLabels[i]} (${tabsCounts[i]})",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                    color: on ? AppColors.textBright : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })),
                    ),
                    const SizedBox(height: 14),

                    // ===== Body =====
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.event_busy_outlined,
                                color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(height: 12),
                          const Text("Bron yo'q",
                              style: TextStyle(
                                  color: AppColors.textBright,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text("Sartaroshingizni tanlab, bron qiling",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      )
                    else
                      ...visible.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BookingCard(b: e.value)
                              .animate()
                              .fadeIn(duration: 200.ms, delay: (e.key * 25).ms),
                        );
                      }),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b});
  final Booking b;

  Color get _statusColor {
    switch (b.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.success;
    }
  }

  String get _statusText {
    switch (b.status) {
      case 'completed':
        return 'Yakunlangan';
      case 'cancelled':
        return 'Bekor qilingan';
      default:
        return 'Tasdiqlangan';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 44px avatar
          ClipOval(
            child: b.barberAvatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: b.barberAvatar,
                    width: 44, height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, err) => _AvatarFallback(name: b.barberName),
                  )
                : _AvatarFallback(name: b.barberName),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(b.barberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textBright)),
                  ),
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
                ]),
                if (b.services.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    b.services.map((s) => "${s.icon} ${s.name}").join(", "),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(b.date,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Text(b.time,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const Spacer(),
                  if (b.totalPrice > 0)
                    Text("${_fmt(b.totalPrice)} so'm",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                ]),
                if (b.status == 'confirmed') ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 12),
                        label: const Text("Yakunlash",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 12, color: AppColors.danger),
                        label: const Text("Bekor qilish",
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5)),
                          backgroundColor: AppColors.danger.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () {},
                      ),
                    ),
                  ]),
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
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
