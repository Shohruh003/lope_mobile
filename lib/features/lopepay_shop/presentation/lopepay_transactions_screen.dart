import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';

class LopepayTransactionsScreen extends ConsumerStatefulWidget {
  const LopepayTransactionsScreen({super.key});
  @override
  ConsumerState<LopepayTransactionsScreen> createState() =>
      _LopepayTransactionsScreenState();
}

class _LopepayTransactionsScreenState
    extends ConsumerState<LopepayTransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 20;

  String _type = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  LopepayTxnKey get _key => (
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
      _type = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'topup':
        return tr(ref, 'mobile.lopepay.txn.typeTopup', "Hisob to'ldirildi");
      case 'sms_deduction':
        return tr(ref, 'mobile.lopepay.txn.typeSms', "SMS to'lovi");
      case 'ai_deduction':
        return tr(ref, 'mobile.lopepay.txn.typeAi', "AI to'lovi");
      case 'referral_bonus':
        return tr(ref, 'mobile.lopepay.txn.typeReferral', "Referral");
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepayTxnFilteredProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: Text(
            tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"),
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
                    DropdownButtonFormField<String>(
                      isDense: true,
                      initialValue: _type,
                      decoration: InputDecoration(
                          labelText:
                              tr(ref, 'lopePay.shop.filterType', "Turi")),
                      items: [
                        DropdownMenuItem(
                            value: 'all',
                            child: Text(tr(ref, 'common.all', "Hammasi"))),
                        DropdownMenuItem(
                            value: 'topup',
                            child: Text(_typeLabel('topup'))),
                        DropdownMenuItem(
                            value: 'sms_deduction',
                            child: Text(_typeLabel('sms_deduction'))),
                        DropdownMenuItem(
                            value: 'ai_deduction',
                            child: Text(_typeLabel('ai_deduction'))),
                        DropdownMenuItem(
                            value: 'referral_bonus',
                            child: Text(_typeLabel('referral_bonus'))),
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
            error: (e, _) => AppErrorState(
              message: humanize(e),
              onRetry: () {
                ref.invalidate(lopepayTxnFilteredProvider);
                ref.invalidate(lopepayTxnProvider);
              },
            ),
            data: (res) {
              final list = res.data;
              final pages = (res.total / _pageSize).ceil();
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepayTxnFilteredProvider);
                  ref.invalidate(lopepayTxnProvider);
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.pageBottom(context)),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.rLg,
                        boxShadow: AppShadows.primaryGlow(AppColors.primary),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.account_balance_wallet,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                  tr(ref, 'lopePay.shop.currentBalance',
                                      "Joriy balans"),
                                  style: AppText.overline
                                      .copyWith(color: Colors.white70)),
                              const SizedBox(height: 2),
                              Text(
                                  "${_fmt(res.balance)} ${tr(ref, 'common.currency', "so'm")}",
                                  style: AppText.titleLg
                                      .copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                              tr(ref, 'mobile.customer.transactions.empty',
                                  "Tranzaktsiya yo'q"),
                              style: AppText.bodySm),
                        ),
                      )
                    else
                      ...list.asMap().entries.map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        final amount = ((t['amount'] ?? 0) as num).toInt();
                        final inflow = amount > 0;
                        final type = (t['type'] ?? '').toString();
                        final description =
                            (t['description'] ?? '').toString();
                        final color =
                            inflow ? AppColors.success : AppColors.danger;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            variant: AppCardVariant.flat,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      color.withValues(alpha: 0.22),
                                      color.withValues(alpha: 0.08),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: AppRadius.rMd,
                                ),
                                child: Icon(
                                    inflow
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: color,
                                    size: 18),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      AppBadge(
                                        label: type.isEmpty
                                            ? 'вЂ”'
                                            : _typeLabel(type),
                                        variant: AppBadgeVariant.neutral,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Flexible(
                                        child: Text(
                                            t['createdAt'] != null
                                                ? _df.format(DateTime.parse(
                                                        t['createdAt']
                                                            .toString())
                                                    .toLocal())
                                                : '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.caption
                                                .copyWith(fontSize: 11)),
                                      ),
                                    ]),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.caption),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                  "${inflow ? '+' : 'в€’'}${_fmt(amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                                  style: AppText.titleSm.copyWith(
                                      color: color, fontSize: 14)),
                            ]),
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
