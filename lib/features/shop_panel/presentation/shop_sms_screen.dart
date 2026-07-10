import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

class ShopSmsScreen extends ConsumerStatefulWidget {
  const ShopSmsScreen({super.key});
  @override
  ConsumerState<ShopSmsScreen> createState() => _ShopSmsScreenState();
}

class _ShopSmsScreenState extends ConsumerState<ShopSmsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 30;

  String? _barberId;
  String _type = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  ShopSmsKey get _key => (
        barberId: _barberId,
        type: _type == 'all' ? null : _type,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
        page: _page,
      );

  Future<void> _pickDate(bool isFrom) async {
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 1;
    });
  }

  void _resetFilters() {
    AppHaptics.selection();
    setState(() {
      _barberId = null;
      _type = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'confirmation':
        return tr(ref, 'shop.smsTypes.confirmation', "Tasdiqlash");
      case 'reminder':
        return tr(ref, 'shop.smsTypes.reminder', "Eslatma");
      case 'retention':
        return tr(ref, 'shop.smsTypes.retention', "Qaytarish");
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopSmsFilteredProvider(_key));
    final barbersAsync = ref.watch(shopBarbersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.sms.title', "SMS tarixi"),
            style: AppText.titleMd),
        actions: [
          IconButton(
            icon: Icon(
                _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                color: _filtersOpen ? AppColors.primary : null),
            onPressed: () {
              AppHaptics.selection();
              setState(() => _filtersOpen = !_filtersOpen);
            },
          ),
        ],
      ),
      body: Column(children: [
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: AppCard(
              variant: AppCardVariant.flat,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    barbersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (barbers) => DropdownButtonFormField<String?>(
                        isDense: true,
                        initialValue: _barberId,
                        decoration: InputDecoration(
                          labelText: tr(ref, 'shop.filter.barber', "Master"),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child: Text(
                                  tr(ref, 'shop.filter.allBarbers', "Barchasi"))),
                          ...barbers.map((b) => DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() {
                          _barberId = v;
                          _page = 1;
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      isDense: true,
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: tr(ref, 'shop.filter.type', "Turi"),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text(tr(ref, 'common.all', "Hammasi"))),
                        DropdownMenuItem(
                            value: 'confirmation',
                            child: Text(_typeLabel('confirmation'))),
                        DropdownMenuItem(
                            value: 'reminder',
                            child: Text(_typeLabel('reminder'))),
                        DropdownMenuItem(
                            value: 'retention',
                            child: Text(_typeLabel('retention'))),
                      ],
                      onChanged: (v) => setState(() {
                        _type = v ?? 'all';
                        _page = 1;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                          child: _DatePill(
                              label: _from == null
                                  ? tr(ref, 'shop.filter.from', "Dan")
                                  : _ymd.format(_from!),
                              onTap: () => _pickDate(true))),
                      const SizedBox(width: AppSpacing.sm),
                      const Text("—",
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _DatePill(
                              label: _to == null
                                  ? tr(ref, 'shop.filter.to', "Gacha")
                                  : _ymd.format(_to!),
                              onTap: () => _pickDate(false))),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: tr(ref, 'common.reset', "Tozalash"),
                      leadingIcon: Icons.refresh,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.sm,
                      fullWidth: true,
                      onPressed: _resetFilters,
                    ),
                  ]),
            ),
          ),
        Expanded(
          child: async.when(
            loading: () => const AppListSkeleton(),
            error: (e, _) => AppErrorState(
              message: humanize(e),
              onRetry: () {
                ref.invalidate(shopSmsFilteredProvider);
                ref.invalidate(shopSmsLogProvider);
              },
            ),
            data: (res) {
              final list = res.data;
              final pages = (res.total / _pageSize).ceil();
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.sms_outlined,
                  title: tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
                  message: tr(
                    ref,
                    'mobile.barber.sms.emptyHint',
                    "Yuborilgan SMS'lar shu yerda ko'rinadi.",
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(shopSmsFilteredProvider);
                  ref.invalidate(shopSmsLogProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final ok = s.status == 'delivered' ||
                          s.status == 'sent' ||
                          s.status == 'success';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          variant: AppCardVariant.flat,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: (ok
                                            ? AppColors.success
                                            : AppColors.danger)
                                        .withValues(alpha: 0.15),
                                    borderRadius: AppRadius.rSm,
                                  ),
                                  child: Icon(
                                      ok
                                          ? Icons.mark_email_read
                                          : Icons.error_outline,
                                      size: 16,
                                      color: ok
                                          ? AppColors.success
                                          : AppColors.danger),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                    child: Text(s.phone,
                                        style: AppText.titleSm
                                            .copyWith(fontSize: 14))),
                                AppBadge(
                                  label: ok
                                      ? tr(ref,
                                          'mobile.barber.sms.statusOk',
                                          'delivered')
                                      : tr(ref,
                                          'mobile.barber.sms.statusFail',
                                          'failed'),
                                  variant: ok
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.danger,
                                ),
                              ]),
                              const SizedBox(height: AppSpacing.sm),
                              Text(s.message, style: AppText.bodySm),
                              const SizedBox(height: AppSpacing.sm),
                              Row(children: [
                                const Icon(Icons.schedule,
                                    size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(_df.format(s.createdAt.toLocal()),
                                    style: AppText.caption),
                              ]),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          duration: 200.ms, delay: (i * 20).ms);
                    }),
                    if (pages > 1) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppButton(
                            label: tr(ref, 'common.prev', "Oldingi"),
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            leadingIcon: Icons.chevron_left,
                            onPressed: _page <= 1
                                ? null
                                : () => setState(() => _page--),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadius.rPill,
                            ),
                            child: Text("$_page / $pages",
                                style: AppText.button
                                    .copyWith(color: AppColors.primary)),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          AppButton(
                            label: tr(ref, 'common.next', "Keyingi"),
                            variant: AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            trailingIcon: Icons.chevron_right,
                            onPressed: _page >= pages
                                ? null
                                : () => setState(() => _page++),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
