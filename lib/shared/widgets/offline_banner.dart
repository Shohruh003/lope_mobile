import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity_service.dart';
import '../../core/tr.dart';
import '../shared.dart';

/// Persistent top banner that slides in whenever the device drops off
/// the network and slides back out as soon as connectivity returns.
///
/// Rendered once at the root of [MaterialApp.builder] so every screen
/// gets the same visual signal — barbers, shop admins and customers
/// all see the same amber strip. Doesn't intercept taps under it,
/// just adds `banner height` of top padding to the widget below.
class OfflineBannerWrapper extends ConsumerWidget {
  const OfflineBannerWrapper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).maybeWhen(
          data: (v) => v,
          orElse: () => true,
        );
    return Stack(children: [
      child,
      if (!online)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _OfflineStrip(),
        ),
    ]);
  }
}

class _OfflineStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Material(
      color: Colors.transparent,
      child: Container(
        color: AppColors.warning,
        padding: EdgeInsets.only(
          top: topInset + 4,
          bottom: 6,
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(ref, 'mobile.offline.banner',
                  "Internet yo'q — ma'lumotlar so'nggi kunlaringizdan ko'rsatilyapti"),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }
}
