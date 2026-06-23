import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Pending SMS reminders queue. Read-only list of who's scheduled to receive
/// what at what time. Backend: GET /barbershop/reminders.
class ShopRemindersScreen extends ConsumerWidget {
  const ShopRemindersScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_remindersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'barberApp.reminderSettings', "Eslatmalar"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'mobile.shop.reminders.empty', "Navbatdagi eslatma yo'q"),
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_remindersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                final scheduled = DateTime.tryParse(r['scheduledAt']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final pending = r['status'] == 'pending';
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
                        Expanded(child: Text((r['phone'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (pending ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              pending
                                  ? tr(ref, 'mobile.shop.reminders.statusPending', 'pending')
                                  : tr(ref, 'mobile.shop.reminders.statusSent', 'sent'),
                              style: TextStyle(
                                  color: pending ? AppColors.warning : AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text((r['message'] ?? '').toString(),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                      const SizedBox(height: 6),
                      Text(_df.format(scheduled.toLocal()),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

final _remindersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/barbershop/reminders');
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
  return list.cast<Map<String, dynamic>>();
});
