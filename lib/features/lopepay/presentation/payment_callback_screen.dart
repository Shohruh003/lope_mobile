import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

/// Screen shown after the user returns from Click/Payme with a status
/// query param. Click/Payme's server-side callback and our balance
/// webhook are asynchronous — the user is usually back in the app
/// BEFORE the backend has credited the balance, so a naive
/// `ref.invalidate(myBalanceProvider)` on init would show the stale
/// pre-payment amount.
///
/// This screen instead polls the balance every ~2s (up to 20s) and
/// only settles when either (a) the balance goes up from the snapshot
/// taken at mount time (webhook fired) or (b) the timeout elapses. In
/// the timeout case we surface an "yangilanish kechiktirilyapti"
/// message that tells the user their money is safe and to refresh
/// later — much better than the previous silent success.
class PaymentCallbackScreen extends ConsumerStatefulWidget {
  const PaymentCallbackScreen({super.key, required this.status});
  final String status;

  @override
  ConsumerState<PaymentCallbackScreen> createState() =>
      _PaymentCallbackScreenState();
}

class _PaymentCallbackScreenState
    extends ConsumerState<PaymentCallbackScreen> {
  static const _pollIntervalMs = 2000;
  static const _pollTimeoutMs = 20000;
  static final _fmt = NumberFormat.decimalPattern();

  Timer? _poll;
  int? _initialBalance;
  int? _currentBalance;
  bool _webhookReceived = false;
  bool _timedOut = false;
  int _elapsedMs = 0;

  bool get _isSuccess => widget.status == 'success';

  @override
  void initState() {
    super.initState();
    if (_isSuccess) {
      AppHaptics.success();
      _startPolling();
    } else {
      AppHaptics.error();
    }
    // ignore: unawaited_futures
    ref.read(authControllerProvider.notifier).refreshFromServer();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startPolling() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    // Capture the pre-webhook balance so we can detect when the
    // amount actually changes (webhook credited it).
    try {
      final initial = await ref
          .read(balanceRepositoryProvider)
          .myBalance(user.id);
      if (!mounted) return;
      setState(() {
        _initialBalance = initial.amount;
        _currentBalance = initial.amount;
      });
    } catch (_) {
      // If the initial fetch fails, we still poll — the user's
      // network may recover mid-flow.
    }
    _poll = Timer.periodic(
        const Duration(milliseconds: _pollIntervalMs), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      _elapsedMs += _pollIntervalMs;
      try {
        final fresh = await ref
            .read(balanceRepositoryProvider)
            .myBalance(user.id);
        if (!mounted) return;
        setState(() {
          _currentBalance = fresh.amount;
          if (_initialBalance != null &&
              fresh.amount > _initialBalance!) {
            _webhookReceived = true;
          }
        });
        if (_webhookReceived) {
          t.cancel();
          // Also invalidate the FutureProvider so any screen the user
          // navigates to next reads the new amount from cache instead
          // of firing a fresh fetch.
          ref.invalidate(myBalanceProvider(user.id));
        }
      } catch (_) {
        // Swallow single failed polls — the timer will retry.
      }
      if (_elapsedMs >= _pollTimeoutMs && !_webhookReceived) {
        t.cancel();
        if (mounted) setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ok = _isSuccess;
    // While we're still waiting for the webhook, keep the header
    // amber-warning (money is safe but not yet credited). Once the
    // webhook fires we flip green; if it times out we flip amber and
    // show the "yangilanish kechiktirilyapti" copy.
    final settled = _webhookReceived || !ok || _timedOut;
    final color = !ok
        ? AppColors.danger
        : (_webhookReceived
            ? AppColors.success
            : (_timedOut ? AppColors.warning : AppColors.primary));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusMedallion(
                  color: color,
                  icon: !ok
                      ? Icons.close
                      : (_webhookReceived
                          ? Icons.check
                          : (_timedOut
                              ? Icons.access_time
                              : Icons.hourglass_top)),
                  spinning: ok && !settled,
                ),
                AppSpacing.gapXl,
                Text(
                  !ok
                      ? tr(ref, 'mobile.payment.failTitle',
                          "To'lov bekor qilindi")
                      : (_webhookReceived
                          ? tr(ref, 'mobile.payment.successTitle',
                              "To'lov muvaffaqiyatli")
                          : (_timedOut
                              ? tr(ref, 'mobile.payment.delayedTitle',
                                  "Yangilanish kechikmoqda")
                              : tr(ref, 'mobile.payment.pendingTitle',
                                  "Balans yangilanmoqda..."))),
                  style: AppText.titleLg,
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapSm,
                Text(
                  _buildBody(ok),
                  style: AppText.bodyLg
                      .copyWith(color: context.colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (ok && _webhookReceived && _currentBalance != null) ...[
                  AppSpacing.gapMd,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Text(
                      "${tr(ref, 'mobile.lopepay.home.balance', 'Balans')}: ${_fmt.format(_currentBalance)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.titleSm
                          .copyWith(color: AppColors.success),
                    ),
                  ),
                ],
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

  String _buildBody(bool ok) {
    if (!ok) {
      return tr(ref, 'mobile.payment.failMsg',
          "Hech narsa yechilmadi. Qaytadan urinib ko'ring");
    }
    if (_webhookReceived) {
      return tr(ref, 'mobile.payment.successMsg',
          'Balansingiz muvaffaqiyatli yangilandi');
    }
    if (_timedOut) {
      return tr(
          ref,
          'mobile.payment.delayedMsg',
          "Pul yechilgan, lekin balans hali yangilanmadi. Bir necha daqiqadan keyin \"Hisobni ochish\" tugmasidan tekshiring.");
    }
    return tr(ref, 'mobile.payment.pendingMsg',
        "To'lovingiz qabul qilindi. Balans yangilanishini kutyapmiz...");
  }
}

class _StatusMedallion extends StatelessWidget {
  const _StatusMedallion({
    required this.color,
    required this.icon,
    required this.spinning,
  });
  final Color color;
  final IconData icon;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    final medallion = Container(
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
            colors: [
              color,
              color.withValues(alpha: 0.85),
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
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (spinning)
              const SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            Icon(icon, size: 56, color: Colors.white),
          ],
        ),
      ),
    );
    // Only show the "shake" outro after the flow settles — while
    // spinning, the shake feels frantic.
    if (spinning) {
      return medallion.animate().scale(
            duration: 500.ms,
            begin: const Offset(0.4, 0.4),
            curve: Curves.easeOutBack,
          );
    }
    return medallion
        .animate()
        .scale(
          duration: 500.ms,
          begin: const Offset(0.4, 0.4),
          curve: Curves.easeOutBack,
        )
        .then()
        .shake(hz: 2, curve: Curves.easeInOut, duration: 300.ms);
  }
}
