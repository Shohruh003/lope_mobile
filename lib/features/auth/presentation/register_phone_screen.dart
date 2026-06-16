import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/colors.dart';
import '../data/auth_repository.dart';

/// First step of registration: collect phone, kick off the OTP send. On
/// success we push the OTP screen with the phone embedded in the query
/// string so a deep-link refresh still works.
class RegisterPhoneScreen extends ConsumerStatefulWidget {
  const RegisterPhoneScreen({super.key});

  @override
  ConsumerState<RegisterPhoneScreen> createState() => _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends ConsumerState<RegisterPhoneScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _validPrefixes = {
    '90', '91', '93', '94', '95', '97', '98', '99',
    '33', '50', '55', '77', '88',
    '80', '87', '92',
  };

  bool _isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9 && _validPrefixes.contains(digits.substring(0, 2));
  }

  Future<void> _submit() async {
    final raw = _phoneController.text;
    if (!_isValidPhone(raw)) {
      setState(() => _error = "Telefon raqami noto'g'ri");
      return;
    }
    final phone = '+998${raw.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendRegistrationCode(phone);
      if (!mounted) return;
      context.push('/register-otp?phone=${Uri.encodeComponent(phone)}');
    } on Object catch (e) {
      String msg = "Xatolik — qaytadan urinib ko'ring";
      if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
        msg = "Internetga ulanish yo'q";
      } else if (e.toString().contains('409') || e.toString().contains('already')) {
        msg = "Bu raqam allaqachon ro'yxatdan o'tgan";
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
                "Telefon raqamingiz",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.1,
                  color: AppColors.textBright,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 12),
              const Text(
                "Sizga 4 raqamli tasdiqlash kodi yuboramiz",
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5, fontWeight: FontWeight.w500),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
              const SizedBox(height: 36),
              TextField(
                controller: _phoneController,
                autofocus: true,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppColors.textBright),
                decoration: const InputDecoration(
                  prefix: Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Text(
                      "+998",
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textBright),
                    ),
                  ),
                  hintText: "90 123 45 67",
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 17, fontWeight: FontWeight.w500),
                ),
                onSubmitted: (_) => _submit(),
              ).animate().fadeIn(duration: 400.ms, delay: 160.ms),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ).animate().shake(hz: 4, duration: 300.ms),
              ],

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Davom etish", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 240.ms),
            ],
          ),
        ),
      ),
    );
  }
}
