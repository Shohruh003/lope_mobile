import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

/// Mirrors web `BarbershopTransactions.tsx`:
///   - Balance hero up top
///   - Filter chips (All / +Income / -Expense / Topup / SMS / AI / Bonus)
///     → mapped to server-side type+direction params
///   - Filter button → collapsible panel: barber, smsType, from/to dates
///   - Server-side pagination + Prev/Next
class ShopTransactionsScreen extends ConsumerStatefulWidget {
  const ShopTransactionsScreen({super.key});
  @override
  ConsumerState<ShopTransactionsScreen> createState() =>
      _ShopTransactionsScreenState();
}

class _ShopTransactionsScreenState
    extends ConsumerState<ShopTransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 20;

  String _chip = 'all'; // ui-only — maps to type/direction below
  String? _barberId;
  String _smsType = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  ({String? type, String? direction}) _chipToParams() {
    switch (_chip) {
      case 'in':
        return (type: null, direction: 'income');
      case 'out':
        return (type: null, direction: 'expense');
      case 'topup':
        return (type: 'topup', direction: null);
      case 'sms':
        return (type: 'sms_deduction', direction: null);
      case 'ai':
        return (type: 'ai_deduction', direction: null);
      case 'bonus':
        return (type: 'referral_bonus', direction: null);
      default:
        return (type: null, direction: null);
    }
  }

  ShopTxnKey get _key {
    final p = _chipToParams();
    return (
      type: p.type,
      direction: p.direction,
      barberId: _barberId,
      smsType: _smsType == 'all' ? null : _smsType,
      from: _from == null ? null : _ymd.format(_from!),
      to: _to == null ? null : _ymd.format(_to!),
      page: _page,
    );
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

  void _resetAdvancedFilters() {
    setState(() {
      _barberId = null;
      _smsType = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  String _methodLabel(WidgetRef ref, String m) {
    switch (m) {
      case 'click':
        return tr(ref, 'mobile.customer.transactions.methodClick',
            "Click to'lov");
      case 'payme':
        return tr(ref, 'mobile.customer.transactions.methodPayme',
            "Payme to'lov");
      case 'telegram':
        return tr(ref, 'mobile.customer.transactions.methodTelegram',
            'Telegram bonus');
      case 'sms':
        return tr(
            ref, 'mobile.customer.transactions.methodSms', 'SMS xizmat');
      case 'ai':
        return tr(ref, 'mobile.customer.transactions.methodAi', 'AI Stil');
      case 'referral':
        return tr(ref, 'mobile.customer.transactions.methodReferral',
            'Referal bonus');
      default:
        return tr(ref, 'mobile.customer.transactions.methodDefault',
            'Tranzaktsiya');
    }
  }

  String _smsTypeLabel(String t) {
    switch (t) {
      case 'CONFIRMATION':
        return tr(ref, 'shop.smsTypes.confirmation', 'Tasdiqlash');
      case 'REMINDER':
        return tr(ref, 'shop.smsTypes.reminder', 'Eslatma');
      case 'RETENTION':
        return tr(ref, 'shop.smsTypes.retention', 'Qaytarish');
      default:
        return tr(ref, 'common.all', 'Hammasi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopTxnFilteredProvider(_key));
    final balanceAsync = ref.watch(shopBalanceProvider);
    final barbersAsync = ref.watch(shopBarbersProvider);

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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(shopTxnFilteredProvider);
          ref.invalidate(shopTransactionsProvider);
          ref.invalidate(shopBalanceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ===== Balance card =====
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tr(ref, 'mobile.lopepay.home.balance', "Balans"),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      balanceAsync.when(
                        loading: () => const Text("…",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                        error: (_, _) => const Text("—",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                        data: (b) => Text(
                            "${_fmt(b)} ${tr(ref, 'common.currency', "so'm")}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3)),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // ===== Filter chips =====
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _Chip(
                      label: tr(ref, 'common.all', "Hammasi"),
                      on: _chip == 'all',
                      onTap: () => setState(() {
                            _chip = 'all';
                            _page = 1;
                          })),
                  _Chip(
                      label:
                          "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} +",
                      on: _chip == 'in',
                      onTap: () => setState(() {
                            _chip = 'in';
                            _page = 1;
                          })),
                  _Chip(
                      label:
                          "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} −",
                      on: _chip == 'out',
                      onTap: () => setState(() {
                            _chip = 'out';
                            _page = 1;
                          })),
                  _Chip(
                      label: tr(ref, 'mobile.customer.transactions.topUp',
                          "To'ldirish"),
                      on: _chip == 'topup',
                      onTap: () => setState(() {
                            _chip = 'topup';
                            _page = 1;
                          })),
                  _Chip(
                      label: 'SMS',
                      on: _chip == 'sms',
                      onTap: () => setState(() {
                            _chip = 'sms';
                            _page = 1;
                          })),
                  _Chip(
                      label: 'AI',
                      on: _chip == 'ai',
                      onTap: () => setState(() {
                            _chip = 'ai';
                            _page = 1;
                          })),
                  _Chip(
                      label: tr(ref,
                          'mobile.customer.transactions.methodReferral',
                          "Bonus"),
                      on: _chip == 'bonus',
                      onTap: () => setState(() {
                            _chip = 'bonus';
                            _page = 1;
                          })),
                ],
              ),
            ),

            // ===== Advanced filter panel =====
            if (_filtersOpen) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
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
                            labelText:
                                tr(ref, 'shop.filter.barber', "Master"),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: null,
                                child: Text(tr(ref, 'shop.filter.allBarbers',
                                    "Barchasi"))),
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
                      const SizedBox(height: 10),
                      // smsType only meaningful when SMS chip is selected;
                      // shown unconditionally for parity with web.
                      DropdownButtonFormField<String>(
                        isDense: true,
                        initialValue: _smsType,
                        decoration: InputDecoration(
                            labelText:
                                tr(ref, 'shop.smsTypes.label', "SMS turi")),
                        items: [
                          DropdownMenuItem(
                              value: 'all',
                              child: Text(_smsTypeLabel('all'))),
                          DropdownMenuItem(
                              value: 'CONFIRMATION',
                              child: Text(_smsTypeLabel('CONFIRMATION'))),
                          DropdownMenuItem(
                              value: 'REMINDER',
                              child: Text(_smsTypeLabel('REMINDER'))),
                          DropdownMenuItem(
                              value: 'RETENTION',
                              child: Text(_smsTypeLabel('RETENTION'))),
                        ],
                        onChanged: (v) => setState(() {
                          _smsType = v ?? 'all';
                          _page = 1;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _DatePill(
                                label: _from == null
                                    ? tr(ref, 'shop.filter.from', "Dan")
                                    : _ymd.format(_from!),
                                onTap: () => _pickDate(true))),
                        const SizedBox(width: 8),
                        const Text("—",
                            style:
                                TextStyle(color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _DatePill(
                                label: _to == null
                                    ? tr(ref, 'shop.filter.to', "Gacha")
                                    : _ymd.format(_to!),
                                onTap: () => _pickDate(false))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 16),
                            label:
                                Text(tr(ref, 'common.reset', "Tozalash")),
                            onPressed: _resetAdvancedFilters,
                          ),
                        ),
                      ]),
                    ]),
              ),
            ],
            const SizedBox(height: 12),

            // ===== List =====
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                        style: const TextStyle(color: AppColors.textMuted))),
              ),
              data: (res) {
                final list = res.data;
                final pages = (res.total / _pageSize).ceil();
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                          tr(ref, 'mobile.customer.transactions.empty',
                              "Tranzaktsiya yo'q"),
                          style: const TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return Column(children: [
                  ...list.asMap().entries.map((e) {
                    final t = e.value;
                    final inflow = t.direction == 'in' || t.amount > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: (inflow
                                      ? AppColors.success
                                      : AppColors.danger)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                inflow
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                                color: inflow
                                    ? AppColors.success
                                    : AppColors.danger),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    t.description ??
                                        _methodLabel(ref, t.method),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_df.format(t.createdAt.toLocal()),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                              "${inflow ? '+' : '−'}${_fmt(t.amount)} ${tr(ref, 'common.currency', "so'm")}",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: inflow
                                      ? AppColors.success
                                      : AppColors.danger)),
                        ]),
                      ).animate().fadeIn(
                          duration: 250.ms, delay: (e.key * 25).ms),
                    );
                  }),
                  if (pages > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: _page <= 1
                              ? null
                              : () => setState(() => _page--),
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
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: on ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? AppColors.primary : AppColors.textMuted)),
        ),
      ),
    );
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
