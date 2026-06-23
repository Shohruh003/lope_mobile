import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

class LopepayTransactionsScreen extends ConsumerWidget {
  const LopepayTransactionsScreen({super.key});
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lopepayTxnProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'mobile.customer.transactions.empty', "Tranzaktsiya yo'q"),
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(lopepayTxnProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = list[i];
                final amount = ((t['amount'] ?? 0) as num).toInt();
                final inflow = amount > 0;
                return Container(
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
                          Text((t['description'] ?? tr(ref, 'mobile.customer.transactions.methodDefault', 'Tranzaktsiya')).toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          if (t['createdAt'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _df.format(DateTime.parse(t['createdAt'].toString()).toLocal()),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text("${inflow ? '+' : '−'}${_fmt(amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                        style: TextStyle(fontWeight: FontWeight.w800, color: inflow ? AppColors.success : AppColors.danger)),
                  ]),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
              },
            ),
          );
        },
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
}
