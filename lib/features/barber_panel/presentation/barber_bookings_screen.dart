import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

/// Full bookings history for the signed-in barber, newest first.
class BarberBookingsScreen extends ConsumerWidget {
  const BarberBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberAllBookingsProvider(barberId));

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(barberAllBookingsProvider(barberId).future),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text("Barcha bronlar",
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
              ),
              async.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text("Hali bron yo'q",
                              style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _BookingCard(b: list[i])
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                          .slideY(begin: 0.1, end: 0),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b});
  final BarberBooking b;

  Color get _color {
    switch (b.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String get _statusText {
    switch (b.status) {
      case 'completed':
        return 'Yakunlangan';
      case 'cancelled':
        return 'Bekor qilingan';
      default:
        return 'Tasdiqlangan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = b.guestName?.isNotEmpty == true
        ? b.guestName!
        : (b.userName.isNotEmpty ? b.userName : 'Mijoz');
    final phone = b.guestPhone ?? b.userPhone ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_statusText,
                    style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phone, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(b.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(b.time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              if (b.totalPrice > 0)
                Text(
                  "${_fmt(b.totalPrice)} so'm",
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i;
      buf.write(s[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}
