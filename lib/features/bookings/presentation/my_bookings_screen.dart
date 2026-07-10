import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

/// Redesigned "Bronlar" screen. State/API logic same as before (infinite
/// scroll pagination, refresh on resume, review prompt after complete);
/// only the UI is rebuilt on the new design system.
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with WidgetsBindingObserver {
  int _tab = 0; // 0 = upcoming, 1 = past, 2 = cancelled

  final List<Booking> _all = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initial = true;
  String? _error;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(1));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPage(1);
    }
  }

  void _onScroll() {
    if (_loading || !_hasMore) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadPage(_page + 1);
    }
  }

  Future<void> _loadPage(int page) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(bookingRepositoryProvider).minePaged(
          ref.read(authControllerProvider).user?.id ?? '',
          page: page);
      if (!mounted) return;
      setState(() {
        if (page == 1) _all.clear();
        _all.addAll(res.data);
        _page = page;
        _hasMore = res.hasMore;
        _initial = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _hasMore = true;
    await _loadPage(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              // ===== Header =====
              Text(
                tr(ref, 'myBookings.title', 'Bronlar'),
                style: AppText.titleLg,
              ),
              AppSpacing.gapMd,

              Builder(builder: (_) {
                if (_initial && _loading) {
                  return const AppListSkeleton(itemCount: 5);
                }
                if (_error != null && _all.isEmpty) {
                  return SizedBox(
                    height: 300,
                    child: AppErrorState(
                      message: _error!,
                      onRetry: _refresh,
                    ),
                  );
                }
                final list = _all;
                final upcoming =
                    list.where((b) => b.status == 'confirmed').toList();
                final past =
                    list.where((b) => b.status == 'completed').toList();
                final cancelled =
                    list.where((b) => b.status == 'cancelled').toList();

                final tabsCounts = [
                  upcoming.length,
                  past.length,
                  cancelled.length
                ];
                final tabsLabels = [
                  tr(ref, 'profile.upcoming', 'Kelayotgan'),
                  tr(ref, 'profile.past', "O'tgan"),
                  tr(ref, 'profile.cancelled', 'Bekor'),
                ];
                final visible =
                    _tab == 0 ? upcoming : (_tab == 1 ? past : cancelled);

                return Column(children: [
                  // ===== Tabs =====
                  _SegmentedTabs(
                    labels: tabsLabels,
                    counts: tabsCounts,
                    selected: _tab,
                    onChange: (i) => setState(() => _tab = i),
                  ),
                  AppSpacing.gapLg,

                  // ===== Body =====
                  if (visible.isEmpty)
                    SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        icon: _tab == 2
                            ? Icons.event_busy_rounded
                            : (_tab == 1
                                ? Icons.history_rounded
                                : Icons.event_available_rounded),
                        title: tr(ref, 'myBookings.empty', "Bron yo'q"),
                        message: _tab == 0
                            ? tr(ref, 'myBookings.emptyHint',
                                "Sartaroshingizni tanlab, bron qiling")
                            : (_tab == 1
                                ? tr(ref, 'myBookings.emptyPastHint',
                                    "Yakunlangan bronlar bu yerda ko'rinadi")
                                : tr(ref, 'myBookings.emptyCancelledHint',
                                    "Bekor qilingan bronlar bu yerda saqlanadi")),
                      ),
                    )
                  else
                    ...visible.asMap().entries.map((e) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _BookingCard(b: e.value, onChanged: _refresh)
                            .animate()
                            .fadeIn(
                                duration: 200.ms,
                                delay: (e.key * 25).ms,
                                curve: AppMotion.emphasized),
                      );
                    }),
                  if (_loading && !_initial)
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))),
                    ),
                ]);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Segmented tabs with count badges
// ─────────────────────────────────────────────────────────────────────────
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.labels,
    required this.counts,
    required this.selected,
    required this.onChange,
  });
  final List<String> labels;
  final List<int> counts;
  final int selected;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == selected;
          return Expanded(
            child: TapScale(
              onTap: () => onChange(i),
              haptic: HapticStrength.selection,
              scale: 0.97,
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: on ? AppColors.background : Colors.transparent,
                  borderRadius: AppRadius.rSm,
                  border: on
                      ? Border.all(color: AppColors.border)
                      : null,
                  boxShadow: on ? AppShadows.subtle : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: AppText.caption.copyWith(
                        fontSize: 12,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on
                            ? AppColors.textBright
                            : AppColors.textMuted,
                      ),
                    ),
                    AppSpacing.hGapXs,
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: on
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: AppRadius.rPill,
                      ),
                      child: Text(
                        '${counts[i]}',
                        style: AppText.caption.copyWith(
                          color: on ? Colors.white : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Booking card
// ─────────────────────────────────────────────────────────────────────────
class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.b, required this.onChanged});
  final Booking b;
  final Future<void> Function() onChanged;

  ({AppBadgeVariant variant, String label}) _statusMeta(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return (
          variant: AppBadgeVariant.success,
          label: tr(ref, 'myBookings.statusCompleted', 'Yakunlangan'),
        );
      case 'cancelled':
        return (
          variant: AppBadgeVariant.danger,
          label: tr(ref, 'myBookings.statusCancelled', 'Bekor qilingan'),
        );
      default:
        return (
          variant: AppBadgeVariant.info,
          label: tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan'),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _statusMeta(ref);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.lg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 44px avatar
          ClipOval(
            child: b.barberAvatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: assetUrl(b.barberAvatar),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SkeletonCircle(size: 44),
                    errorWidget: (_, _, _) =>
                        _AvatarFallback(name: b.barberName),
                  )
                : _AvatarFallback(name: b.barberName),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      b.barberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleSm,
                    ),
                  ),
                  AppSpacing.hGapSm,
                  AppBadge(
                    label: status.label,
                    variant: status.variant,
                    dot: b.status == 'confirmed',
                  ),
                ]),
                if (b.services.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    b.services.map((s) => '${s.icon} ${s.name}').join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textMuted),
                  AppSpacing.hGapXs,
                  Text(b.date, style: AppText.caption),
                  AppSpacing.hGapMd,
                  const Icon(Icons.access_time_outlined,
                      size: 12, color: AppColors.textMuted),
                  AppSpacing.hGapXs,
                  Text(b.time, style: AppText.caption),
                  const Spacer(),
                  if (b.totalPrice > 0)
                    Text(
                      "${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                ]),
                if (b.notes != null && b.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.rSm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 12, color: AppColors.textMuted),
                        AppSpacing.hGapXs,
                        Expanded(
                          child: Text(
                            b.notes!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (b.status == 'confirmed') ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(
                      child: AppButton(
                        label: tr(ref, 'myBookings.complete', 'Yakunlash'),
                        leadingIcon: Icons.check_circle_outline,
                        variant: AppButtonVariant.success,
                        size: AppButtonSize.sm,
                        fullWidth: true,
                        onPressed: () => _complete(context, ref),
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: AppButton(
                        label: tr(ref, 'myBookings.cancel', 'Bekor qilish'),
                        leadingIcon: Icons.close,
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.sm,
                        fullWidth: true,
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
    AppHaptics.light();
    final ok = await _confirmDialog(
      context,
      ref,
      title:
          tr(ref, 'myBookings.completeConfirmTitle', 'Bronni yakunlash?'),
      message: tr(ref, 'myBookings.completeConfirmMsg',
          'Bron yakunlangan deb belgilanadi.'),
      confirmLabel: tr(ref, 'common.confirm', 'Tasdiqlash'),
      confirmVariant: AppButtonVariant.primary,
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).complete(b.id);
      ref.invalidate(myBookingsProvider);
      await onChanged();
      if (context.mounted) {
        await _maybePromptReview(context, ref);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.errorRetry',
                "Xatolik — qaytadan urinib ko'ring"))));
      }
    }
  }

  Future<void> _maybePromptReview(BuildContext context, WidgetRef ref) async {
    var rating = 0;
    final commentCtrl = TextEditingController();
    var submitting = false;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
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
                    content: Text(
                        "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
              }
            } finally {
              setSheet(() => submitting = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: AppSpacing.lg +
                  MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: AppRadius.rPill,
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Text(
                  tr(ref, 'mobile.reviews.leaveReview', 'Sharh qoldirish'),
                  style: AppText.titleMd,
                ),
                const SizedBox(height: 4),
                Text(
                  tr(ref, 'mobile.reviews.rateHint',
                      "{{name}}'ning ishini baholang",
                      {'name': b.barberName}),
                  style: AppText.bodySm,
                ),
                AppSpacing.gapLg,
                Center(
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final filled = i < rating;
                        return TapScale(
                          onTap: () {
                            AppHaptics.selection();
                            setSheet(() => rating = i + 1);
                          },
                          scale: 0.85,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              filled ? Icons.star : Icons.star_border,
                              color: AppColors.warning,
                              size: 40,
                            ),
                          ),
                        );
                      })),
                ),
                AppSpacing.gapMd,
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.reviews.commentPlaceholder',
                        'Sharhingiz (ixtiyoriy)'),
                  ),
                ),
                AppSpacing.gapLg,
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(
                          ref, 'mobile.reviews.skip', "O'tkazib yuborish"),
                      variant: AppButtonVariant.secondary,
                      onPressed: submitting ? null : doSkip,
                      fullWidth: true,
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'mobile.reviews.submit', 'Yuborish'),
                      variant: AppButtonVariant.primary,
                      loading: submitting,
                      onPressed: submitting ? null : doSubmit,
                      fullWidth: true,
                    ),
                  ),
                ]),
              ],
            ),
          );
        }),
      );
    } finally {
      commentCtrl.dispose();
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final ok = await _confirmDialog(
      context,
      ref,
      title: tr(ref, 'myBookings.cancelConfirmTitle',
          'Bronni bekor qilasizmi?'),
      message: tr(ref, 'myBookings.cancelConfirmMsg',
          "Bekor qilingach, qaytarib bo'lmaydi."),
      confirmLabel: tr(ref, 'myBookings.cancel', 'Bekor qilish'),
      confirmVariant: AppButtonVariant.danger,
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(myBookingsProvider);
      await onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'myBookings.cancelled',
                'Bron bekor qilindi'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.errorRetry',
                "Xatolik — qaytadan urinib ko'ring"))));
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

// ─────────────────────────────────────────────────────────────────────────
// Confirm dialog with new design system look
// ─────────────────────────────────────────────────────────────────────────
Future<bool?> _confirmDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  required String confirmLabel,
  required AppButtonVariant confirmVariant,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dCtx) => Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.titleMd),
            AppSpacing.gapSm,
            Text(message, style: AppText.bodySm),
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
                  label: confirmLabel,
                  variant: confirmVariant,
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

// ─────────────────────────────────────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.titleMd.copyWith(color: Colors.white),
      ),
    );
  }
}
