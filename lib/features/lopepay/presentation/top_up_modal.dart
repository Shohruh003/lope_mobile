import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

/// Mirrors `ClickTopUpModal.tsx` 1:1.
///
/// Two-step flow:
///   Step 1 — Method selection: Telegram bot / Click / Payme
///   Step 2 — Amount input with 4 quick-pick buttons (5k/10k/50k/100k) and
///            free-form input, then "Pay" CTA that opens the gateway in the
///            external browser.
class TopUpModal extends ConsumerStatefulWidget {
  const TopUpModal({super.key});

  /// Imperative helper — push this from anywhere.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const TopUpModal(),
    );
  }

  @override
  ConsumerState<TopUpModal> createState() => _TopUpModalState();
}

class _TopUpModalState extends ConsumerState<TopUpModal> {
  static const _telegramBot = 'https://t.me/lope_style_bot';
  static const _minTopUp = 1000;
  static const _maxTopUp = 1000000;
  static const _quickAmounts = [5000, 10000, 50000, 100000];

  String _step = 'method'; // 'method' | 'amount'
  String _method = 'click'; // 'click' | 'payme'
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse(_telegramBot);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pay() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < _minTopUp) {
      setState(() => _error = tr(ref, 'topUp.minAmount', "Minimal summa 1 000 so'm"));
      return;
    }
    if (amount > _maxTopUp) {
      setState(() => _error = tr(ref, 'topUp.maxAmount', "Maksimal summa 1 000 000 so'm"));
      return;
    }
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await ref.read(balanceRepositoryProvider).initiateTopUp(
            userId: user.id,
            amount: amount,
            gateway: _method,
          );
      if (url.isEmpty) {
        throw Exception(tr(ref, 'topUp.payError', "To'lov tizimi bilan bog'lanishda xatolik"));
      }
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '${tr(ref, 'topUp.payError', "To'lov tizimi bilan bog'lanishda xatolik")}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ===== Header =====
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Text(tr(ref, 'topUp.title', "Balansni to'ldirish"),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),

              const SizedBox(height: 12),

              if (_step == 'method') _methodStep() else _amountStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Text(tr(ref, 'topUp.selectMethod', "To'lov usulini tanlang"),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
      const SizedBox(height: 14),
      _MethodBtn(
        bgColor: const Color(0xFF3B82F6),
        icon: Icons.send,
        title: tr(ref, 'topUp.viaTelegram', "Telegram bot orqali"),
        subtitle: "@lope_style_bot",
        onTap: _openTelegram,
      ),
      const SizedBox(height: 8),
      _MethodBtn(
        bgColor: AppColors.primary,
        icon: Icons.open_in_new,
        title: tr(ref, 'topUp.viaClick', "Click orqali"),
        subtitle: tr(ref, 'topUp.clickDesc', "Online to'lov — darhol balansingizga tushadi"),
        onTap: () => setState(() {
          _method = 'click';
          _step = 'amount';
        }),
      ),
      const SizedBox(height: 8),
      _MethodBtn(
        bgColor: const Color(0xFF2563EB),
        icon: Icons.open_in_new,
        title: tr(ref, 'topUp.viaPayme', "Payme orqali"),
        subtitle: tr(ref, 'topUp.paymeDesc', "Online to'lov — darhol balansingizga tushadi"),
        onTap: () => setState(() {
          _method = 'payme';
          _step = 'amount';
        }),
      ),
    ]);
  }

  Widget _amountStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Back
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.arrow_back, size: 14),
          label: Text(tr(ref, 'topUp.back', "← Orqaga").replaceAll('← ', '')),
          onPressed: () => setState(() {
            _step = 'method';
            _amountCtrl.clear();
            _error = null;
          }),
        ),
      ),
      const SizedBox(height: 4),

      // Quick amounts grid
      Row(children: List.generate(_quickAmounts.length, (i) {
        final q = _quickAmounts[i];
        final on = _amountCtrl.text == q.toString();
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _quickAmounts.length - 1 ? 0 : 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                _amountCtrl.text = q.toString();
                _error = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: on ? AppColors.primary : AppColors.border),
                ),
                child: Center(
                  child: Text("${_fmt(q ~/ 1000)}k",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: on ? AppColors.primary : AppColors.textMuted)),
                ),
              ),
            ),
          ),
        );
      })),

      const SizedBox(height: 14),

      // Amount input
      ShadLabel(tr(ref, 'topUp.enterAmount', "Summa kiriting")),
      const SizedBox(height: 6),
      TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _error = null),
        style: const TextStyle(fontSize: 18, color: AppColors.textBright, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          hintText: "10 000",
          suffixText: "so'm",
          suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 6),
        Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
      ],

      const SizedBox(height: 14),

      SizedBox(
        height: 46,
        child: ElevatedButton.icon(
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.open_in_new, size: 16),
          label: Text(_method == 'payme'
              ? tr(ref, 'topUp.payBtnPayme', "Payme orqali to'lash")
              : tr(ref, 'topUp.payBtn', "Click orqali to'lash")),
          onPressed: _loading ? null : _pay,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _method == 'payme'
            ? tr(ref, 'topUp.redirectNotePayme', "Payme to'lov sahifasiga o'tasiz")
            : tr(ref, 'topUp.redirectNote', "Click to'lov sahifasiga o'tasiz"),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    ]);
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

class _MethodBtn extends StatelessWidget {
  const _MethodBtn({
    required this.bgColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Color bgColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: bgColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textBright)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}
