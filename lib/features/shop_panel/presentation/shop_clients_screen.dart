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
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  String _query = '';
  String _bucket = 'all';
  final Set<String> _selected = {};
  bool _sending = false;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(
                ref,
                'mobile.shop.clients.bulkSendQueued',
                "{{n}} ta SMS navbatga qo'shildi",
                {'n': '${res.total}'}))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggleSelectAll(List<ShopClient> visible) {
    AppHaptics.selection();
    final allSelected =
        visible.every((c) => _selected.contains(c.phone));
    setState(() {
      if (allSelected) {
        for (final c in visible) {
          _selected.remove(c.phone);
        }
      } else {
        for (final c in visible) {
          if (c.phone.isNotEmpty) _selected.add(c.phone);
        }
      }
    });
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xs,
                  ),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.rMd,
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
                            const EdgeInsets.symmetric(vertical: 12),
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
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    children: [
                      AppChip(
                        label: tr(ref, 'common.all', 'Hammasi'),
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
                if (filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Row(children: [
                      TapScale(
                        onTap: () => _toggleSelectAll(filtered),
                        scale: 0.95,
                        child: Row(children: [
                          Icon(
                            filtered
                                    .every((c) =>
                                        _selected.contains(c.phone))
                                ? Icons.check_box
                                : (filtered.any((c) =>
                                        _selected.contains(c.phone))
                                    ? Icons.indeterminate_check_box
                                    : Icons.check_box_outline_blank),
                            size: 20,
                            color: AppColors.primary,
                          ),
                          AppSpacing.hGapXs,
                          Text(
                            tr(
                                ref,
                                'mobile.shop.clients.selectAll',
                                'Hammasini tanlash'),
                            style: AppText.bodySm.copyWith(
                              color: context.colors.textBright,
                            ),
                          ),
                        ]),
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length}',
                        style: AppText.caption,
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

class _ClientRow extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      onTap: () =>
          context.push('/shop/clients/${Uri.encodeComponent(c.phone)}'),
      borderColor:
          selected ? AppColors.primary : null,
      child: Row(children: [
        TapScale(
          onTap: onToggle,
          scale: 0.8,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              selected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color:
                  selected ? AppColors.primary : context.colors.textMuted,
              size: 22,
            ),
          ),
        ),
        AppSpacing.hGapXs,
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
              style: AppText.titleMd,
            ),
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.name.isEmpty ? c.phone : c.name,
                style: AppText.titleSm,
              ),
              if (c.phone.isNotEmpty)
                Text(c.phone, style: AppText.caption),
              Consumer(builder: (context, ref, _) {
                if (c.lastVisit == null) return const SizedBox.shrink();
                return Text(
                    "${tr(ref, 'barberMyClients.lastVisit', 'Oxirgi tashrif')}: ${df.format(c.lastVisit!.toLocal())}",
                    style: AppText.caption);
              }),
            ],
          ),
        ),
        AppSpacing.hGapSm,
        if (c.bookingsCount > 0)
          AppBadge(
            label: '${c.bookingsCount}',
            variant: AppBadgeVariant.success,
          ),
        AppSpacing.hGapXs,
        TapScale(
          onTap: c.phone.isEmpty ? null : _call,
          scale: 0.9,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_outlined,
                color: AppColors.primary, size: 18),
          ),
        ),
      ]),
    );
  }
}
