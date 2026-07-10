import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';

class TopUpModal extends ConsumerStatefulWidget {
  const TopUpModal({super.key});

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

  String _step = 'method';
  String _method = 'click';
  final _amountCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    AppHaptics.light();
    final uri = Uri.parse(_telegramBot);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pay() async {
    AppHaptics.medium();
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < _minTopUp) {
      AppHaptics.error();
      setState(() => _error =
          tr(ref, 'topUp.minAmount', "Minimal summa 1 000 so'm"));
      return;
    }
    if (amount > _maxTopUp) {
      AppHaptics.error();
      setState(() => _error =
          tr(ref, 'topUp.maxAmount', "Maksimal summa 1 000 000 so'm"));
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
        throw Exception(tr(ref, 'topUp.payError',
            "To'lov tizimi bilan bog'lanishda xatolik"));
      }
      final uri = Uri.tryParse(url);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      AppHaptics.error();
      setState(() => _error =
          '${tr(ref, 'topUp.payError', "To'lov tizimi bilan bog'lanishda xatolik")}: $e');
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
          color: AppColors.surface,
          borderRadius: AppRadius.rTopXl,
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom:
                AppSpacing.xxl + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
              ),
              AppSpacing.gapLg,
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.rMd,
                    boxShadow:
                        AppShadows.primaryGlow(AppColors.primary),
                  ),
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.white, size: 22),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Text(
                    tr(ref, 'topUp.title', "Balansni to'ldirish"),
                    style: AppText.titleMd,
                  ),
                ),
                TapScale(
                  onTap: () => Navigator.of(context).pop(),
                  scale: 0.9,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 16),
                  ),
                ),
              ]),
              AppSpacing.gapLg,
              if (_step == 'method') _methodStep() else _amountStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        tr(ref, 'topUp.selectMethod', "To'lov usulini tanlang"),
        style: AppText.overline,
      ),
      AppSpacing.gapMd,
      _MethodBtn(
        bgColor: const Color(0xFF2AABEE),
        icon: Icons.send,
        title: tr(ref, 'topUp.viaTelegram', 'Telegram bot orqali'),
        subtitle: '@lope_style_bot',
        onTap: _openTelegram,
      ),
      AppSpacing.gapSm,
      _MethodBtn(
        bgColor: AppColors.primary,
        icon: Icons.open_in_new,
        title: tr(ref, 'topUp.viaClick', 'Click orqali'),
        subtitle: tr(ref, 'topUp.clickDesc',
            "Online to'lov — darhol balansingizga tushadi"),
        onTap: () {
          AppHaptics.light();
          setState(() {
            _method = 'click';
            _step = 'amount';
          });
        },
      ),
      AppSpacing.gapSm,
      _MethodBtn(
        bgColor: const Color(0xFF2563EB),
        icon: Icons.open_in_new,
        title: tr(ref, 'topUp.viaPayme', 'Payme orqali'),
        subtitle: tr(ref, 'topUp.paymeDesc',
            "Online to'lov — darhol balansingizga tushadi"),
        onTap: () {
          AppHaptics.light();
          setState(() {
            _method = 'payme';
            _step = 'amount';
          });
        },
      ),
    ]);
  }

  Widget _amountStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TapScale(
        onTap: () {
          AppHaptics.light();
          setState(() {
            _step = 'method';
            _amountCtrl.clear();
            _error = null;
          });
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.arrow_back,
              color: AppColors.primary, size: 18),
          AppSpacing.hGapXs,
          Text(
            tr(ref, 'topUp.back', "Orqaga").replaceAll('← ', ''),
            style: AppText.body.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
      AppSpacing.gapMd,
      Text(
        tr(ref, 'topUp.enterAmount', 'Summa kiriting'),
        style: AppText.overline,
      ),
      AppSpacing.gapSm,
      Row(
        children: List.generate(_quickAmounts.length, (i) {
          final q = _quickAmounts[i];
          final on = _amountCtrl.text == q.toString();
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == _quickAmounts.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: TapScale(
                onTap: () {
                  AppHaptics.selection();
                  setState(() {
                    _amountCtrl.text = q.toString();
                    _error = null;
                  });
                },
                scale: 0.95,
                child: AnimatedContainer(
                  duration: AppMotion.base,
                  curve: AppMotion.emphasized,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: on
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surface,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(
                      color:
                          on ? AppColors.primary : AppColors.border,
                      width: on ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${_fmt(q ~/ 1000)}k',
                      style: AppText.body.copyWith(
                        fontWeight: FontWeight.w800,
                        color: on
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      AppSpacing.gapMd,
      TextField(
        controller: _amountCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() => _error = null),
        style: AppText.numeric.copyWith(fontSize: 22),
        decoration: InputDecoration(
          hintText: '10 000',
          suffixText: tr(ref, 'common.currency', "so'm"),
          suffixStyle: AppText.body.copyWith(color: AppColors.textMuted),
        ),
      ),
      if (_error != null) ...[
        AppSpacing.gapSm,
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.1),
            borderRadius: AppRadius.rSm,
          ),
          child: Row(children: [
            const Icon(Icons.error_outline,
                color: AppColors.danger, size: 14),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(_error!,
                  style: AppText.bodySm.copyWith(color: AppColors.danger)),
            ),
          ]),
        ),
      ],
      AppSpacing.gapLg,
      AppButton(
        label: _method == 'payme'
            ? tr(ref, 'topUp.payBtnPayme', "Payme orqali to'lash")
            : tr(ref, 'topUp.payBtn', "Click orqali to'lash"),
        trailingIcon: Icons.open_in_new,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.lg,
        fullWidth: true,
        loading: _loading,
        onPressed: _loading ? null : _pay,
      ),
      AppSpacing.gapSm,
      Center(
        child: Text(
          _method == 'payme'
              ? tr(ref, 'topUp.redirectNotePayme',
                  "Payme to'lov sahifasiga o'tasiz")
              : tr(ref, 'topUp.redirectNote',
                  "Click to'lov sahifasiga o'tasiz"),
          style: AppText.caption,
        ),
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
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.15),
            borderRadius: AppRadius.rSm,
          ),
          child: Icon(icon, color: bgColor, size: 20),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleSm),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
        const Icon(Icons.chevron_right,
            color: AppColors.textMuted, size: 18),
      ]),
    );
  }
}
