import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/roles.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

class LowBalanceWatcher {
  static const _minBalance = 5000;
  static const _dismissedUntilKey = 'balance-modal-dismissed-until';

  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || !isBarberRole(user.role)) return;
    if (user.isVip) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedUntil = prefs.getInt(_dismissedUntilKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < dismissedUntil) return;

    int amount;
    try {
      final b =
          await ref.read(balanceRepositoryProvider).myBalance(user.id);
      amount = b.amount;
    } catch (_) {
      return;
    }
    if (amount >= _minBalance) return;
    if (!context.mounted) return;

    AppHaptics.medium();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => _LowBalanceDialog(balance: amount),
    );
  }
}

class _LowBalanceDialog extends ConsumerStatefulWidget {
  const _LowBalanceDialog({required this.balance});
  final int balance;
  @override
  ConsumerState<_LowBalanceDialog> createState() =>
      _LowBalanceDialogState();
}

class _LowBalanceDialogState extends ConsumerState<_LowBalanceDialog> {
  bool _dontShowYear = false;

  Future<void> _dismiss() async {
    AppHaptics.light();
    final prefs = await SharedPreferences.getInstance();
    final ms = _dontShowYear
        ? 365 * 24 * 60 * 60 * 1000
        : 7 * 24 * 60 * 60 * 1000;
    await prefs.setInt(LowBalanceWatcher._dismissedUntilKey,
        DateTime.now().millisecondsSinceEpoch + ms);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _topUp() async {
    AppHaptics.medium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(LowBalanceWatcher._dismissedUntilKey,
        DateTime.now().millisecondsSinceEpoch + 24 * 60 * 60 * 1000);
    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/transactions');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
            AppSpacing.gapLg,
            Text(
              tr(ref, 'topUp.lowBalanceTitle',
                  "Hisobingizni to'ldiring"),
              style: AppText.titleMd,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapSm,
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: AppRadius.rMd,
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25)),
              ),
              child: Column(children: [
                Text(
                  tr(ref, 'topUp.currentBalance', 'Joriy balans'),
                  style: AppText.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  "${_fmt(widget.balance)} ${tr(ref, 'common.currency', "so'm")}",
                  style: AppText.numeric.copyWith(
                    color: AppColors.warning,
                    fontSize: 24,
                  ),
                ),
              ]),
            ),
            AppSpacing.gapMd,
            Text(
              tr(ref, 'topUp.lowBalanceHint',
                  "Balans yetarli bo'lmasa mijozlarga SMS eslatmalar yuborilmaydi."),
              textAlign: TextAlign.center,
              style: AppText.bodySm,
            ),
            AppSpacing.gapMd,
            Row(children: [
              Checkbox(
                value: _dontShowYear,
                onChanged: (v) =>
                    setState(() => _dontShowYear = v ?? false),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  tr(ref, 'topUp.dontShowAgain',
                      "Endi 1 yil ko'rsatma"),
                  style: AppText.bodySm,
                ),
              ),
            ]),
            AppSpacing.gapMd,
            AppButton(
              label: tr(ref, 'topUp.topUpBtn', "Hisob to'ldirish")
                  .replaceAll('💳 ', ''),
              leadingIcon: Icons.account_balance_wallet,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: _topUp,
            ),
            AppSpacing.gapSm,
            AppButton(
              label: tr(ref, 'topUp.later', 'Keyinroq'),
              variant: AppButtonVariant.ghost,
              fullWidth: true,
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}
