import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Mirrors web `ShopTransactions.tsx`:
///   - "Current balance" card up top
///   - Filter button → collapsible panel: type (topup/sms_deduction/all), from/to dates
///   - List of transaction rows with arrow icon, type badge, date, description, amount
///   - Prev / Next pagination at bottom when total > limit
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
        title: Text(tr(ref, 'mobile.customer.transactions.history',
            "Tranzaktsiyalar")),
        actions: [
          IconButton(
            icon: Icon(
                _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                color: _filtersOpen ? AppColors.primary : null),
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      ),
      body: Column(children: [
        // ===== Filter panel =====
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: _type,
                  decoration: InputDecoration(
                      labelText: tr(ref, 'lopePay.shop.filterType', "Turi")),
                  items: [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text(tr(ref, 'common.all', "Hammasi"))),
                    DropdownMenuItem(
                        value: 'topup', child: Text(_typeLabel('topup'))),
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
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _DatePill(
                          label: _from == null
                              ? tr(ref, 'lopePay.shop.filterFrom', "Dan")
                              : _ymd.format(_from!),
                          onTap: () => _pickDate(true))),
                  const SizedBox(width: 8),
                  const Text("—",
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _DatePill(
                          label: _to == null
                              ? tr(ref, 'lopePay.shop.filterTo', "Gacha")
                              : _ymd.format(_to!),
                          onTap: () => _pickDate(false))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(tr(ref, 'common.reset', "Tozalash")),
                      onPressed: _resetFilters,
                    ),
                  ),
                ]),
              ]),
            ),
          ),

        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted))),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // Balance hero card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                              Icons.account_balance_wallet,
                              color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  tr(ref, 'lopePay.shop.currentBalance',
                                      "Joriy balans"),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                      letterSpacing: 0.4,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  "${_fmt(res.balance)} ${tr(ref, 'common.currency', "so'm")}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                              tr(ref, 'mobile.customer.transactions.empty',
                                  "Tranzaktsiya yo'q"),
                              style:
                                  const TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    else
                      ...list.asMap().entries.map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        final amount = ((t['amount'] ?? 0) as num).toInt();
                        final inflow = amount > 0;
                        final type = (t['type'] ?? '').toString();
                        final description = (t['description'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: (inflow
                                          ? AppColors.success
                                          : AppColors.danger)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                    inflow
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: inflow
                                        ? AppColors.success
                                        : AppColors.danger,
                                    size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Text(
                                            type.isEmpty
                                                ? '—'
                                                : _typeLabel(type),
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textBright)),
                                      ),
                                      const SizedBox(width: 6),
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
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 10)),
                                      ),
                                    ]),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  "${inflow ? '+' : '−'}${_fmt(amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: inflow
                                          ? AppColors.success
                                          : AppColors.danger,
                                      fontSize: 13)),
                            ]),
                          ),
                        ).animate().fadeIn(duration: 200.ms, delay: (i * 20).ms);
                      }),

                    // Pagination
                    if (pages > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed:
                                _page <= 1 ? null : () => setState(() => _page--),
                            child: Text(tr(ref, 'common.prev', "Oldingi")),
                          ),
                          const SizedBox(width: 12),
                          Text("$_page / $pages",
                              style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: _page >= pages
                                ? null
                                : () => setState(() => _page++),
                            child: Text(tr(ref, 'common.next', "Keyingi")),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
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
                style:
                    const TextStyle(color: AppColors.textBright, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
