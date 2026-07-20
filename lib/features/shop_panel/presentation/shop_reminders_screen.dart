import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';

class ShopRemindersScreen extends ConsumerStatefulWidget {
  const ShopRemindersScreen({super.key});
  @override
  ConsumerState<ShopRemindersScreen> createState() =>
      _ShopRemindersScreenState();
}

class _ShopRemindersScreenState extends ConsumerState<ShopRemindersScreen> {
  static final _df = DateFormat('dd.MM.yyyy');
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_dueForReminderProvider(_page));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.shop.reminders.title', "Eslatma kutmoqda"),
            style: AppText.titleMd),
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
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppCard(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.18),
                      AppColors.warning.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: AppColors.warning.withValues(alpha: 0.35),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.2),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        tr(ref, 'mobile.shop.reminders.hint',
                            "Oxirgi tashrifidan {{n}} kun yoki undan ko'p o'tgan mijozlar.",
                            {'n': '$days'}),
                        style: AppText.bodySm,
                      ),
                    ),
                    TapScale(
                      onTap: () => context.push('/shop/settings'),
                      haptic: HapticStrength.light,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: Text(
                            tr(ref, 'mobile.shop.reminders.changeBtn',
                                "O'zgartirish"),
                            style: AppText.button
                                .copyWith(color: AppColors.primary, fontSize: 12)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),

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
                    final overdue = c.daysSince >= days + 7;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () => context.push(
                            '/shop/clients/${Uri.encodeComponent(c.key)}'),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: overdue
                                    ? [
                                        AppColors.danger
                                            .withValues(alpha: 0.6),
                                        AppColors.danger
                                            .withValues(alpha: 0.2),
                                      ]
                                    : [
                                        AppColors.warning
                                            .withValues(alpha: 0.6),
                                        AppColors.warning
                                            .withValues(alpha: 0.2),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: c.avatar.isNotEmpty
                                  ? CachedNetworkImage(
                                      // Backend returns a relative
                                      // asset path — every other
                                      // screen wraps with assetUrl so
                                      // the request resolves against
                                      // the API base URL. Without it
                                      // the image always 404'd.
                                      imageUrl: assetUrl(c.avatar),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover)
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: context.colors.surface,
                                      alignment: Alignment.center,
                                      child: Text(
                                          (c.name.isNotEmpty
                                                  ? c.name[0]
                                                  : '?')
                                              .toUpperCase(),
                                          style: AppText.titleSm.copyWith(
                                              color: AppColors.primary)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name.isEmpty ? c.phone : c.name,
                                    style: AppText.titleSm
                                        .copyWith(fontSize: 14)),
                                if (c.phone.isNotEmpty)
                                  Text(c.phone, style: AppText.caption),
                                if (c.lastVisit != null)
                                  Text(
                                      "${tr(ref, 'barberMyClients.lastVisit', 'Oxirgi tashrif')}: ${_df.format(c.lastVisit!.toLocal())}",
                                      style: AppText.caption
                                          .copyWith(fontSize: 11)),
                                if (c.lastBarberName.isNotEmpty)
                                  Text(c.lastBarberName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption
                                          .copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppBadge(
                                label: tr(
                                    ref,
                                    'mobile.shop.reminders.daysAgo',
                                    "{{n}} kun oldin",
                                    {'n': '${c.daysSince}'}),
                                variant: overdue
                                    ? AppBadgeVariant.danger
                                    : AppBadgeVariant.warning,
                              ),
                              if (c.smsSentRecently) ...[
                                const SizedBox(height: 4),
                                AppBadge(
                                  label: tr(
                                      ref,
                                      'mobile.shop.reminders.smsSent',
                                      "SMS yuborilgan"),
                                  variant: AppBadgeVariant.success,
                                  icon: Icons.check,
                                ),
                              ],
                            ],
                          ),
                        ]),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 250.ms, delay: (e.key * 25).ms);
                  }),
                if (data.totalPages > 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppButton(
                        label: tr(ref, 'common.prev', "Oldingi"),
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        leadingIcon: Icons.chevron_left,
                        onPressed: _page <= 1
                            ? null
                            : () => setState(() => _page--),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Text("$_page / ${data.totalPages}",
                            style: AppText.button
                                .copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: tr(ref, 'common.next', "Keyingi"),
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        trailingIcon: Icons.chevron_right,
                        onPressed: _page >= data.totalPages
                            ? null
                            : () => setState(() => _page++),
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
