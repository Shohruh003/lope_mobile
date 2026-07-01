import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
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
    if (_code.length != 4) {
      setState(() =>
          _error = tr(ref, 'auth.codeMustBe4', "Kod 4 raqamli bo'lishi kerak"));
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
      context.push('/register-complete?phone=${Uri.encodeComponent(widget.phone)}&code=$_code');
    } on Object catch (_) {
      setState(() =>
          _error = tr(ref, 'auth.codeWrongOrExpired', "Kod noto'g'ri yoki muddati tugagan"));
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
    try {
      await ref.read(authRepositoryProvider).sendRegistrationCode(widget.phone);
      _startResendCountdown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'auth.newCodeSent', "Yangi kod yuborildi"))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.errorRetry', "Xatolik — qaytadan urinib ko'ring"))));
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ShadCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Column(children: [
                      const ShadIconBubble(icon: Icons.mark_email_read_outlined),
                      const SizedBox(height: 12),
                      ShadCardTitle(tr(ref, 'auth.enterCode', "Kodni kiriting")),
                      const SizedBox(height: 4),
                      ShadCardDescription(tr(ref, 'auth.codeSentToPhone',
                          "{{phone}} raqamiga yuborildi", {'phone': widget.phone})),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (i) => _otpCell(i)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading || _code.length != 4 ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr(ref, 'auth.verify', "Tasdiqlash")),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: _resendIn > 0
                        ? Text(
                            "${tr(ref, 'auth.resendIn', 'Qayta yuborish')}: $_resendIn ${tr(ref, 'auth.secondsShort', 's')}",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14))
                        : TextButton(
                            onPressed: _resend,
                            child: Text(tr(ref, 'auth.resendCode', "Kodni qayta yuborish"))),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpCell(int i) {
    final hasValue = _controllers[i].text.isNotEmpty;
    return SizedBox(
      width: 60, height: 60,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textBright),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasValue ? AppColors.primary : AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: hasValue ? AppColors.primary : AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
