import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notifications_repository.dart';

/// Mirrors web `BarberNotificationsScreen` / `CustomerNotificationsScreen`:
///   - Date grouping (Bugun / Kecha / explicit DD-month) sticky-headered
///   - Type-aware colour + icon: new_booking / booking_cancelled /
///     manual_booking / reminder
///   - Pull-to-refresh and explicit Mark-all-read with a stamped unread count
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(notificationsProvider(user.role));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.notifications.title', "Bildirishnomalar")),
        actions: [
          async.maybeWhen(
            data: (list) {
              final unread = list.where((n) => !n.read).length;
              if (unread == 0) return const SizedBox.shrink();
              return Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.done_all, color: AppColors.primary),
                  tooltip: tr(ref, 'mobile.notifications.markAllRead', "Hammasini o'qish"),
                  onPressed: () async {
                    try {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .markAllRead(role: user.role, userId: user.id);
                      ref.invalidate(notificationsProvider(user.role));
                    } catch (_) {}
                  },
                ),
              ]);
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}", style: const TextStyle(color: AppColors.textMuted)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_off_outlined,
                          size: 40, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      tr(ref, 'mobile.notifications.empty', "Bildirishnomalar yo'q"),
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(ref, 'barberApp.noNotificationsHint',
                          "Yangi bron yoki eslatma kelsa shu yerda ko'rasiz"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          // ----- Group by date label -----
          final locale = ref.watch(localeProvider).asData?.value.locale ?? 'uz';
          final groups = _groupByDate(list, ref, locale);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(notificationsProvider(user.role).future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: groups.length,
              itemBuilder: (context, gi) {
                final group = groups[gi];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          group.label.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      ...List.generate(group.items.length, (i) {
                        final n = group.items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NotifTile(
                            n: n,
                            onTap: () async {
                              if (n.read) return;
                              try {
                                await ref
                                    .read(notificationsRepositoryProvider)
                                    .markRead(n.id, role: user.role);
                                ref.invalidate(notificationsProvider(user.role));
                              } catch (_) {}
                            },
                          ),
                        ).animate().fadeIn(duration: 200.ms, delay: (i * 25).ms);
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

  // Locale-aware month names so the "DD month" header reads naturally in
  // every supported language. Falls back to Uzbek if locale is unknown.
  const monthsByLocale = <String, List<String>>{
    'uz': [
      "yanvar","fevral","mart","aprel","may","iyun",
      "iyul","avgust","sentabr","oktabr","noyabr","dekabr"
    ],
    'uz_cyr': [
      "январ","феврал","март","апрел","май","июн",
      "июл","август","сентябр","октябр","ноябр","декабр"
    ],
    'ru': [
      "января","февраля","марта","апреля","мая","июня",
      "июля","августа","сентября","октября","ноября","декабря"
    ],
    'en': [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
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
  'new_booking':        _TypeStyle(Icons.event_available,  Color(0xFF3B82F6)), // blue
  'booking_cancelled':  _TypeStyle(Icons.event_busy,       Color(0xFFEF4444)), // red
  'manual_booking':     _TypeStyle(Icons.phone_in_talk,    Color(0xFF10B981)), // green
  'reminder':           _TypeStyle(Icons.access_time,      Color(0xFFF59E0B)), // orange
};

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _typeStyles[n.type ?? ''] ?? _typeStyles['new_booking']!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.read
              ? AppColors.background
              : style.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: style.color, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.icon, color: style.color, size: 18),
            ),
            const SizedBox(width: 12),
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
                          style: TextStyle(
                            fontWeight: n.read ? FontWeight.w500 : FontWeight.w600,
                            fontSize: 14,
                            color: n.read ? AppColors.textSecondary : AppColors.textBright,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hhmm(n.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
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
