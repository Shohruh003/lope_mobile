import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../reviews/data/reviews_repository.dart';
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
              Text(tr(ref, 'myBookings.title', "Bronlar"),
                  style: const TextStyle(
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
                  child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
                data: (list) {
                  final upcoming = list.where((b) => b.status == 'confirmed').toList();
                  final past = list.where((b) => b.status == 'completed').toList();
                  final cancelled = list.where((b) => b.status == 'cancelled').toList();

                  final tabsCounts = [upcoming.length, past.length, cancelled.length];
                  final tabsLabels = [
                    tr(ref, 'profile.upcoming', "Kelayotgan"),
                    tr(ref, 'profile.past', "O'tgan"),
                    tr(ref, 'profile.cancelled', "Bekor"),
                  ];
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
                          Text(tr(ref, 'myBookings.empty', "Bron yo'q"),
                              style: const TextStyle(
                                  color: AppColors.textBright,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(tr(ref, 'myBookings.emptyHint',
                              "Sartaroshingizni tanlab, bron qiling"),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

class _BookingCard extends ConsumerWidget {
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

  String _statusText(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return tr(ref, 'myBookings.statusCompleted', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'myBookings.statusCancelled', 'Bekor qilingan');
      default:
        return tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    child: Text(_statusText(ref),
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
                    Text("${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
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
                        label: Text(tr(ref, 'myBookings.complete', "Yakunlash"),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _complete(context, ref),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close, size: 12, color: AppColors.danger),
                        label: Text(tr(ref, 'myBookings.cancel', "Bekor qilish"),
                            style: const TextStyle(
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
                        onPressed: () => _cancel(context, ref),
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
      ref.invalidate(myBookingsProvider);
      if (context.mounted) {
        // Web flow: after completing, prompt the customer to rate
        // the barber. They can also skip and just close.
        await _maybePromptReview(context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _maybePromptReview(BuildContext context, WidgetRef ref) async {
    var rating = 0;
    final commentCtrl = TextEditingController();
    var submitting = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        Future<void> doSkip() async {
          Navigator.of(sheetCtx).pop();
        }

        Future<void> doSubmit() async {
          if (rating == 0) {
            await doSkip();
            return;
          }
          setSheet(() => submitting = true);
          try {
            await ref.read(reviewsRepositoryProvider).submit(
                  barberId: b.barberId,
                  rating: rating,
                  comment: commentCtrl.text.trim(),
                  bookingId: b.id,
                );
            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
          } catch (e) {
            if (sheetCtx.mounted) {
              ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                  content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
            }
          } finally {
            setSheet(() => submitting = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ref, 'mobile.reviews.leaveReview', "Sharh qoldirish"),
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  tr(ref, 'mobile.reviews.rateHint',
                      "{{name}}'ning ishini baholang",
                      {'name': b.barberName}),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              Center(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled = i < rating;
                      return IconButton(
                        icon: Icon(filled ? Icons.star : Icons.star_border,
                            color: AppColors.warning, size: 36),
                        onPressed: () => setSheet(() => rating = i + 1),
                      );
                    })),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.reviews.commentPlaceholder',
                        "Sharhingiz (ixtiyoriy)")),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: submitting ? null : doSkip,
                    child: Text(tr(ref, 'mobile.reviews.skip', "O'tkazib yuborish")),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: submitting ? null : doSubmit,
                    child: submitting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(tr(ref, 'mobile.reviews.submit', "Yuborish")),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );
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
      ref.invalidate(myBookingsProvider);
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
