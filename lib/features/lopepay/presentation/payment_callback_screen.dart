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
    // Gate the haptic on the actual payment outcome — the old
    // AppHaptics.success() fired even when the callback URL carried
    // status=failed, making a rejected payment feel like it worked.
    if (widget.status == 'success') {
      AppHaptics.success();
    } else {
      AppHaptics.error();
    }
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
                      // Success / danger gradients derived from the
                      // theme tokens so they auto-adjust if the palette
                      // ever swaps (previously hard-coded emerald /
                      // red hex — worked in both modes but decoupled
                      // from the design system).
                      gradient: LinearGradient(
                        colors: ok
                            ? [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.85),
                              ]
                            : [
                                AppColors.danger,
                                AppColors.danger.withValues(alpha: 0.85),
                              ],
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
                      .copyWith(color: context.colors.textSecondary),
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
