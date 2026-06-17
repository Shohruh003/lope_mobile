import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(notificationsProvider(user.role));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.notifications.title', "Bildirishnomalar")),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsRepositoryProvider).markAllRead();
                ref.invalidate(notificationsProvider(user.role));
              } catch (_) {}
            },
            child: Text(tr(ref, 'mobile.notifications.markAllRead', "Hammasini o'qish")),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(tr(ref, 'mobile.notifications.empty', "Bildirishnomalar yo'q"),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(notificationsProvider(user.role).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: n.read
                      ? null
                      : () async {
                          try {
                            await ref.read(notificationsRepositoryProvider).markRead(n.id);
                            ref.invalidate(notificationsProvider(user.role));
                          } catch (_) {}
                        },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.read ? AppColors.background : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: n.read ? AppColors.border : AppColors.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          if (!n.read) ...[
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(n.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textBright)),
                          ),
                          Text(_df.format(n.createdAt.toLocal()),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ]),
                        if (n.body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(n.body,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
                        ],
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
