import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../data/auth_repository.dart';

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
    '33', '50', '55', '77', '88', '80', '87', '92',
  };

  bool _isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9 && _validPrefixes.contains(digits.substring(0, 2));
  }

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    if (!_isValidPhone(_phoneController.text)) {
      HapticFeedback.heavyImpact();
      setState(() => _error = tr(ref, 'common.validation.invalidPhone', "Telefon raqam noto'g'ri"));
      return;
    }
    final phone = '+998${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendRegistrationCode(phone);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.push('/register-otp?phone=${Uri.encodeComponent(phone)}');
    } on Object catch (e) {
      HapticFeedback.heavyImpact();
      String msg = tr(ref, 'common.errorRetry', "Xatolik — qaytadan urinib ko'ring");
      if (e.toString().contains('SocketException')) {
        msg = tr(ref, 'common.noInternet', "Internetga ulanish yo'q");
      }
      if (e.toString().contains('409')) {
        msg = tr(ref, 'auth.phoneAlreadyRegistered', "Bu raqam allaqachon ro'yxatdan o'tgan");
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ShadCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Center(
                    child: Column(children: [
                      const ShadIconBubble(icon: Icons.phone_outlined),
                      const SizedBox(height: 12),
                      ShadCardTitle(tr(ref, 'auth.yourPhone', "Telefon raqamingiz")),
                      const SizedBox(height: 4),
                      ShadCardDescription(tr(ref, 'auth.weWillSendCode',
                          "4 raqamli tasdiqlash kodi yuboramiz")),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  ShadField(
                    label: tr(ref, 'auth.phone', "Telefon"),
                    error: _error,
                    child: TextField(
                      controller: _phoneController,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(9),
                      ],
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        prefixText: '+998 ',
                        prefixStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                        hintText: '901234567',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(tr(ref, 'common.continue', "Davom etish")),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),
        ),
      ),
    );
  }
}
