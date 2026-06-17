import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

class ShopBookingsScreen extends ConsumerWidget {
  const ShopBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.shop.bookings.title', "Salon bronlari"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'mobile.shop.bookings.empty', "Bron yo'q"),
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(shopBookingsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = list[i];
                final ok = b.status == 'confirmed' || b.status == 'completed';
                final color = b.status == 'cancelled' ? AppColors.danger : (b.status == 'completed' ? AppColors.success : AppColors.primary);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(b.userName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(b.status,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      if (b.barberName.isNotEmpty)
                        Text("Master: ${b.barberName}",
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(b.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 14),
                        const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(b.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const Spacer(),
                        if (b.totalPrice > 0)
                          Text("${_fmt(b.totalPrice)} so'm",
                              style: TextStyle(color: ok ? AppColors.success : AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
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
