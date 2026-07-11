import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// Login — Uzum/Click darajasidagi kirish sahifasi.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
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
    if (_passwordController.text.length < 4) {
      AppHaptics.error();
      setState(() =>
          _error = tr(ref, 'auth.shortPassword', 'Parol kamida 4 belgi'));
      return;
    }
    final phone =
        '+998${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).login(
          phone: phone, password: _passwordController.text);
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      AppHaptics.success();
      routeToRoleHome(context, user);
    } on Object catch (e) {
      AppHaptics.error();
      // Was `e.toString().contains('SocketException')` — Dio wraps
      // network failures in a typed exception, so checking the type is
      // both cheaper and doesn't break when the exception's toString
      // changes.
      final isOffline = e is DioException &&
          e.type == DioExceptionType.connectionError;
      final msg = isOffline
          ? tr(ref, 'common.noInternet', "Internetga ulanish yo'q")
          : tr(ref, 'auth.invalidCredentials',
              "Telefon yoki parol noto'g'ri");
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  // Gradient logo pill
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
                      child: const Icon(Icons.content_cut,
                          color: Colors.white, size: 34),
                    ),
                  )
                      .animate()
                      .scale(
                          begin: const Offset(0.5, 0.5),
                          duration: 500.ms,
                          curve: Curves.easeOutBack)
                      .fadeIn(duration: 400.ms),
                  AppSpacing.gapLg,
                  Text(
                    tr(ref, 'auth.loginTitle', 'Xush kelibsiz'),
                    style: AppText.titleLg,
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms),
                  const SizedBox(height: 6),
                  Text(
                    tr(ref, 'auth.loginSub', 'Hisobingizga kiring'),
                    style: AppText.bodyLg
                        .copyWith(color: context.colors.textMuted),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 150.ms),
                  AppSpacing.gapXxl,

                  // Card
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    radius: AppRadius.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Phone
                        _Label(tr(ref, 'auth.phone', 'Telefon')),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
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
                        ),

                        AppSpacing.gapMd,

                        // Password
                        _Label(tr(ref, 'auth.password', 'Parol')),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppText.body,
                          decoration: InputDecoration(
                            hintText: '••••••',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: context.colors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),

                        // Forgot
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TapScale(
                            onTap: () => context.push('/forgot-password'),
                            scale: 0.95,
                            child: Text(
                              tr(ref, 'auth.forgotPassword',
                                  'Parolni unutdingizmi?'),
                              style: AppText.bodySm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        if (_error != null) ...[
                          AppSpacing.gapMd,
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: AppRadius.rSm,
                              border: Border.all(
                                color:
                                    AppColors.danger.withValues(alpha: 0.3),
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

                        // Login CTA
                        AppButton(
                          label: tr(ref, 'auth.login', 'Kirish'),
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          loading: _loading,
                          onPressed: _loading ? null : _submit,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                  AppSpacing.gapLg,

                  // No account? Register
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        Text(
                          "${tr(ref, 'auth.noAccount', "Hisobingiz yo'qmi?")} ",
                          style: AppText.body
                              .copyWith(color: context.colors.textMuted),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppHaptics.light();
                            context.push('/register-phone');
                          },
                          child: Text(
                            tr(ref, 'auth.register', "Ro'yxatdan o'tish"),
                            style: AppText.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  AppSpacing.gapXl,

                  // OR
                  Row(children: [
                    Expanded(
                        child: Divider(color: context.colors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Text(
                        tr(ref, 'common.or', 'yoki').toUpperCase(),
                        style: AppText.overline,
                      ),
                    ),
                    Expanded(
                        child: Divider(color: context.colors.border)),
                  ]),
                  AppSpacing.gapLg,

                  AppButton(
                    label:
                        tr(ref, 'auth.guestView', "Mehmon sifatida ko'rish"),
                    leadingIcon: Icons.person_outline,
                    variant: AppButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: () => context.push('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.overline);
}
