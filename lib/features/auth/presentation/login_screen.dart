import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes.dart';
import '../../../shared/theme/colors.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// Returning-user login. Hero-centered layout, phone + password fields,
/// post-login routes by role.
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
    '33', '50', '55', '77', '88',
    '80', '87', '92',
  };

  bool _isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 9 && _validPrefixes.contains(digits.substring(0, 2));
  }

  Future<void> _submit() async {
    final raw = _phoneController.text;
    final password = _passwordController.text;
    if (!_isValidPhone(raw)) {
      setState(() => _error = "Telefon raqami noto'g'ri");
      return;
    }
    if (password.length < 4) {
      setState(() => _error = "Parol kamida 4 belgi bo'lishi kerak");
      return;
    }
    final phone = '+998${raw.replaceAll(RegExp(r'\D'), '')}';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).login(
            phone: phone,
            password: password,
          );
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      // Role-aware routing — barbers / shops never see the customer feed.
      routeToRoleHome(context, user);
    } on Object catch (e) {
      String msg = "Telefon yoki parol noto'g'ri";
      if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
        msg = "Internetga ulanish yo'q";
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Hero brand block — centered
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.content_cut, color: Colors.white, size: 44),
                      ).animate().scale(
                            duration: 500.ms,
                            begin: const Offset(0.6, 0.6),
                            end: const Offset(1, 1),
                            curve: Curves.easeOutBack,
                          ),

                      const SizedBox(height: 20),
                      const Text(
                        "Xush kelibsiz",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.1),
                      ).animate().fadeIn(duration: 500.ms, delay: 80.ms).slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 8),
                      const Text(
                        "Lope Style hisobingizga kiring",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                      ).animate().fadeIn(duration: 500.ms, delay: 160.ms),

                      const SizedBox(height: 36),

                      // Phone field — full width but content centered
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.left,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(9),
                        ],
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        decoration: const InputDecoration(
                          prefix: Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Text(
                              "+998",
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                          hintText: "90 123 45 67",
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 240.ms),

                      const SizedBox(height: 14),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "Parol",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        onSubmitted: (_) => _submit(),
                      ).animate().fadeIn(duration: 500.ms, delay: 320.ms),

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
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                              ),
                            ],
                          ),
                        ).animate().shake(hz: 4, duration: 300.ms),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text("Kirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 400.ms),

                      const Spacer(),

                      // Bottom register link
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Hisobingiz yo'qmi?",
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => context.push('/register-phone'),
                              child: const Text(
                                "Ro'yxatdan o'tish",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 500.ms, delay: 480.ms),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
