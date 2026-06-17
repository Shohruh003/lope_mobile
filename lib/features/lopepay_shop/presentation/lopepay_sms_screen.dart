import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

class LopepaySmsScreen extends ConsumerWidget {
  const LopepaySmsScreen({super.key});
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lopepaySmsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("SMS tarixi")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text("SMS yo'q", style: TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(lopepaySmsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = list[i];
                final ok = s['status'] == 'delivered' || s['status'] == 'sent';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text((s['phone'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (ok ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text((s['status'] ?? '').toString(),
                            style: TextStyle(color: ok ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text((s['message'] ?? '').toString(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                    if (s['createdAt'] != null) ...[
                      const SizedBox(height: 6),
                      Text(_df.format(DateTime.parse(s['createdAt'].toString()).toLocal()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ]),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
