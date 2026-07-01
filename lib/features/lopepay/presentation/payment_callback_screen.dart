import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

/// Landing screen the payment gateway redirects to after the user completes
/// (or cancels) a top-up. We re-fetch the balance immediately and show a
/// status badge.
class PaymentCallbackScreen extends ConsumerStatefulWidget {
  const PaymentCallbackScreen({super.key, required this.status});
  final String status; // 'success' | 'failure' | anything else → unknown

  @override
  ConsumerState<PaymentCallbackScreen> createState() => _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState extends ConsumerState<PaymentCallbackScreen> {
  @override
  void initState() {
    super.initState();
    // Kick a balance + user refresh — server credited funds + may have
    // toggled VIP / promoted the role. Both providers updated so the
    // wallet card shows the new amount before the user even taps
    // 'Hisobni ochish'.
    final user = ref.read(authControllerProvider).user;
    if (user != null) ref.invalidate(myBalanceProvider(user.id));
    // ignore: unawaited_futures
    ref.read(authControllerProvider.notifier).refreshFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.status == 'success';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: (ok ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(ok ? Icons.check : Icons.close,
                      size: 56, color: ok ? AppColors.success : AppColors.danger),
                ).animate().scale(duration: 500.ms, begin: const Offset(0.4, 0.4), end: const Offset(1, 1), curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                    ok
                        ? tr(ref, 'mobile.payment.successTitle', "To'lov muvaffaqiyatli")
                        : tr(ref, 'mobile.payment.failTitle', "To'lov bekor qilindi"),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textBright, letterSpacing: -0.3),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  ok
                      ? tr(ref, 'mobile.payment.successMsg', "Hisobingiz tezda yangilanadi")
                      : tr(ref, 'mobile.payment.failMsg',
                          "Hech narsa yechilmadi. Qaytadan urinib ko'ring"),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/transactions'),
                    child: Text(tr(ref, 'mobile.payment.openWallet', "Hisobni ochish")),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.go('/home'),
                  child: Text(tr(ref, 'mobile.payment.home', "Bosh sahifa")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
