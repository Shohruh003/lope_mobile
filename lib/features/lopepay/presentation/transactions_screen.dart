import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';
import 'top_up_modal.dart';

/// Combined balance card + payment history list. Used by both customer and
/// barber roles; only the entry point differs.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  String _filter = 'all'; // 'all' | 'in' | 'out'

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final balance = ref.watch(myBalanceProvider(user.id));
    final history = ref.watch(paymentHistoryProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.customer.transactions.title', "Hisobim"))),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myBalanceProvider(user.id));
          ref.invalidate(paymentHistoryProvider(user.id));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Balance card
            balance.when(
              loading: () => Container(
                height: 130, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
              data: (b) => _BalanceCard(amount: b.amount, aiFree: b.aiFreeRemaining, userId: user.id),
            ),
            const SizedBox(height: 22),
            Text(tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            // Direction filter chips (mirror web MyTransactions)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TxnChip(
                      label: tr(ref, 'common.all', "Hammasi"),
                      on: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                  _TxnChip(
                      label: tr(ref, 'mobile.customer.transactions.income', "Kirim"),
                      on: _filter == 'in',
                      onTap: () => setState(() => _filter = 'in')),
                  _TxnChip(
                      label: tr(ref, 'mobile.customer.transactions.expense', "Chiqim"),
                      on: _filter == 'out',
                      onTap: () => setState(() => _filter = 'out')),
                ],
              ),
            ),
            const SizedBox(height: 10),
            history.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
              data: (raw) {
                final list = raw.where((p) {
                  final inflow = p.direction == 'in' || p.amount > 0;
                  if (_filter == 'in') return inflow;
                  if (_filter == 'out') return !inflow;
                  return true;
                }).toList();
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: Text(
                            raw.isEmpty
                                ? tr(ref, 'mobile.customer.transactions.empty',
                                    "Hali tranzaktsiya yo'q")
                                : tr(ref, 'common.noResults',
                                    "Hech narsa topilmadi"),
                            style: const TextStyle(color: AppColors.textMuted))),
                  );
                }
                return Column(
                  children: List.generate(list.length, (i) {
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
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: (inflow ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(inflow ? Icons.arrow_downward : Icons.arrow_upward,
                                color: inflow ? AppColors.success : AppColors.danger),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.description ?? _methodLabel(ref, p.method),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_df.format(p.createdAt.toLocal()),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text("${inflow ? '+' : '−'}${_fmt(p.amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: inflow ? AppColors.success : AppColors.danger)),
                        ],
                      ),
                    ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
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

class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard({required this.amount, required this.aiFree, required this.userId});
  final int amount;
  final int? aiFree;
  final String userId;
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
          Text(tr(ref, 'mobile.customer.transactions.balanceCurrent', "Joriy balans"),
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("${_fmt(widget.amount)} ${tr(ref, 'common.currency', "so'm")}",
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: _openTopUpSheet,
            child: Text(tr(ref, 'mobile.customer.transactions.topUp', "To'ldirish"),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TxnChip extends StatelessWidget {
  const _TxnChip({required this.label, required this.on, required this.onTap});
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
