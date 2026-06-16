import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sms_history_repository.dart';

class BarberSmsHistoryScreen extends ConsumerWidget {
  const BarberSmsHistoryScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(smsHistoryProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.sms.title', "SMS tarixi"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(smsHistoryProvider(user.id).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = list[i];
                final ok = s.status == 'delivered' || s.status == 'sent' || s.status == 'success';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(s.phone,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (ok ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(s.status,
                                style: TextStyle(color: ok ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.message,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                      const SizedBox(height: 8),
                      Text(_df.format(s.createdAt.toLocal()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
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
}
