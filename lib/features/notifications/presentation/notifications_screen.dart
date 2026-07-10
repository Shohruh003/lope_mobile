import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Notifications screen — date-grouped, type-aware. Uzum/Click darajasi:
///   - Date headers sifatida overline label
///   - Kartochka: chap tomonda rangli accent bar + icon dahili
///     (new_booking/booking_cancelled/manual_booking/reminder)
///   - Read/unread — unread'da subtle tint background + read dot indicator
///   - Mark-all-read tugmasi appbarda (faqat unread > 0 bo'lsa)
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(notificationsProvider(user.role));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.notifications.title', 'Bildirishnomalar'),
          style: AppText.titleMd,
        ),
        actions: [
          async.maybeWhen(
            data: (list) {
              final unread = list.where((n) => !n.read).length;
              if (unread == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: TapScale(
                  onTap: () async {
                    AppHaptics.light();
                    try {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .markAllRead(role: user.role, userId: user.id);
                      ref.invalidate(notificationsProvider(user.role));
                    } catch (_) {}
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.done_all,
                            color: AppColors.primary, size: 16),
                        AppSpacing.hGapXs,
                        Text(
                          '$unread',
                          style: AppText.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const AppListSkeleton(itemCount: 6),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(notificationsProvider(user.role)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.notifications_off_rounded,
              title: tr(ref, 'mobile.notifications.empty',
                  "Bildirishnomalar yo'q"),
              message: tr(ref, 'barberApp.noNotificationsHint',
                  "Yangi bron yoki eslatma kelsa shu yerda ko'rasiz"),
            );
          }

          final locale =
              ref.watch(localeProvider).asData?.value.locale ?? 'uz';
          final groups = _groupByDate(list, ref, locale);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.refresh(notificationsProvider(user.role).future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: groups.length,
              itemBuilder: (context, gi) {
                final group = groups[gi];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppSpacing.xs,
                          bottom: AppSpacing.sm,
                        ),
                        child: Text(
                          group.label.toUpperCase(),
                          style: AppText.overline,
                        ),
                      ),
                      ...List.generate(group.items.length, (i) {
                        final n = group.items[i];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _NotifTile(
                            n: n,
                            onTap: () async {
                              if (n.read) return;
                              AppHaptics.light();
                              try {
                                await ref
                                    .read(notificationsRepositoryProvider)
                                    .markRead(n.id, role: user.role);
                                ref.invalidate(
                                    notificationsProvider(user.role));
                              } catch (_) {}
                            },
                          ),
                        ).animate().fadeIn(
                            duration: 200.ms,
                            delay: (i * 25).ms,
                            curve: AppMotion.emphasized);
                      }),
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

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<AppNotification> items;
}

List<_Group> _groupByDate(
    List<AppNotification> list, WidgetRef ref, String locale) {
  final today = DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  final y0 = t0.subtract(const Duration(days: 1));

  const monthsByLocale = <String, List<String>>{
    'uz': [
      'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
      'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr'
    ],
    'uz_cyr': [
      'январ', 'феврал', 'март', 'апрел', 'май', 'июн',
      'июл', 'август', 'сентябр', 'октябр', 'ноябр', 'декабр'
    ],
    'ru': [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ],
    'en': [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ],
  };
  final months = monthsByLocale[locale] ?? monthsByLocale['uz']!;
  final todayLabel = tr(ref, 'barberApp.today', 'Bugun');
  final yesterdayLabel = tr(ref, 'barberApp.yesterday', 'Kecha');

  final byLabel = <String, List<AppNotification>>{};
  final order = <String>[];

  for (final n in list) {
    final d = n.createdAt.toLocal();
    final d0 = DateTime(d.year, d.month, d.day);
    final String label;
    if (d0 == t0) {
      label = todayLabel;
    } else if (d0 == y0) {
      label = yesterdayLabel;
    } else if (locale == 'en') {
      label = '${months[d.month - 1]} ${d.day}';
    } else {
      label = '${d.day} ${months[d.month - 1]}';
    }
    final bucket = byLabel.putIfAbsent(label, () {
      order.add(label);
      return <AppNotification>[];
    });
    bucket.add(n);
  }

  return order.map((k) => _Group(k, byLabel[k]!)).toList();
}

class _TypeStyle {
  const _TypeStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

const _typeStyles = <String, _TypeStyle>{
  'new_booking':
      _TypeStyle(Icons.event_available, Color(0xFF3B82F6)), // blue
  'booking_cancelled':
      _TypeStyle(Icons.event_busy, Color(0xFFEF4444)), // red
  'manual_booking':
      _TypeStyle(Icons.phone_in_talk, Color(0xFF10B981)), // green
  'reminder': _TypeStyle(Icons.access_time, Color(0xFFF59E0B)), // orange
};

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _typeStyles[n.type ?? ''] ?? _typeStyles['new_booking']!;
    return TapScale(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: n.read
              ? AppColors.surface
              : style.color.withValues(alpha: 0.08),
          borderRadius: AppRadius.rLg,
          border: Border.all(
            color: n.read
                ? AppColors.border
                : style.color.withValues(alpha: 0.35),
          ),
          boxShadow: n.read ? null : AppShadows.subtle,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                borderRadius: AppRadius.rMd,
              ),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppText.body.copyWith(
                            fontWeight:
                                n.read ? FontWeight.w500 : FontWeight.w700,
                            color: n.read
                                ? AppColors.textSecondary
                                : AppColors.textBright,
                            height: 1.3,
                          ),
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Text(
                        _hhmm(n.createdAt),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!n.read) ...[
              AppSpacing.hGapSm,
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: style.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _hhmm(DateTime t) {
    final lt = t.toLocal();
    final hh = lt.hour.toString().padLeft(2, '0');
    final mm = lt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
