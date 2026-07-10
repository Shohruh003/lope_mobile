import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

class PaymentCallbackScreen extends ConsumerStatefulWidget {
  const PaymentCallbackScreen({super.key, required this.status});
  final String status;

  @override
  ConsumerState<PaymentCallbackScreen> createState() =>
      _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState
    extends ConsumerState<PaymentCallbackScreen> {
  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    if (user != null) ref.invalidate(myBalanceProvider(user.id));
    // ignore: unawaited_futures
    ref.read(authControllerProvider.notifier).refreshFromServer();
    AppHaptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final ok = widget.status == 'success';
    final color = ok ? AppColors.success : AppColors.danger;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ok
                            ? const [Color(0xFF10B981), Color(0xFF059669)]
                            : const [Color(0xFFEF4444), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      ok ? Icons.check : Icons.close,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      duration: 500.ms,
                      begin: const Offset(0.4, 0.4),
                      curve: Curves.easeOutBack,
                    )
                    .then()
                    .shake(
                      hz: 2,
                      curve: Curves.easeInOut,
                      duration: 300.ms,
                    ),
                AppSpacing.gapXl,
                Text(
                  ok
                      ? tr(ref, 'mobile.payment.successTitle',
                          "To'lov muvaffaqiyatli")
                      : tr(ref, 'mobile.payment.failTitle',
                          "To'lov bekor qilindi"),
                  style: AppText.titleLg,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapSm,
                Text(
                  ok
                      ? tr(ref, 'mobile.payment.successMsg',
                          'Hisobingiz tezda yangilanadi')
                      : tr(ref, 'mobile.payment.failMsg',
                          "Hech narsa yechilmadi. Qaytadan urinib ko'ring"),
                  style: AppText.bodyLg
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapXl,
                AppButton(
                  label: tr(ref, 'mobile.payment.openWallet',
                      'Hisobni ochish'),
                  leadingIcon: Icons.account_balance_wallet,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => context.go('/transactions'),
                ),
                AppSpacing.gapSm,
                AppButton(
                  label:
                      tr(ref, 'mobile.payment.home', 'Bosh sahifa'),
                  variant: AppButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
