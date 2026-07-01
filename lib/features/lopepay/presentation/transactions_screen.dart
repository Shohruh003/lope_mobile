import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';
import 'top_up_modal.dart';

/// Combined balance + payment history. Mirrors web MyTransactionsPage:
///   - Balance hero card (with top-up button)
///   - Income / Expense stats card (computed server-side per filter window)
///   - Direction chips (Hammasi / Kirim / Chiqim)
///   - Filter button → collapsible panel: method dropdown, from/to dates
///   - Prev/Next pagination
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');

  String _direction = 'all'; // 'all' | 'in' | 'out' → income/expense server-side
  String _method = 'all'; // 'all' | 'click' | 'payme' | 'telegram' | 'internal'
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  // Map direction chip to server param. Web sends 'income'/'expense'.
  String? _directionParam() {
    if (_direction == 'in') return 'income';
    if (_direction == 'out') return 'expense';
    return null;
  }

  PaymentHistoryKey _key(String userId) => (
        userId: userId,
        direction: _directionParam() ?? 'all',
        method: _method,
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
      _direction = 'all';
      _method = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'click':
        return tr(ref, 'mobile.customer.transactions.methodClick',
            "Click to'lov");
      case 'payme':
        return tr(ref, 'mobile.customer.transactions.methodPayme',
            "Payme to'lov");
      case 'telegram':
        return tr(ref, 'mobile.customer.transactions.methodTelegram',
            'Telegram');
      case 'internal':
        return tr(ref, 'mobile.customer.transactions.methodInternal',
            "Ichki");
      default:
        return tr(ref, 'common.all', 'Hammasi');
    }
  }

  String _methodRowLabel(WidgetRef ref, String m) {
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final balance = ref.watch(myBalanceProvider(user.id));
    final async = ref.watch(paymentHistoryFilteredProvider(_key(user.id)));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.customer.transactions.title', "Hisobim")),
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
          ref.invalidate(myBalanceProvider(user.id));
          ref.invalidate(paymentHistoryFilteredProvider);
          ref.invalidate(paymentHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ===== Balance hero =====
            balance.when(
              loading: () => Container(
                  height: 130,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20)),
                  child:
                      const Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(
                  "${tr(ref, 'common.error', 'Xatolik')}: $e",
                  style: const TextStyle(color: AppColors.textMuted)),
              data: (b) => _BalanceCard(
                  amount: b.amount, aiFree: b.aiFreeRemaining),
            ),

            // ===== Stats card (Income / Expense) =====
            async.maybeWhen(
              data: (res) => Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(children: [
                  Expanded(
                    child: _StatTile(
                        icon: Icons.trending_up,
                        color: AppColors.success,
                        label: tr(ref, 'mobile.customer.transactions.income',
                            "Kirim"),
                        value:
                            "${_fmt(res.totalIncome)} ${tr(ref, 'common.currency', "so'm")}"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatTile(
                        icon: Icons.trending_down,
                        color: AppColors.danger,
                        label: tr(ref, 'mobile.customer.transactions.expense',
                            "Chiqim"),
                        value:
                            "${_fmt(res.totalExpense)} ${tr(ref, 'common.currency', "so'm")}"),
                  ),
                ]),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 22),
            Text(
                tr(ref, 'mobile.customer.transactions.history',
                    "Tranzaktsiyalar"),
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: -0.3)),
            const SizedBox(height: 10),

            // Direction chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TxnChip(
                      label: tr(ref, 'common.all', "Hammasi"),
                      on: _direction == 'all',
                      onTap: () => setState(() {
                            _direction = 'all';
                            _page = 1;
                          })),
                  _TxnChip(
                      label: tr(ref, 'mobile.customer.transactions.income',
                          "Kirim"),
                      on: _direction == 'in',
                      onTap: () => setState(() {
                            _direction = 'in';
                            _page = 1;
                          })),
                  _TxnChip(
                      label: tr(ref, 'mobile.customer.transactions.expense',
                          "Chiqim"),
                      on: _direction == 'out',
                      onTap: () => setState(() {
                            _direction = 'out';
                            _page = 1;
                          })),
                ],
              ),
            ),

            // Filter panel
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
                      DropdownButtonFormField<String>(
                        isDense: true,
                        initialValue: _method,
                        decoration: InputDecoration(
                            labelText: tr(ref, 'lopePay.shop.filterType',
                                "To'lov turi")),
                        items: [
                          DropdownMenuItem(
                              value: 'all',
                              child: Text(_methodLabel('all'))),
                          DropdownMenuItem(
                              value: 'click',
                              child: Text(_methodLabel('click'))),
                          DropdownMenuItem(
                              value: 'payme',
                              child: Text(_methodLabel('payme'))),
                          DropdownMenuItem(
                              value: 'telegram',
                              child: Text(_methodLabel('telegram'))),
                          DropdownMenuItem(
                              value: 'internal',
                              child: Text(_methodLabel('internal'))),
                        ],
                        onChanged: (v) => setState(() {
                          _method = v ?? 'all';
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
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _DatePill(
                                label: _to == null
                                    ? tr(ref, 'shop.filter.to', "Gacha")
                                    : _ymd.format(_to!),
                                onTap: () => _pickDate(false))),
                      ]),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(tr(ref, 'common.reset', "Tozalash")),
                        onPressed: _resetFilters,
                      ),
                    ]),
              ),
            ],

            const SizedBox(height: 12),
            async.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(
                  "${tr(ref, 'common.error', 'Xatolik')}: $e",
                  style: const TextStyle(color: AppColors.textMuted)),
              data: (res) {
                final list = res.data;
                final pages = res.totalPages;
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text(
                            tr(ref,
                                'mobile.customer.transactions.empty',
                                "Hali tranzaktsiya yo'q"),
                            style:
                                const TextStyle(color: AppColors.textMuted))),
                  );
                }
                return Column(children: [
                  ...List.generate(list.length, (i) {
                    final p = list[i];
                    final inflow = p.direction == 'in' || p.amount > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
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
                                  p.description ??
                                      _methodRowLabel(ref, p.method),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(_df.format(p.createdAt.toLocal()),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                            "${inflow ? '+' : '−'}${_fmt(p.amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: inflow
                                    ? AppColors.success
                                    : AppColors.danger)),
                      ]),
                    ).animate().fadeIn(
                        duration: 200.ms, delay: (i * 20).ms);
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

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard({required this.amount, required this.aiFree});
  final int amount;
  final int? aiFree;
  @override
  ConsumerState<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<_BalanceCard> {
  Future<void> _openTopUpSheet() async {
    await TopUpModal.show(context);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              tr(ref, 'mobile.customer.transactions.balanceCurrent',
                  "Joriy balans"),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              "${_fmt(widget.amount)} ${tr(ref, 'common.currency', "so'm")}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          if (widget.aiFree != null) ...[
            const SizedBox(height: 8),
            Text(
                tr(ref, 'mobile.customer.transactions.freeAiHint',
                    "Bugun {{n}} ta bepul AI Stil qoldi",
                    {'n': '${widget.aiFree}'}),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: _openTopUpSheet,
            child: Text(
                tr(ref, 'mobile.customer.transactions.topUp', "To'ldirish"),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TxnChip extends StatelessWidget {
  const _TxnChip(
      {required this.label, required this.on, required this.onTap});
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
            border:
                Border.all(color: on ? AppColors.primary : AppColors.border),
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
