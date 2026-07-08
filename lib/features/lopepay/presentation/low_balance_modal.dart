import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/roles.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

/// Mirrors the web's low-balance modal logic from `BarberLayout.tsx`:
///   - Auto-pops once after login if balance < 5000
///   - Dismiss options: "7 kun ko'rsatma" or "1 yil ko'rsatma" (stored in
///     SharedPreferences so the user isn't hammered every screen)
///   - "Hisobni to'ldirish" button → navigates to /transactions
///
/// Call `LowBalanceWatcher.maybeShow(context, ref)` once from each
/// barber-side shell.
class LowBalanceWatcher {
  static const _minBalance = 5000;
  static const _dismissedUntilKey = 'balance-modal-dismissed-until';

  /// Decide whether to pop the modal and if so, show it.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || !isBarberRole(user.role)) return;

    // VIP barbers are billed separately for SMS and shouldn't see the
    // top-up modal. Web fix 71a0b33 added the same guard on BarberLayout.
    // AppUser.vipUntil is populated from the nested barber.vipUntil on the
    // login + /auth/me responses so we can check it inline without an
    // extra /barbers/:id round-trip.
    if (user.isVip) return;

    // Already dismissed?
    final prefs = await SharedPreferences.getInstance();
    final dismissedUntil = prefs.getInt(_dismissedUntilKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < dismissedUntil) return;

    // Fetch balance
    int amount;
    try {
      final b = await ref.read(balanceRepositoryProvider).myBalance(user.id);
      amount = b.amount;
    } catch (_) {
      return;
    }
    if (amount >= _minBalance) return;
    if (!context.mounted) return;

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
  ConsumerState<_LowBalanceDialog> createState() => _LowBalanceDialogState();
}

class _LowBalanceDialogState extends ConsumerState<_LowBalanceDialog> {
  bool _dontShowYear = false;

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = _dontShowYear
        ? 365 * 24 * 60 * 60 * 1000 // 1 year
        : 7 * 24 * 60 * 60 * 1000; // 7 days
    await prefs.setInt(
        LowBalanceWatcher._dismissedUntilKey,
        DateTime.now().millisecondsSinceEpoch + ms);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _topUp() async {
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
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 28),
            ),
            const SizedBox(height: 14),
            Text(tr(ref, 'topUp.lowBalanceTitle', "Hisobingizni to'ldiring"),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text(
              "${tr(ref, 'topUp.currentBalance', 'Joriy balans')}: ${_fmt(widget.balance)} ${tr(ref, 'common.currency', "so'm")}.\n${tr(ref, 'topUp.lowBalanceHint', "Balans yetarli bo'lmasa mijozlarga SMS eslatmalar yuborilmaydi.")}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),

            // Don't-show-1-year checkbox
            Row(children: [
              Checkbox(
                value: _dontShowYear,
                onChanged: (v) => setState(() => _dontShowYear = v ?? false),
                activeColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  tr(ref, 'topUp.dontShowAgain', "Endi 1 yil ko'rsatma"),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.account_balance_wallet, size: 16),
                label: Text(tr(ref, 'topUp.topUpBtn', "Hisob to'ldirish")
                    .replaceAll('💳 ', '')),
                onPressed: _topUp,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: _dismiss,
                child: Text(tr(ref, 'topUp.later', "Keyinroq")),
              ),
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
