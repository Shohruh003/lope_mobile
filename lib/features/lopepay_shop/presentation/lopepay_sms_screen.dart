import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';

class LopepaySmsScreen extends ConsumerStatefulWidget {
  const LopepaySmsScreen({super.key});
  @override
  ConsumerState<LopepaySmsScreen> createState() => _LopepaySmsScreenState();
}

class _LopepaySmsScreenState extends ConsumerState<LopepaySmsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 20;

  String _phone = '';
  String _type = 'all';
  String? _productId;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  LopepaySmsKey get _key => (
        phone: _phone.isEmpty ? null : _phone,
        type: _type == 'all' ? null : _type,
        productId: _productId,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
        page: _page,
      );

  String _typeLabel(WidgetRef ref, String t) {
    switch (t) {
      case 'INSTALLMENT_PRE_DUE':
        return tr(ref, 'mobile.lopepay.sms.typePreDue', 'Ertaga eslatma');
      case 'INSTALLMENT_DUE':
        return tr(ref, 'mobile.lopepay.sms.typeDue', "Bugun to'lov");
      case 'INSTALLMENT_OVERDUE':
        return tr(ref, 'mobile.lopepay.sms.typeOverdue', 'Kechikkan');
      default:
        return t;
    }
  }

  AppBadgeVariant _typeVariant(String t) {
    switch (t) {
      case 'INSTALLMENT_PRE_DUE':
        return AppBadgeVariant.info;
      case 'INSTALLMENT_DUE':
        return AppBadgeVariant.warning;
      case 'INSTALLMENT_OVERDUE':
        return AppBadgeVariant.danger;
      default:
        return AppBadgeVariant.neutral;
    }
  }

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
      _phone = '';
      _type = 'all';
      _productId = null;
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepaySmsFilteredProvider(_key));
    final productsAsync = ref.watch(lopepayProductsProvider);

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
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.rMd,
              border: Border.all(color: context.colors.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() {
                _phone = v;
                _page = 1;
              }),
              style: AppText.body,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
                prefixIcon: Icon(Icons.search,
                    color: context.colors.textMuted, size: 20),
                hintText: tr(ref, 'lopePay.shop.filterPhone', "Telefon raqami"),
                hintStyle: AppText.body.copyWith(color: context.colors.textMuted),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              AppChip(
                  label: tr(ref, 'common.all', "Hammasi"),
                  selected: _type == 'all',
                  onTap: () => setState(() {
                        _type = 'all';
                        _page = 1;
                      })),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: _typeLabel(ref, 'INSTALLMENT_PRE_DUE'),
                  selected: _type == 'INSTALLMENT_PRE_DUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_PRE_DUE';
                        _page = 1;
                      })),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: _typeLabel(ref, 'INSTALLMENT_DUE'),
                  selected: _type == 'INSTALLMENT_DUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_DUE';
                        _page = 1;
                      })),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: _typeLabel(ref, 'INSTALLMENT_OVERDUE'),
                  selected: _type == 'INSTALLMENT_OVERDUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_OVERDUE';
                        _page = 1;
                      })),
            ],
          ),
        ),
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.xs),
            child: AppCard(
              variant: AppCardVariant.flat,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    productsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (products) => DropdownButtonFormField<String?>(
                        isDense: true,
                        initialValue: _productId,
                        decoration: InputDecoration(
                          labelText: tr(ref, 'lopePay.shop.filterProduct',
                              "Mahsulot"),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child:
                                  Text(tr(ref, 'common.all', "Hammasi"))),
                          ...products.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() {
                          _productId = v;
                          _page = 1;
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                          child: _DatePill(
                              label: _from == null
                                  ? tr(ref, 'lopePay.shop.filterFrom', "Dan")
                                  : _ymd.format(_from!),
                              onTap: () => _pickDate(true))),
                      const SizedBox(width: AppSpacing.sm),
                      Text("вЂ”",
                          style: TextStyle(color: context.colors.textMuted)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                          child: _DatePill(
                              label: _to == null
                                  ? tr(ref, 'lopePay.shop.filterTo', "Gacha")
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
            error: (e, _) => AppErrorState(message: humanize(e)),
            data: (res) {
              final list = res.data;
              final pages = (res.total / _pageSize).ceil();
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.sms_outlined,
                  title: tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepaySmsFilteredProvider);
                  ref.invalidate(lopepaySmsProvider);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.pageBottom(context)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final type = (s['type'] ?? '').toString();
                      final inst = s['installment'] is Map
                          ? (s['installment'] as Map).cast<String, dynamic>()
                          : <String, dynamic>{};
                      final phone = (inst['customerPhone'] ??
                              s['phone'] ??
                              '')
                          .toString();
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
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius: AppRadius.rSm,
                                  ),
                                  child: const Icon(Icons.mark_email_read,
                                      size: 16, color: AppColors.success),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                    child: Text(phone,
                                        style: AppText.titleSm
                                            .copyWith(fontSize: 14))),
                                AppBadge(
                                  label: tr(ref, 'mobile.barber.sms.statusOk',
                                      'delivered'),
                                  variant: AppBadgeVariant.success,
                                ),
                              ]),
                              if (type.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                AppBadge(
                                  label: _typeLabel(ref, type),
                                  variant: _typeVariant(type),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              Text((s['message'] ?? '').toString(),
                                  style: AppText.bodySm),
                              if ((s['sentAt'] ?? s['createdAt']) != null) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Row(children: [
                                  Icon(Icons.schedule,
                                      size: 12, color: context.colors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                      _df.format(DateTime.parse(
                                              (s['sentAt'] ??
                                                      s['createdAt'])
                                                  .toString())
                                          .toLocal()),
                                      style: AppText.caption),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms, delay: (i * 20).ms);
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
          color: context.colors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined,
              size: 14, color: context.colors.textMuted),
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
