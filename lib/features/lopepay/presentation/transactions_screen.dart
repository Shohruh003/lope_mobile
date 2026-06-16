import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

/// Combined balance card + payment history list. Used by both customer and
/// barber roles; only the entry point differs.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final balance = ref.watch(myBalanceProvider(user.id));
    final history = ref.watch(paymentHistoryProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text("Hisobim")),
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
              error: (e, _) => Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
              data: (b) => _BalanceCard(amount: b.amount, aiFree: b.aiFreeRemaining, userId: user.id),
            ),
            const SizedBox(height: 22),
            const Text("Tranzaktsiyalar",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3)),
            const SizedBox(height: 10),
            history.when(
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text("Hali tranzaktsiya yo'q", style: TextStyle(color: AppColors.textMuted))),
                  );
                }
                return Column(
                  children: List.generate(list.length, (i) {
                    final p = list[i];
                    final inflow = p.direction == 'in' || p.amount > 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
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
                                Text(p.description ?? _methodLabel(p.method),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_df.format(p.createdAt.toLocal()),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text("${inflow ? '+' : '−'}${_fmt(p.amount.abs())} so'm",
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

  String _methodLabel(String m) {
    switch (m) {
      case 'click': return 'Click to\'lov';
      case 'payme': return 'Payme to\'lov';
      case 'telegram': return 'Telegram bonus';
      case 'sms': return 'SMS xizmat';
      case 'ai': return 'AI Stil';
      case 'referral': return 'Referal bonus';
      default: return 'Tranzaktsiya';
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
    final amountCtrl = TextEditingController(text: '50000');
    String gateway = 'click';
    bool busy = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Balansni to'ldirish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "Summa (so'm)"),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Click"),
                      selected: gateway == 'click',
                      onSelected: (_) => setSheet(() => gateway = 'click'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Payme"),
                      selected: gateway == 'payme',
                      onSelected: (_) => setSheet(() => gateway = 'payme'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: busy ? null : () async {
                    final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amt < 1000) return;
                    setSheet(() => busy = true);
                    try {
                      final url = await ref.read(balanceRepositoryProvider)
                          .initiateTopUp(userId: widget.userId, amount: amt, gateway: gateway);
                      if (url.isNotEmpty) {
                        final uri = Uri.tryParse(url);
                        if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      }
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                    } catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(content: Text("Xato: $e")));
                      }
                    } finally {
                      setSheet(() => busy = false);
                    }
                  },
                  child: busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("To'lovga o'tish"),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Joriy balans",
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text("${_fmt(widget.amount)} so'm",
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          if (widget.aiFree != null) ...[
            const SizedBox(height: 8),
            Text("Bugun ${widget.aiFree} ta bepul AI Stil qoldi",
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
            child: const Text("To'ldirish", style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
