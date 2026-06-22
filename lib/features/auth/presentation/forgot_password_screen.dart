import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Three steps in a single screen: enter phone → enter OTP → enter new
/// password. Each step is a separate Widget below; the parent holds the
/// progress index.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _step = 0; // 0 = phone, 1 = otp, 2 = new password
  String _phone = '';
  String _otp = '';
  String? _error;
  bool _busy = false;

  Future<void> _sendCode(String phone) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/auth/forgot/send-code', data: {'phone': phone});
      setState(() {
        _phone = phone;
        _step = 1;
      });
    } on DioException catch (e) {
      setState(() => _error = e.response?.statusCode == 404
          ? "Bu raqam ro'yxatda yo'q"
          : "Xato — qaytadan urinib ko'ring");
    } catch (_) {
      setState(() => _error = "Xato — qaytadan urinib ko'ring");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode(String code) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).post(
        '/auth/forgot/verify-code',
        data: {'phone': _phone, 'code': code},
      );
      if (res.statusCode == 200 || res.data == true) {
        setState(() {
          _otp = code;
          _step = 2;
        });
      } else {
        setState(() => _error = tr(ref, 'auth.codeWrong', "Kod noto'g'ri"));
      }
    } catch (_) {
      setState(() => _error = tr(ref, 'auth.codeWrongOrExpired',
          "Kod noto'g'ri yoki muddati tugagan"));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword(String newPassword) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post('/auth/forgot/reset', data: {
        'phone': _phone,
        'code': _otp,
        'newPassword': newPassword,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'auth.passwordUpdated', "Parol yangilandi"))));
      context.go('/login');
    } catch (_) {
      setState(() => _error =
          tr(ref, 'auth.updateError', "Yangilashda xato. Qaytadan urinib ko'ring"));
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (_step) {
            0 => _PhoneStep(busy: _busy, error: _error, onSubmit: _sendCode),
            1 => _OtpStep(phone: _phone, busy: _busy, error: _error, onSubmit: _verifyCode),
            _ => _PasswordStep(busy: _busy, error: _error, onSubmit: _resetPassword),
          },
        ),
      ),
    );
  }
}

class _PhoneStep extends ConsumerStatefulWidget {
  const _PhoneStep({required this.busy, required this.error, required this.onSubmit});
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;
  @override
  ConsumerState<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<_PhoneStep> {
  final _phoneCtrl = TextEditingController();
  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(tr(ref, 'auth.forgotPassword', "Parolni unutdingizmi?"),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1, color: AppColors.textBright))
            .animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 12),
        Text(tr(ref, 'auth.forgotPasswordHint', "Telefon raqamingizga 4 raqamli tasdiqlash kodi yuboramiz"),
            style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 32),
        TextField(
          controller: _phoneCtrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textBright),
          decoration: const InputDecoration(
            prefix: Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text("+998", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textBright)),
            ),
            hintText: "90 123 45 67",
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Text(widget.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.busy ? null : () => widget.onSubmit('+998${_phoneCtrl.text.trim()}'),
            child: widget.busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr(ref, 'auth.sendCode', "Kod yuborish"),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends ConsumerStatefulWidget {
  const _OtpStep({required this.phone, required this.busy, required this.error, required this.onSubmit});
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
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(tr(ref, 'auth.enterCode', "Kodni kiriting"),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textBright)),
        const SizedBox(height: 12),
        Text(tr(ref, 'auth.codeSentTo4', '{{phone}} raqamiga 4 raqamli kod yubordik',
                {'phone': widget.phone}),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textBright, letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', hintText: '0000'),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Text(widget.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.busy ? null : () => widget.onSubmit(_ctrl.text),
            child: widget.busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr(ref, 'auth.verify', "Tasdiqlash"),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _PasswordStep extends ConsumerStatefulWidget {
  const _PasswordStep({required this.busy, required this.error, required this.onSubmit});
  final bool busy;
  final String? error;
  final ValueChanged<String> onSubmit;
  @override
  ConsumerState<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends ConsumerState<_PasswordStep> {
  final _ctrl = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(tr(ref, 'auth.newPassword', "Yangi parol"),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textBright)),
        const SizedBox(height: 12),
        Text(tr(ref, 'auth.newPasswordHint', "Kamida 4 belgili yangi parol qo'ying"),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          autofocus: true,
          obscureText: _obscure,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textBright),
          decoration: InputDecoration(
            hintText: tr(ref, 'auth.newPassword', "Yangi parol"),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 12),
          Text(widget.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.busy ? null : () => widget.onSubmit(_ctrl.text),
            child: widget.busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(tr(ref, 'auth.updatePassword', "Parolni yangilash"),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
