import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import '../data/auth_repository.dart';

/// 4-digit OTP for the registration flow. Auto-advances, auto-submits on the
/// last digit, resends after a 60s cooldown. On success we route forward to
/// the final step (name + password) carrying the verified phone.
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
      setState(() => _error = "Kod 4 raqamli bo'lishi kerak");
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
      // OTP good — push to the final step. The phone + code travel together
      // so the register endpoint can re-verify atomically.
      context.push(
        '/register-complete?phone=${Uri.encodeComponent(widget.phone)}&code=$_code',
      );
    } on Object catch (_) {
      setState(() => _error = "Kod noto'g'ri yoki muddati tugagan");
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yangi kod yuborildi")),
        );
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Xatolik — qaytadan urinib ko'ring")),
        );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                "Kodni kiriting",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 10),
              Text(
                "${widget.phone} raqamiga 4 raqamli kod yubordik",
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(4, (i) => _otpCell(i)),
              ).animate().fadeIn(duration: 500.ms, delay: 160.ms),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading || _code.length != 4 ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Tasdiqlash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: _resendIn > 0
                    ? Text(
                        "Qayta yuborish: $_resendIn s",
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text("Kodni qayta yuborish"),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otpCell(int i) {
    final hasValue = _controllers[i].text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: 64,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? AppColors.primary : AppColors.border,
          width: hasValue ? 1.5 : 1,
        ),
        boxShadow: hasValue
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controllers[i],
        focusNode: _focusNodes[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
          filled: false,
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
