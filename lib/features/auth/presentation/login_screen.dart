import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// Centered Card matching the web's Login.tsx layout. Compact, label-above-
/// input pattern, primary button full width, forgot-password right-aligned,
/// "No account? Register" CTA at the bottom + a Guest button.
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
    return digits.length == 9 && _validPrefixes.contains(digits.substring(0, 2));
  }

  Future<void> _submit() async {
    if (!_isValidPhone(_phoneController.text)) {
      setState(() => _error = tr(ref, 'common.validation.invalidPhone', "Telefon raqam noto'g'ri"));
      return;
    }
    if (_passwordController.text.length < 4) {
      setState(() => _error = tr(ref, 'auth.shortPassword', "Parol kamida 4 belgi"));
      return;
    }
    final phone = '+998${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(phone: phone, password: _passwordController.text);
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      routeToRoleHome(context, user);
    } on Object catch (e) {
      String msg = tr(ref, 'auth.invalidCredentials', "Telefon yoki parol noto'g'ri");
      if (e.toString().contains('SocketException')) {
        msg = tr(ref, 'common.noInternet', "Internetga ulanish yo'q");
      }
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: 48px circular icon bubble + title + description
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.content_cut, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(ref, 'auth.loginTitle', "Xush kelibsiz"),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: AppColors.textBright,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(ref, 'auth.loginSub', "Hisobingizga kiring"),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 22),

                    // Phone label + input
                    _Label(tr(ref, 'auth.phone', "Telefon")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneController,
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
                    ),

                    const SizedBox(height: 14),

                    // Password
                    _Label(tr(ref, 'auth.password', "Parol")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "••••••",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),

                    // Forgot link right
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => context.push('/forgot-password'),
                        child: Text(
                          tr(ref, 'auth.forgotPassword', "Parolni unutdingizmi?"),
                          style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],

                    const SizedBox(height: 14),

                    // Primary submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(tr(ref, 'auth.login', "Kirish")),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // No account? Register
                    Center(
                      child: Wrap(
                        children: [
                          Text("${tr(ref, 'auth.noAccount', "Hisobingiz yo'qmi?")} ",
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.push('/register-phone'),
                            child: Text(
                              tr(ref, 'auth.register', "Ro'yxatdan o'tish"),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    // OR divider
                    Row(children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(tr(ref, 'common.or', 'yoki').toUpperCase(),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ]),
                    const SizedBox(height: 14),

                    // Guest button (outlined)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/home'),
                        icon: const Icon(Icons.person_outline, size: 16),
                        label: Text(tr(ref, 'auth.guestView', "Mehmon sifatida ko'rish")),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card matching shadcn — same bg as scaffold, 1px border, 10px radius.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// `<Label>` from shadcn — small, medium-weight, muted-foreground.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
}
