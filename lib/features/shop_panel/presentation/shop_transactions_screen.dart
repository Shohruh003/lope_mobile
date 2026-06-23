import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

/// Shop owner's transaction history. Mirrors BarbershopTransactions:
/// balance card on top, then filter chips (All / Topup / SMS / AI /
/// Bonus / Income only / Expense only) over a chronological list.
class ShopTransactionsScreen extends ConsumerStatefulWidget {
  const ShopTransactionsScreen({super.key});

  @override
  ConsumerState<ShopTransactionsScreen> createState() =>
      _ShopTransactionsScreenState();
}

class _ShopTransactionsScreenState
    extends ConsumerState<ShopTransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  String _filter = 'all'; // 'all' | 'topup' | 'sms' | 'ai' | 'bonus' | 'in' | 'out'

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
      case 'click': return tr(ref, 'mobile.customer.transactions.methodClick', "Click to'lov");
      case 'payme': return tr(ref, 'mobile.customer.transactions.methodPayme', "Payme to'lov");
      case 'telegram': return tr(ref, 'mobile.customer.transactions.methodTelegram', 'Telegram bonus');
      case 'sms': return tr(ref, 'mobile.customer.transactions.methodSms', 'SMS xizmat');
      case 'ai': return tr(ref, 'mobile.customer.transactions.methodAi', 'AI Stil');
      case 'referral': return tr(ref, 'mobile.customer.transactions.methodReferral', 'Referal bonus');
      default: return tr(ref, 'mobile.customer.transactions.methodDefault', 'Tranzaktsiya');
    }
  }

  bool _matchesFilter(ShopTxnEntry t) {
    final inflow = t.direction == 'in' || t.amount > 0;
    switch (_filter) {
      case 'all':
        return true;
      case 'in':
        return inflow;
      case 'out':
        return !inflow;
      case 'topup':
        return t.method == 'click' ||
            t.method == 'payme' ||
            t.method == 'telegram';
      case 'sms':
        return t.method == 'sms';
      case 'ai':
        return t.method == 'ai';
      case 'bonus':
        return t.method == 'referral' || t.method == 'telegram';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopTransactionsProvider);
    final balanceAsync = ref.watch(shopBalanceProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(
              ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"))),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(shopTransactionsProvider);
          ref.invalidate(shopBalanceProvider);
          await ref.read(shopTransactionsProvider.future);
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
                  width: 44, height: 44,
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
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        error: (_, _) => const Text("—",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        data: (b) => Text(
                            "${_fmt(b)} ${tr(ref, 'common.currency', "so'm")}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
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
                  _Chip(label: tr(ref, 'common.all', "Hammasi"),
                      on: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                  _Chip(label: "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} +",
                      on: _filter == 'in',
                      onTap: () => setState(() => _filter = 'in')),
                  _Chip(label: "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} −",
                      on: _filter == 'out',
                      onTap: () => setState(() => _filter = 'out')),
                  _Chip(label: tr(ref, 'mobile.customer.transactions.topUp', "To'ldirish"),
                      on: _filter == 'topup',
                      onTap: () => setState(() => _filter = 'topup')),
                  _Chip(label: 'SMS',
                      on: _filter == 'sms',
                      onTap: () => setState(() => _filter = 'sms')),
                  _Chip(label: 'AI',
                      on: _filter == 'ai',
                      onTap: () => setState(() => _filter = 'ai')),
                  _Chip(label: tr(ref, 'mobile.customer.transactions.methodReferral', "Bonus"),
                      on: _filter == 'bonus',
                      onTap: () => setState(() => _filter = 'bonus')),
                ],
              ),
            ),
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
              data: (raw) {
                final list = raw.where(_matchesFilter).toList();
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                          raw.isEmpty
                              ? tr(ref, 'mobile.customer.transactions.empty',
                                  "Tranzaktsiya yo'q")
                              : tr(ref, 'common.noResults',
                                  "Hech narsa topilmadi"),
                          style: const TextStyle(color: AppColors.textMuted)),
                    ),
                  );
                }
                return Column(
                  children: list.asMap().entries.map((e) {
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
                            width: 38, height: 38,
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
                                    : AppColors.danger),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    t.description ?? _methodLabel(ref, t.method),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_df.format(t.createdAt.toLocal()),
                                    style: const TextStyle(
                                        color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(
                              "${inflow ? '+' : '−'}${_fmt(t.amount)} ${tr(ref, 'common.currency', "so'm")}",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: inflow
                                      ? AppColors.success
                                      : AppColors.danger)),
                        ]),
                      ).animate().fadeIn(duration: 250.ms, delay: (e.key * 25).ms),
                    );
                  }).toList(),
                );
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? AppColors.primary : AppColors.border),
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
