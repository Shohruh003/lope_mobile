import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/tr.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../theme/colors.dart';

/// Notifications icon with an unread-count badge in the top-right corner.
/// Used by all four role shells (customer / barber / barbershop / lopepay)
/// so users get the same red dot affordance the web sidebar shows.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final unread = user == null
        ? 0
        : ref.watch(notificationsProvider(user.role)).maybeWhen(
              data: (list) => list.where((n) => !n.read).length,
              orElse: () => 0,
            );
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: tr(ref, 'barberApp.notifications', 'Bildirishnomalar'),
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.notifications_outlined,
            color: AppColors.textPrimary, size: 22),
        onPressed: () => context.push('/notifications'),
      ),
      if (unread > 0)
        Positioned(
          top: 4,
          right: 4,
          child: IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1),
              ),
            ),
          ),
        ),
    ]);
  }
}
