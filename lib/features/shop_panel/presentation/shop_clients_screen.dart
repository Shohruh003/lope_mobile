import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';
import 'bulk_send_progress_modal.dart';

class ShopClientsScreen extends ConsumerStatefulWidget {
  const ShopClientsScreen({super.key});

  @override
  ConsumerState<ShopClientsScreen> createState() =>
      _ShopClientsScreenState();
}

class _ShopClientsScreenState extends ConsumerState<ShopClientsScreen> {
  static final _df = DateFormat('dd.MM.yyyy');
  String _query = '';
  String _bucket = 'all';
  final Set<String> _selected = {};
  bool _sending = false;

  /// Set while fetching the full paginated client list for the
  /// "Hammasini tanlash" action — disables the checkbox and shows a
  /// spinner so the user can't tap-storm.
  bool _selectingAll = false;

  bool _inBucket(ShopClient c, DateTime now) {
    if (_bucket == 'all') return true;
    if (c.lastVisit == null) return _bucket == '60+';
    final days = now.difference(c.lastVisit!).inDays;
    switch (_bucket) {
      case '0-7':
        return days <= 7;
      case '8-20':
        return days >= 8 && days <= 20;
      case '21-60':
        return days >= 21 && days <= 60;
      case '60+':
        return days > 60;
      default:
        return true;
    }
  }

  Future<void> _send() async {
    AppHaptics.medium();
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
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
              Text(
                tr(ref, 'mobile.shop.clients.bulkSendTitle',
                    'Tanlanganlarga SMS yuborilsinmi?'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(
                    ref,
                    'mobile.shop.clients.bulkSendMsg',
                    "{{n}} ta mijozga retention SMS jo'natiladi.",
                    {'n': '${_selected.length}'}),
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
                    label: tr(ref, 'common.confirm', 'Tasdiqlash'),
                    variant: AppButtonVariant.primary,
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
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final res = await ref
          .read(shopRepositoryProvider)
          .sendRetentionSms(_selected.toList());
      if (!mounted) return;
      AppHaptics.success();
      setState(() => _selected.clear());
      if (res.jobId.isNotEmpty) {
        await BulkSendProgressModal.show(context, jobId: res.jobId);
      } else {
        AppSnack.success(
            context,
            tr(
                ref,
                'mobile.shop.clients.bulkSendQueued',
                "{{n}} ta SMS navbatga qo'shildi",
                {'n': '${res.total}'}));
      }
      // Refetch after the send finishes so the client list reflects
      // updated 'due for reminder' / last-visit state — previously
      // the modal closed and the same rows sat there marked pending.
      if (mounted) ref.invalidate(shopClientsProvider);
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        AppSnack.error(context, humanize(e));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// "Hammasini tanlash" now selects **every** client across all
  /// pages, not just the currently loaded 50. Fetches the full list
  /// via `clientsAll()` (paginated loop inside the repo) and merges
  /// their phones into [_selected]. Second tap clears selection.
  Future<void> _toggleSelectAll(List<ShopClient> visible) async {
    AppHaptics.selection();
    // If anything is currently selected, treat the tap as "clear all".
    if (_selected.isNotEmpty) {
      setState(() => _selected.clear());
      return;
    }
    setState(() => _selectingAll = true);
    try {
      final all =
          await ref.read(shopRepositoryProvider).clientsAll(
                search: _query.isEmpty ? null : _query,
              );
      if (!mounted) return;
      setState(() {
        for (final c in all) {
          // Filter by the current bucket + phone-present so we don't
          // queue up empty numbers.
          if (c.phone.isEmpty) continue;
          if (!_inBucket(c, DateTime.now())) continue;
          _selected.add(c.phone);
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppSnack.error(context, humanize(e));
    } finally {
      if (mounted) setState(() => _selectingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopClientsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'shop.nav.clients', 'Mijozlar'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(shopClientsProvider),
        ),
        data: (rawList) {
          final now = DateTime.now();
          final filtered = rawList.where((c) {
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final hit = c.name.toLowerCase().contains(q) ||
                  c.phone.contains(_query);
              if (!hit) return false;
            }
            return _inBucket(c, now);
          }).toList();

          return Stack(children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.refresh(shopClientsProvider.future),
              child: Column(children: [
                // ── Search ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.rLg,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        prefixIcon: Icon(Icons.search,
                            color: context.colors.textMuted, size: 20),
                        hintText: tr(ref,
                            'mobile.lopepay.customers.searchHint',
                            'Ism yoki telefon'),
                        hintStyle: AppText.body
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                  ),
                ),
                // ── Filter chips (recency bucket) ──
                // Wrapped in a symmetric-sm-padded scroller so the
                // pills have breathing room above and below —
                // previously they rendered flush against the search
                // bar on top and 'Hammasini tanlash' below, which the
                // shop owner flagged as 'chiplarga yopishib qolgan'.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      children: [
                        AppChip(
                          label: tr(ref, 'common.all', 'Barchasi'),
                          selected: _bucket == 'all',
                          onTap: () => setState(() => _bucket = 'all'),
                        ),
                      AppSpacing.hGapSm,
                      AppChip(
                        label: '0-7',
                        selected: _bucket == '0-7',
                        onTap: () => setState(() => _bucket = '0-7'),
                      ),
                      AppSpacing.hGapSm,
                      AppChip(
                        label: '8-20',
                        selected: _bucket == '8-20',
                        onTap: () => setState(() => _bucket = '8-20'),
                      ),
                      AppSpacing.hGapSm,
                      AppChip(
                        label: '21-60',
                        selected: _bucket == '21-60',
                        onTap: () => setState(() => _bucket = '21-60'),
                      ),
                      AppSpacing.hGapSm,
                      AppChip(
                        label: '60+',
                        selected: _bucket == '60+',
                        onTap: () => setState(() => _bucket = '60+'),
                      ),
                    ],
                    ),
                  ),
                ),
                // Thin divider between the filter row and the select-
                // all bar. Gives the eye a clear line to rest on so
                // the two rows don't blur into one control strip.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: context.colors.border,
                  ),
                ),
                // ── Select-all + count ──
                if (filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Row(children: [
                      TapScale(
                        onTap: _selectingAll
                            ? null
                            : () => _toggleSelectAll(filtered),
                        scale: 0.95,
                        child: Row(children: [
                          // Small spinner while the paginated fetch
                          // runs so the user sees the checkbox is
                          // working — no more mystery 2-3 second
                          // pause on the first tap of "Hammasini
                          // tanlash" for a shop with 700+ clients.
                          if (_selectingAll)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else
                            Icon(
                              _selected.isNotEmpty
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          AppSpacing.hGapSm,
                          Text(
                            tr(
                                ref,
                                'mobile.shop.clients.selectAll',
                                'Hammasini tanlash'),
                            style: AppText.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textBright,
                            ),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      // Count pill — small chip with a person icon so
                      // 'how many rows in this filter' reads at a
                      // glance instead of being a lone number.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.people_alt_outlined,
                              size: 12, color: AppColors.primary),
                          AppSpacing.hGapXs,
                          Text(
                            '${filtered.length}',
                            style: AppText.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? AppEmptyState(
                          icon: Icons.people_outline_rounded,
                          title: rawList.isEmpty
                              ? tr(ref, 'mobile.shop.clients.empty',
                                  "Mijozlar ro'yxati bo'sh")
                              : tr(ref, 'common.noResults',
                                  'Hech narsa topilmadi'),
                          message: rawList.isEmpty
                              ? tr(
                                  ref,
                                  'mobile.shop.clients.emptyHint',
                                  "Barcha mijozlar bu yerda paydo bo'ladi.",
                                )
                              : tr(ref, 'mobile.shop.clients.noResultsHint',
                                  "Qidiruv shartlarini o'zgartirib ko'ring."),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.sm,
                            AppSpacing.lg,
                            80,
                          ),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              AppSpacing.gapSm,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return _ClientRow(
                              c: c,
                              df: _df,
                              selected: _selected.contains(c.phone),
                              onToggle: () {
                                AppHaptics.selection();
                                setState(() {
                                  if (_selected.contains(c.phone)) {
                                    _selected.remove(c.phone);
                                  } else if (c.phone.isNotEmpty) {
                                    _selected.add(c.phone);
                                  }
                                });
                              },
                            ).animate().fadeIn(
                                duration: 250.ms,
                                delay: (i * 20).ms);
                          },
                        ),
                ),
              ]),
            ),
            if (_selected.isNotEmpty)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: AppButton(
                  label: tr(
                      ref,
                      'mobile.shop.clients.sendSmsBtn',
                      '{{n}} ta mijozga SMS',
                      {'n': '${_selected.length}'}),
                  leadingIcon: Icons.send,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  loading: _sending,
                  onPressed: _sending ? null : _send,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _ClientRow extends ConsumerWidget {
  const _ClientRow({
    required this.c,
    required this.df,
    required this.selected,
    required this.onToggle,
  });
  final ShopClient c;
  final DateFormat df;
  final bool selected;
  final VoidCallback onToggle;

  Future<void> _call() async {
    AppHaptics.light();
    final clean = c.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Days since last visit → recency colour. Green = "faol", moving
  /// through amber/orange as the client goes quiet, red when they
  /// haven't been in for two months. Applied to both the avatar ring
  /// and the small "kecha / 3 kun oldin" pill so the eye can scan
  /// the list and spot dormant clients without reading text.
  Color _recencyColour(BuildContext context) {
    final v = c.lastVisit;
    if (v == null) return context.colors.textMuted;
    final days = DateTime.now().difference(v).inDays;
    if (days <= 7) return AppColors.success;
    if (days <= 20) return AppColors.warning;
    if (days <= 60) return const Color(0xFFF97316); // orange-500
    return AppColors.danger;
  }

  /// Humanised time ago — 'Bugun / Kecha / 3 kun oldin / 2 hafta
  /// oldin / 3 oy oldin'. Falls back to the DateFormat pattern for
  /// visits older than a year so it's still readable.
  String _lastVisitLabel(WidgetRef ref) {
    final v = c.lastVisit;
    if (v == null) return '—';
    final now = DateTime.now();
    final target = DateTime(v.year, v.month, v.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(target).inDays;
    if (diff <= 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.yesterday', 'Kecha');
    if (diff < 7) {
      return '$diff ${tr(ref, 'mobile.dates.daysAgo', 'kun oldin')}';
    }
    if (diff < 30) {
      final w = (diff / 7).floor();
      return '$w ${tr(ref, 'mobile.dates.weeksAgo', 'hafta oldin')}';
    }
    if (diff < 365) {
      final m = (diff / 30).floor();
      return '$m ${tr(ref, 'mobile.dates.monthsAgo', 'oy oldin')}';
    }
    return df.format(v.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ring = _recencyColour(context);
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      onTap: () =>
          context.push('/shop/clients/${Uri.encodeComponent(c.phone)}'),
      color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
      borderColor: selected ? AppColors.primary : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Compact checkbox tap area on the left. Kept always-visible
          // rather than long-press-to-enter-selection because the bulk
          // SMS send is the reason this screen exists — hiding the
          // primary control behind a gesture makes the shop owner
          // hunt for it.
          TapScale(
            onTap: onToggle,
            scale: 0.85,
            haptic: HapticStrength.none,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                selected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: selected
                    ? AppColors.primary
                    : context.colors.textMuted,
                size: 22,
              ),
            ),
          ),
          AppSpacing.hGapSm,
          // Avatar with recency ring — the ring colour reflects how
          // recently the client visited so the shop owner can scan
          // for dormant clients (red rings) without reading the
          // 'kecha / oy oldin' text on each row.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                (c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
                style: AppText.titleSm.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          AppSpacing.hGapMd,
          // Name + phone + last-visit chip.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      c.name.isEmpty ? c.phone : c.name,
                      style: AppText.titleSm.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (c.bookingsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.14),
                        borderRadius: AppRadius.rPill,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.event_available_outlined,
                            size: 10, color: AppColors.success),
                        const SizedBox(width: 3),
                        Text(
                          '${c.bookingsCount}',
                          style: AppText.overline.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ]),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(
                  c.phone.isEmpty ? '—' : c.phone,
                  style: AppText.caption.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                if (c.lastVisit != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ring.withValues(alpha: 0.12),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule, size: 10, color: ring),
                      const SizedBox(width: 3),
                      Text(
                        _lastVisitLabel(ref),
                        style: AppText.overline.copyWith(
                          color: ring,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.hGapSm,
          // Call button.
          TapScale(
            onTap: c.phone.isEmpty ? null : _call,
            scale: 0.9,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_outlined,
                  color: AppColors.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
