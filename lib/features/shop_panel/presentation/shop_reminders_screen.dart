import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Clients who haven't visited the salon for `reminderDays` days or more.
/// Mirrors the web's BarbershopReminders page exactly — taps open the
/// shop-side client detail. Backend:
/// GET /barbershop/clients/due-for-reminder.
class ShopRemindersScreen extends ConsumerWidget {
  const ShopRemindersScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_dueForReminderProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.shop.reminders.title', "Eslatma kutmoqda")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (data) {
          final clients = data.clients;
          final days = data.reminderDays;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_dueForReminderProvider);
              await ref.read(_dueForReminderProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // ===== Hint banner with days param =====
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.30)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.notifications_active,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr(ref, 'mobile.shop.reminders.hint',
                            "Oxirgi tashrifidan {{n}} kun yoki undan ko'p o'tgan mijozlar.",
                            {'n': '$days'}),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/shop/settings'),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6)),
                      child: Text(
                          tr(ref, 'mobile.shop.reminders.changeBtn',
                              "O'zgartirish"),
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                if (clients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                          tr(ref, 'mobile.shop.reminders.empty',
                              "Bu kun uchun eslatma kutayotgan mijozlar yo'q"),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...clients.asMap().entries.map((e) {
                    final c = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => context.push(
                            '/shop/clients/${Uri.encodeComponent(c.key)}'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            ClipOval(
                              child: c.avatar.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: c.avatar,
                                      width: 40, height: 40, fit: BoxFit.cover)
                                  : Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                          (c.name.isNotEmpty ? c.name[0] : '?')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w800)),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name.isEmpty ? c.phone : c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            if (c.lastVisit != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      tr(
                                          ref,
                                          'mobile.shop.reminders.daysAgo',
                                          "{{n}} kun oldin",
                                          {'n': '${c.daysSince}'}),
                                      style: const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(_df.format(c.lastVisit!.toLocal()),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 10)),
                                ],
                              ),
                          ]),
                        ),
                      ).animate().fadeIn(duration: 250.ms, delay: (e.key * 25).ms),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReminderClient {
  _ReminderClient({
    required this.key,
    required this.name,
    required this.phone,
    required this.avatar,
    required this.daysSince,
    this.lastVisit,
  });
  final String key;
  final String name;
  final String phone;
  final String avatar;
  final int daysSince;
  final DateTime? lastVisit;

  factory _ReminderClient.fromJson(Map<String, dynamic> json) {
    final last = json['lastVisit']?.toString();
    return _ReminderClient(
      key: (json['key'] ?? json['phone'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
      daysSince: ((json['daysSince'] ?? json['daysAgo'] ?? 0) as num).toInt(),
      lastVisit: last == null || last.isEmpty ? null : DateTime.tryParse(last),
    );
  }
}

class _RemindersData {
  _RemindersData({required this.reminderDays, required this.clients});
  final int reminderDays;
  final List<_ReminderClient> clients;
}

final _dueForReminderProvider =
    FutureProvider<_RemindersData>((ref) async {
  final res = await ref.watch(dioProvider).get(
      '/barbershop/clients/due-for-reminder',
      queryParameters: {'page': 1, 'limit': 50});
  final data = res.data;
  final raw = (data is Map && data['data'] is List)
      ? data['data'] as List
      : (data is List ? data : <dynamic>[]);
  final reminderDays = (data is Map && data['reminderDays'] != null)
      ? (data['reminderDays'] as num).toInt()
      : 20;
  return _RemindersData(
    reminderDays: reminderDays,
    clients: raw
        .cast<Map<String, dynamic>>()
        .map(_ReminderClient.fromJson)
        .toList(),
  );
});
