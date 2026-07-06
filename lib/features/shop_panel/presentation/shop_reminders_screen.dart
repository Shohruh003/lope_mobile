import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';

/// Clients who haven't visited the salon for `reminderDays` days or more.
/// Mirrors the web's BarbershopReminders page exactly — taps open the
/// shop-side client detail. Backend:
/// GET /barbershop/clients/due-for-reminder.
class ShopRemindersScreen extends ConsumerStatefulWidget {
  const ShopRemindersScreen({super.key});
  @override
  ConsumerState<ShopRemindersScreen> createState() =>
      _ShopRemindersScreenState();
}

class _ShopRemindersScreenState extends ConsumerState<ShopRemindersScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_dueForReminderProvider(_page));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.shop.reminders.title', "Eslatma kutmoqda")),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(_dueForReminderProvider),
        ),
        data: (data) {
          final clients = data.clients;
          final days = data.reminderDays;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_dueForReminderProvider);
              await ref.read(_dueForReminderProvider(_page).future);
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
                  SizedBox(
                    height: 280,
                    child: AppEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: tr(ref, 'mobile.shop.reminders.empty',
                          "Bu kun uchun eslatma kutayotgan mijozlar yo'q"),
                      message: tr(
                        ref,
                        'mobile.shop.reminders.emptyHint',
                        "Ajoyib! Barcha mijozlar so'nggi paytda tashrif buyurishgan.",
                      ),
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
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name.isEmpty ? c.phone : c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (c.daysSince >= days + 7
                                            ? AppColors.danger
                                            : AppColors.warning)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                      tr(
                                          ref,
                                          'mobile.shop.reminders.daysAgo',
                                          "{{n}} kun oldin",
                                          {'n': '${c.daysSince}'}),
                                      style: TextStyle(
                                          color: c.daysSince >= days + 7
                                              ? AppColors.danger
                                              : AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10)),
                                ),
                                if (c.smsSentRecently) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check,
                                              size: 10,
                                              color: AppColors.success),
                                          const SizedBox(width: 3),
                                          Text(
                                              tr(
                                                  ref,
                                                  'mobile.shop.reminders.smsSent',
                                                  "SMS yuborilgan"),
                                              style: const TextStyle(
                                                  color: AppColors.success,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ]),
                                  ),
                                ],
                                if (c.lastVisit != null) ...[
                                  const SizedBox(height: 3),
                                  Text(_df.format(c.lastVisit!.toLocal()),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                ],
                                if (c.lastBarberName.isNotEmpty)
                                  Text(c.lastBarberName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                              ],
                            ),
                          ]),
                        ),
                      ).animate().fadeIn(duration: 250.ms, delay: (e.key * 25).ms),
                    );
                  }),
                if (data.totalPages > 1) ...[
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
                      Text("$_page / ${data.totalPages}",
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _page >= data.totalPages
                            ? null
                            : () => setState(() => _page++),
                        child: Text(tr(ref, 'common.next', "Keyingi")),
                      ),
                    ],
                  ),
                ],
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
    required this.lastBarberName,
    required this.smsSentRecently,
    this.lastVisit,
  });
  final String key;
  final String name;
  final String phone;
  final String avatar;
  final int daysSince;
  final String lastBarberName;
  final bool smsSentRecently;
  final DateTime? lastVisit;

  factory _ReminderClient.fromJson(Map<String, dynamic> json) {
    final last = json['lastVisit']?.toString();
    return _ReminderClient(
      key: (json['key'] ?? json['phone'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      avatar: (json['avatar'] ?? '').toString(),
      daysSince: ((json['daysSince'] ?? json['daysAgo'] ?? 0) as num).toInt(),
      lastBarberName: (json['lastBarberName'] ?? '').toString(),
      smsSentRecently: json['smsSentRecently'] == true,
      lastVisit: last == null || last.isEmpty ? null : DateTime.tryParse(last),
    );
  }
}

class _RemindersData {
  _RemindersData(
      {required this.reminderDays,
      required this.clients,
      required this.total,
      required this.totalPages});
  final int reminderDays;
  final int total;
  final int totalPages;
  final List<_ReminderClient> clients;
}

final _dueForReminderProvider = FutureProvider.family<_RemindersData, int>(
    (ref, page) async {
  final res = await ref.watch(dioProvider).get(
      '/barbershop/clients/due-for-reminder',
      queryParameters: {'page': page, 'limit': 20});
  final data = res.data;
  final raw = (data is Map && data['data'] is List)
      ? data['data'] as List
      : (data is List ? data : <dynamic>[]);
  final reminderDays = (data is Map && data['reminderDays'] != null)
      ? (data['reminderDays'] as num).toInt()
      : 20;
  final meta = data is Map && data['meta'] is Map
      ? (data['meta'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  return _RemindersData(
    reminderDays: reminderDays,
    total: ((meta['total'] ?? raw.length) as num).toInt(),
    totalPages: ((meta['totalPages'] ?? 1) as num).toInt(),
    clients: raw
        .cast<Map<String, dynamic>>()
        .map(_ReminderClient.fromJson)
        .toList(),
  );
});
