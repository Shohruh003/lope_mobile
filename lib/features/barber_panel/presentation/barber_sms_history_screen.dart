import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sms_history_repository.dart';

class BarberSmsHistoryScreen extends ConsumerStatefulWidget {
  const BarberSmsHistoryScreen({super.key});

  @override
  ConsumerState<BarberSmsHistoryScreen> createState() =>
      _BarberSmsHistoryScreenState();
}

class _BarberSmsHistoryScreenState
    extends ConsumerState<BarberSmsHistoryScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm');
  static final _dateOnly = DateFormat('yyyy-MM-dd');

  static const _pageSize = 30;

  String _type = 'all';
  DateTime? _from;
  DateTime? _to;

  // Infinite-scroll bookkeeping. Was: single-page smsHistoryFilteredProvider
  // watched via ref.watch with no way for the barber to reach page 2 —
  // effectively hiding SMS 21..N on any account with a busy history.
  // Now accumulates rows locally and triggers the next fetch as the
  // scroll approaches the bottom.
  final ScrollController _scrollController = ScrollController();
  final List<SmsLogEntry> _items = [];
  int _currentPage = 0; // 0 = nothing loaded yet
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 400) return;
    if (_loadingMore || _initialLoading || !_hasMore) return;
    _loadPage(_currentPage + 1);
  }

  Future<void> _loadPage(int page) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    if (page == 1) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final chunk = await ref.read(smsHistoryRepositoryProvider).fetch(
            barberId: user.id,
            page: page,
            limit: _pageSize,
            type: _type == 'all' ? null : _type,
            from: _from == null ? null : _dateOnly.format(_from!),
            to: _to == null ? null : _dateOnly.format(_to!),
          );
      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _items
            ..clear()
            ..addAll(chunk);
        } else {
          _items.addAll(chunk);
        }
        _currentPage = page;
        // Backend doesn't return totalPages here so we infer 'last page
        // reached' by a short chunk. A page that fills is a signal
        // that another page might exist.
        _hasMore = chunk.length >= _pageSize;
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _error = e;
      });
    }
  }

  void _resetAndReload() {
    setState(() {
      _items.clear();
      _currentPage = 0;
      _hasMore = true;
      _error = null;
    });
    _loadPage(1);
  }

  Future<void> _pickDate(bool isFrom) async {
    AppHaptics.light();
    final initial = (isFrom ? _from : _to) ?? DateTime.now();
    final first = DateTime(2024);
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    if (isFrom) {
      _from = picked;
    } else {
      _to = picked;
    }
    _resetAndReload();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.sms.title', 'SMS tarixi'),
          style: AppText.titleMd,
        ),
      ),
      body: Column(
        children: [
          _FilterBar(
            type: _type,
            from: _from,
            to: _to,
            allLabel: tr(ref, 'common.all', 'Hammasi'),
            confirmLabel:
                tr(ref, 'mobile.barber.sms.typeConfirm', 'Tasdiqlash'),
            reminderLabel:
                tr(ref, 'mobile.barber.sms.typeReminder', 'Eslatma'),
            retentionLabel:
                tr(ref, 'mobile.barber.sms.typeRetention', 'Qayta jalb'),
            onType: (v) {
              _type = v;
              _resetAndReload();
            },
            onFromTap: () => _pickDate(true),
            onToTap: () => _pickDate(false),
            onClearDates: () {
              _from = null;
              _to = null;
              _resetAndReload();
            },
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_initialLoading) {
      return const AppListSkeleton();
    }
    final err = _error;
    if (err != null) {
      return AppErrorState(
        message: humanize(err),
        onRetry: () => _loadPage(1),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadPage(1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: AppEmptyState(
                icon: Icons.sms_outlined,
                title:
                    tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadPage(1),
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
            AppSpacing.lg, AppSpacing.pageBottom(context)),
        // + 1 slot at the tail for the loading-more spinner / done sentinel.
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => AppSpacing.gapSm,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          }
          final s = _items[i];
          final ok = s.status == 'delivered' ||
              s.status == 'sent' ||
              s.status == 'success';
          final delayMs = (i * 30).clamp(0, 400);
          return AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.phone, style: AppText.titleSm),
                    ),
                    if ((s.type ?? '').isNotEmpty) ...[
                      AppBadge(
                        label: switch (s.type!.toLowerCase()) {
                          'confirmation' => tr(
                              ref,
                              'mobile.barber.sms.typeConfirm',
                              'Tasdiqlash'),
                          'reminder' => tr(
                              ref,
                              'mobile.barber.sms.typeReminder',
                              'Eslatma'),
                          'retention' => tr(
                              ref,
                              'mobile.barber.sms.typeRetention',
                              'Qayta jalb'),
                          _ => s.type!,
                        },
                        variant: AppBadgeVariant.info,
                      ),
                      AppSpacing.hGapXs,
                    ],
                    AppBadge(
                      label: ok
                          ? tr(ref, 'mobile.barber.sms.statusOk',
                              'delivered')
                          : tr(ref, 'mobile.barber.sms.statusFail',
                              'failed'),
                      variant: ok
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.danger,
                      dot: true,
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: AppRadius.rSm,
                  ),
                  child: Text(
                    s.message,
                    style: AppText.bodySm.copyWith(
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                AppSpacing.gapXs,
                Text(_df.format(s.createdAt.toLocal()),
                    style: AppText.caption),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms, delay: delayMs.ms).slideY(
              begin: 0.1, end: 0);
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.from,
    required this.to,
    required this.allLabel,
    required this.confirmLabel,
    required this.reminderLabel,
    required this.retentionLabel,
    required this.onType,
    required this.onFromTap,
    required this.onToTap,
    required this.onClearDates,
  });
  final String type;
  final DateTime? from;
  final DateTime? to;
  final String allLabel;
  final String confirmLabel;
  final String reminderLabel;
  final String retentionLabel;
  final ValueChanged<String> onType;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onClearDates;

  static final _short = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppChip(
                  label: allLabel,
                  selected: type == 'all',
                  onTap: () => onType('all'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: confirmLabel,
                  selected: type == 'confirmation',
                  onTap: () => onType('confirmation'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: reminderLabel,
                  selected: type == 'reminder',
                  onTap: () => onType('reminder'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: retentionLabel,
                  selected: type == 'retention',
                  onTap: () => onType('retention'),
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label:
                      from == null ? 'dd.mm.yyyy' : _short.format(from!),
                  onTap: onFromTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs),
                child: Text('—',
                    style: TextStyle(color: context.colors.textMuted)),
              ),
              Expanded(
                child: _DateField(
                  label:
                      to == null ? 'dd.mm.yyyy' : _short.format(to!),
                  onTap: onToTap,
                ),
              ),
              if (from != null || to != null) ...[
                AppSpacing.hGapXs,
                TapScale(
                  onTap: onClearDates,
                  scale: 0.85,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 16, color: context.colors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined,
              size: 14, color: context.colors.textMuted),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm,
            ),
          ),
        ]),
      ),
    );
  }
}
