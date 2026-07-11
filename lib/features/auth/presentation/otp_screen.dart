import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../data/auth_repository.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());
  bool _loading = false;
  String? _error;
  int _resendIn = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startResendCountdown() {
    _resendIn = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _resendIn--;
        if (_resendIn <= 0) t.cancel();
      });
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _submit() async {
    AppHaptics.medium();
    if (_code.length != 4) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'auth.codeMustBe4',
          "Kod 4 raqamli bo'lishi kerak"));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .verifyRegistrationCode(phone: widget.phone, code: _code);
      if (!ok) throw Exception('Invalid OTP');
      if (!mounted) return;
      AppHaptics.success();
      context.push(
          '/register-complete?phone=${Uri.encodeComponent(widget.phone)}&code=$_code');
    } on Object catch (_) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'auth.codeWrongOrExpired',
          "Kod noto'g'ri yoki muddati tugagan"));
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    AppHaptics.light();
    try {
      await ref
          .read(authRepositoryProvider)
          .sendRegistrationCode(widget.phone);
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(tr(ref, 'auth.newCodeSent', 'Yangi kod yuborildi'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.errorRetry',
                "Xatolik — qaytadan urinib ko'ring"))));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: AppRadius.rXl,
                        boxShadow:
                            AppShadows.primaryGlow(AppColors.primary),
                      ),
                      child: const Icon(Icons.mark_email_read_outlined,
                          color: Colors.white, size: 32),
                    ),
                  ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 500.ms,
                      curve: Curves.easeOutBack),
                  AppSpacing.gapLg,
                  Text(
                    tr(ref, 'auth.enterCode', 'Kodni kiriting'),
                    style: AppText.titleLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                        ref,
                        'auth.codeSentToPhone',
                        '{{phone}} raqamiga yuborildi',
                        {'phone': widget.phone}),
                    style: AppText.bodyLg
                        .copyWith(color: context.colors.textMuted),
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
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: List.generate(4, (i) => _otpCell(i)),
                        ),
                        if (_error != null) ...[
                          AppSpacing.gapMd,
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.danger
                                  .withValues(alpha: 0.1),
                              borderRadius: AppRadius.rSm,
                              border: Border.all(
                                color: AppColors.danger
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.danger, size: 16),
                              AppSpacing.hGapSm,
                              Expanded(
                                child: Text(_error!,
                                    style: AppText.bodySm.copyWith(
                                        color: AppColors.danger)),
                              ),
                            ]),
                          ),
                        ],
                        AppSpacing.gapLg,
                        AppButton(
                          label: tr(ref, 'auth.verify', 'Tasdiqlash'),
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          loading: _loading,
                          onPressed: _loading || _code.length != 4
                              ? null
                              : _submit,
                        ),
                        AppSpacing.gapMd,
                        Center(
                          child: _resendIn > 0
                              ? Text(
                                  "${tr(ref, 'auth.resendIn', 'Qayta yuborish')}: $_resendIn ${tr(ref, 'auth.secondsShort', 's')}",
                                  style: AppText.bodySm,
                                )
                              : TapScale(
                                  onTap: _resend,
                                  scale: 0.95,
                                  child: Text(
                                    tr(ref, 'auth.resendCode',
                                        'Kodni qayta yuborish'),
                                    style: AppText.body.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpCell(int i) {
    final hasValue = _controllers[i].text.isNotEmpty;
    return SizedBox(
      width: 60,
      height: 68,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppText.display.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasValue
              ? AppColors.primary.withValues(alpha: 0.1)
              : context.colors.surfaceElevated,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(
                color:
                    hasValue ? AppColors.primary : context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: BorderSide(
                color:
                    hasValue ? AppColors.primary : context.colors.border,
                width: hasValue ? 2 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(
                color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (v) {
          setState(() {});
          if (v.isNotEmpty && i < 3) {
            _focusNodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _focusNodes[i - 1].requestFocus();
          } else if (v.isNotEmpty && i == 3) {
            _focusNodes[i].unfocus();
            _submit();
          }
        },
      ),
    );
  }
}
