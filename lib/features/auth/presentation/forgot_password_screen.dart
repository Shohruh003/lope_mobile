import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  int _step = 0;
  String _phone = '';
  String _otp = '';
  String? _error;
  bool _busy = false;

  Future<void> _sendCode(String phone) async {
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
          '/auth/forgot-password/send-code',
          data: {'phone': phone});
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _phone = phone;
        _step = 1;
      });
    } on DioException catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      setState(() => _error = e.response?.statusCode == 404
          ? tr(ref, 'auth.phoneNotRegistered', "Bu raqam ro'yxatda yo'q")
          : tr(ref, 'auth.tryAgain', "Xato — qaytadan urinib ko'ring"));
    } catch (_) {
      AppHaptics.error();
      if (!mounted) return;
      setState(() => _error =
          tr(ref, 'auth.tryAgain', "Xato — qaytadan urinib ko'ring"));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode(String code) async {
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).post(
        '/auth/forgot-password/verify-code',
        data: {'phone': _phone, 'code': code},
      );
      if (!mounted) return;
      if (res.statusCode == 200 || res.data == true) {
        AppHaptics.success();
        setState(() {
          _otp = code;
          _step = 2;
        });
      } else {
        AppHaptics.error();
        setState(() =>
            _error = tr(ref, 'auth.codeWrong', "Kod noto'g'ri"));
      }
    } catch (_) {
      AppHaptics.error();
      if (!mounted) return;
      setState(() => _error = tr(ref, 'auth.codeWrongOrExpired',
          "Kod noto'g'ri yoki muddati tugagan"));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(String newPassword) async {
    AppHaptics.medium();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/auth/forgot-password/reset', data: {
        'phone': _phone,
        'code': _otp,
        'newPassword': newPassword,
      });
      if (!mounted) return;
      AppHaptics.success();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              tr(ref, 'auth.passwordUpdated', 'Parol yangilandi'))));
      context.go('/login');
    } catch (_) {
      AppHaptics.error();
      if (!mounted) return;
      setState(() => _error = tr(ref, 'auth.updateError',
          "Yangilashda xato. Qaytadan urinib ko'ring"));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSwitcher(
              duration: AppMotion.base,
              switchInCurve: AppMotion.emphasized,
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _PhoneStep(
                      busy: _busy, error: _error, onSubmit: _sendCode),
                  1 => _OtpStep(
                      phone: _phone,
                      busy: _busy,
                      error: _error,
                      onSubmit: _verifyCode),
                  _ => _PasswordStep(
                      busy: _busy,
                      error: _error,
                      onSubmit: _resetPassword),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════ Step 1 — Phone ═══════════

class _PhoneStep extends ConsumerStatefulWidget {
  const _PhoneStep(
      {required this.busy, required this.error, required this.onSubmit});
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;
  @override
  ConsumerState<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<_PhoneStep> {
  final _phoneCtrl = TextEditingController();
  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.lock_reset,
      title: tr(ref, 'auth.forgotPassword', 'Parolni unutdingizmi?'),
      subtitle: tr(ref, 'auth.forgotPasswordHint',
          'Telefon raqamingizga 4 raqamli tasdiqlash kodi yuboramiz'),
      error: widget.error,
      children: [
        Text(tr(ref, 'auth.phone', 'Telefon'), style: AppText.overline),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneCtrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(9),
          ],
          style: AppText.body,
          decoration: const InputDecoration(
            prefixText: '+998 ',
            prefixStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
            hintText: '901234567',
          ),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: tr(ref, 'auth.sendCode', 'Kod yuborish'),
          trailingIcon: Icons.send,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: widget.busy,
          onPressed: widget.busy
              ? null
              : () => widget.onSubmit(
                  '+998${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}'),
        ),
      ],
    );
  }
}

// ═══════════ Step 2 — OTP ═══════════

class _OtpStep extends ConsumerStatefulWidget {
  const _OtpStep({
    required this.phone,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });
  final String phone;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;
  @override
  ConsumerState<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends ConsumerState<_OtpStep> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      icon: Icons.mark_email_read_outlined,
      title: tr(ref, 'auth.enterCode', 'Kodni kiriting'),
      subtitle: tr(
          ref,
          'auth.codeSentTo4',
          '{{phone}} raqamiga 4 raqamli kod yubordik',
          {'phone': widget.phone}),
      error: widget.error,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppText.display.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 12,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '0000',
          ),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: tr(ref, 'auth.verify', 'Tasdiqlash'),
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: widget.busy,
          onPressed:
              widget.busy ? null : () => widget.onSubmit(_ctrl.text),
        ),
      ],
    );
  }
}

// ═══════════ Step 3 — New password ═══════════

class _PasswordStep extends ConsumerStatefulWidget {
  const _PasswordStep({
    required this.busy,
    required this.error,
    required this.onSubmit,
  });
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;
  @override
  ConsumerState<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends ConsumerState<_PasswordStep> {
  final _ctrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _localError;

  @override
  void dispose() {
    _ctrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    AppHaptics.medium();
    final pw = _ctrl.text;
    final cf = _confirmCtrl.text;
    if (pw.length < 6) {
      AppHaptics.error();
      setState(() => _localError =
          tr(ref, 'auth.shortPassword', 'Parol kamida 6 belgi'));
      return;
    }
    if (pw != cf) {
      AppHaptics.error();
      setState(() => _localError =
          tr(ref, 'auth.passwordMismatch', 'Parollar mos kelmadi'));
      return;
    }
    setState(() => _localError = null);
    widget.onSubmit(pw);
  }

  @override
  Widget build(BuildContext context) {
    final err = _localError ?? widget.error;
    return _StepScaffold(
      icon: Icons.lock_outline,
      title: tr(ref, 'auth.newPassword', 'Yangi parol'),
      subtitle: tr(ref, 'auth.newPasswordHint',
          "Kamida 6 belgili yangi parol qo'ying"),
      error: err,
      children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          obscureText: _obscure,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: tr(ref, 'auth.newPassword', 'Yangi parol'),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        AppSpacing.gapSm,
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          style: AppText.body,
          decoration: InputDecoration(
            hintText:
                tr(ref, 'auth.confirmPassword', 'Parolni qayta kiriting'),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 20),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: tr(ref, 'auth.updatePassword', 'Parolni yangilash'),
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          loading: widget.busy,
          onPressed: widget.busy ? null : _onSubmit,
        ),
      ],
    );
  }
}

// ═══════════ Step scaffold — shared shell ═══════════

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.error,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSpacing.gapMd,
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadius.rXl,
              boxShadow: AppShadows.primaryGlow(AppColors.primary),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ).animate().scale(
            begin: const Offset(0.5, 0.5),
            duration: 500.ms,
            curve: Curves.easeOutBack),
        AppSpacing.gapLg,
        Text(title, style: AppText.titleLg, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppText.bodyLg.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXxl,
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppSpacing.xl),
          radius: AppRadius.xl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...children,
              if (error != null) ...[
                AppSpacing.gapMd,
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadius.rSm,
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.danger, size: 16),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        error!,
                        style: AppText.bodySm
                            .copyWith(color: AppColors.danger),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
      ],
    );
  }
}
