import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

/// Per-client visit history — opened by tapping a card on the
/// "Mijozlarim" list. Filters the barber's all-bookings feed to the
/// given phone number and renders each visit as a booking card with
/// date + time + services + price. Shows aggregate stats at the top
/// (total visits, first / last, revenue).
class BarberClientDetailScreen extends ConsumerWidget {
  const BarberClientDetailScreen({
    super.key,
    required this.phone,
    this.initialName,
    this.initialAvatar,
  });

  /// Digits-only phone (e.g. `998942720705`) — matched against the
  /// bookings feed's `userPhone` / `guestPhone` (stripped to digits
  /// for the comparison).
  final String phone;

  /// Client's display name, passed via the query string from the
  /// Mijozlarim list so the header renders instantly without waiting
  /// for the bookings fetch.
  final String? initialName;
  final String? initialAvatar;

  static const _monthsUz = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];

  String _prettyDate(String iso, WidgetRef ref) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.tomorrow', 'Ertaga');
    if (diff == -1) return tr(ref, 'mobile.dates.yesterday', 'Kecha');
    final month = _monthsUz[dt.month - 1];
    if (dt.year != now.year) return '${dt.day} $month ${dt.year}';
    return '${dt.day} $month';
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

  bool _matchesPhone(BarberBooking b, String needle) {
    final u = (b.userPhone ?? '').replaceAll(RegExp(r'\D'), '');
    final g = (b.guestPhone ?? '').replaceAll(RegExp(r'\D'), '');
    return u == needle || g == needle;
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: '+$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: AppListSkeleton());
    final async = ref.watch(barberAllBookingsProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initialName?.isNotEmpty == true
              ? initialName!
              : '+$phone',
          style: AppText.titleMd,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined,
                color: AppColors.primary),
            onPressed: _call,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(
              barberAllBookingsProvider(user.id)),
        ),
        data: (all) {
          // Filter by phone + sort newest visit first. `all` isn't
          // sorted by us (backend does date desc / time desc) but a
          // client-side sort makes the "latest first" contract
          // explicit and survives future backend changes.
          final mine = all.where((b) => _matchesPhone(b, phone)).toList()
            ..sort((a, b) {
              final d = b.date.compareTo(a.date);
              if (d != 0) return d;
              return b.time.compareTo(a.time);
            });

          if (mine.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.refresh(
                  barberAllBookingsProvider(user.id).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 360,
                    child: AppEmptyState(
                      icon: Icons.event_busy,
                      title: tr(ref,
                          'mobile.barber.clientDetail.empty',
                          "Bronlar topilmadi"),
                      message: tr(ref,
                          'mobile.barber.clientDetail.emptyHint',
                          'Bu raqamdan hech qanday bron tarixida yo\'q.'),
                    ),
                  ),
                ],
              ),
            );
          }

          final total = mine
              .where((b) => b.status != 'cancelled')
              .fold<int>(0, (s, b) => s + b.totalPrice);
          final completedCount =
              mine.where((b) => b.status == 'completed').length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(
                barberAllBookingsProvider(user.id).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.pageBottom(context)),
              children: [
                _HeaderCard(
                  name: initialName ??
                      (mine.first.guestName ?? mine.first.userName),
                  phone: '+$phone',
                  avatar: initialAvatar?.isNotEmpty == true
                      ? initialAvatar
                      : mine.first.userAvatar,
                  visits: mine.length,
                  completed: completedCount,
                  totalRevenue: total,
                ),
                AppSpacing.gapLg,
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tr(ref,
                        'mobile.barber.clientDetail.visitsTitle',
                        'Tashriflar tarixi'),
                    style: AppText.titleSm,
                  ),
                ),
                AppSpacing.gapSm,
                for (var i = 0; i < mine.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(
                        bottom: AppSpacing.sm),
                    child: _VisitCard(
                      booking: mine[i],
                      prettyDate: _prettyDate(mine[i].date, ref),
                    ).animate().fadeIn(
                        duration: 200.ms, delay: (i * 30).ms),
                  ),
                AppSpacing.gapMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${tr(ref, 'admin.totalRevenue', 'Umumiy daromad')}:',
                      style: AppText.bodySm,
                    ),
                    Text(
                      '${_fmt(total)} ${tr(ref, 'common.currency', "so'm")}',
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.name,
    required this.phone,
    required this.visits,
    required this.completed,
    required this.totalRevenue,
    this.avatar,
  });

  final String name;
  final String phone;
  final String? avatar;
  final int visits;
  final int completed;
  final int totalRevenue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ClientAvatar(
                name: name, avatar: avatar, size: 56, ring: true),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.titleMd),
                  const SizedBox(height: 2),
                  Text(phone,
                      style: AppText.bodySm.copyWith(
                          color: context.colors.textSecondary,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                ],
              ),
            ),
          ]),
          AppSpacing.gapMd,
          Row(children: [
            Expanded(
              child: _StatBox(
                label: tr(ref,
                    'mobile.barber.clientDetail.visits', 'Tashriflar'),
                value: '$visits',
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: _StatBox(
                label: tr(ref,
                    'mobile.barber.clientDetail.completed',
                    'Yakunlangan'),
                value: '$completed',
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: _StatBox(
                label: tr(ref, 'admin.totalRevenue', 'Daromad'),
                value: totalRevenue >= 1000
                    ? '${(totalRevenue / 1000).toStringAsFixed(0)}k'
                    : '$totalRevenue',
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppText.titleMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: AppText.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _VisitCard extends ConsumerWidget {
  const _VisitCard({required this.booking, required this.prettyDate});
  final BarberBooking booking;
  final String prettyDate;

  Color _statusColor() {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final services = booking.services.map((s) => s.name).join(', ');
    final color = _statusColor();
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.rSm,
              ),
              child: Text(
                prettyDate,
                style: AppText.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AppSpacing.hGapSm,
            Icon(Icons.access_time,
                size: 12, color: context.colors.textMuted),
            AppSpacing.hGapXs,
            Text(
              booking.time,
              style: AppText.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            if (booking.status == 'cancelled')
              Text(
                tr(ref, 'status.cancelled', 'Bekor'),
                style: AppText.overline
                    .copyWith(color: AppColors.danger, fontSize: 10),
              )
            else if (booking.status == 'completed')
              Text(
                tr(ref, 'status.completed', 'Yakunlangan'),
                style: AppText.overline
                    .copyWith(color: AppColors.success, fontSize: 10),
              ),
          ]),
          if (services.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(services,
                style: AppText.bodySm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          if (booking.totalPrice > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${booking.totalDuration} ${tr(ref, 'booking.duration', 'daq')}',
                  style: AppText.caption,
                ),
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
    );
  }
}
