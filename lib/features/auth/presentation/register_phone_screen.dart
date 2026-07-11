import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../data/auth_repository.dart';

class RegisterPhoneScreen extends ConsumerStatefulWidget {
  const RegisterPhoneScreen({super.key});
  @override
  ConsumerState<RegisterPhoneScreen> createState() =>
      _RegisterPhoneScreenState();
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
    return digits.length == 9 &&
        _validPrefixes.contains(digits.substring(0, 2));
  }

  Future<void> _submit() async {
    AppHaptics.medium();
    if (!_isValidPhone(_phoneController.text)) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'common.validation.invalidPhone',
          "Telefon raqam noto'g'ri"));
      return;
    }
    final phone =
        '+998${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendRegistrationCode(phone);
      if (!mounted) return;
      AppHaptics.success();
      context.push('/register-otp?phone=${Uri.encodeComponent(phone)}');
    } on Object catch (e) {
      AppHaptics.error();
      final isDio = e is DioException;
      final isOffline = isDio &&
          (e).type == DioExceptionType.connectionError;
      final isConflict = isDio && (e).response?.statusCode == 409;
      String msg = tr(ref, 'common.errorRetry',
          "Xatolik — qaytadan urinib ko'ring");
      if (isOffline) {
        msg = tr(ref, 'common.noInternet', "Internetga ulanish yo'q");
      } else if (isConflict) {
        msg = tr(ref, 'auth.phoneAlreadyRegistered',
            "Bu raqam allaqachon ro'yxatdan o'tgan");
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
                      child: const Icon(Icons.phone_outlined,
                          color: Colors.white, size: 32),
                    ),
                  ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      duration: 500.ms,
                      curve: Curves.easeOutBack),
                  AppSpacing.gapLg,
                  Text(
                    tr(ref, 'auth.yourPhone', 'Telefon raqamingiz'),
                    style: AppText.titleLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(ref, 'auth.weWillSendCode',
                        '4 raqamli tasdiqlash kodi yuboramiz'),
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
                        Text(tr(ref, 'auth.phone', 'Telefon'),
                            style: AppText.overline),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          style: AppText.body,
                          decoration: InputDecoration(
                            prefixText: '+998 ',
                            prefixStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textMuted,
                            ),
                            hintText: '901234567',
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          AppSpacing.gapMd,
                          Container(
                            padding:
                                const EdgeInsets.all(AppSpacing.sm),
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
                                child: Text(
                                  _error!,
                                  style: AppText.bodySm.copyWith(
                                      color: AppColors.danger),
                                ),
                              ),
                            ]),
                          ),
                        ],
                        AppSpacing.gapLg,
                        AppButton(
                          label:
                              tr(ref, 'common.continue', 'Davom etish'),
                          trailingIcon: Icons.arrow_forward,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          loading: _loading,
                          onPressed: _loading ? null : _submit,
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
}
