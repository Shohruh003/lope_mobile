import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routes.dart';
import '../../../shared/theme/colors.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

/// Final registration step — name + password. The phone (already verified)
/// arrives via query string from the OTP screen. Default role is 'user' (i.e.
/// customer); barber/shop signup happens through a separate flow we'll add
/// later once the customer path is rock solid.
class RegisterCompleteScreen extends ConsumerStatefulWidget {
  const RegisterCompleteScreen({super.key, required this.phone});
  final String phone;

  @override
  ConsumerState<RegisterCompleteScreen> createState() => _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState extends ConsumerState<RegisterCompleteScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    if (name.length < 2) {
      setState(() => _error = "Ismni kiriting (kamida 2 belgi)");
      return;
    }
    if (password.length < 4) {
      setState(() => _error = "Parol kamida 4 belgi bo'lishi kerak");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).register(
            name: name,
            phone: widget.phone,
            password: password,
            role: 'user',
          );
      await ref.read(authControllerProvider.notifier).signedIn(user);
      if (!mounted) return;
      routeToRoleHome(context, user);
    } on Object catch (e) {
      String msg = "Ro'yxatdan o'tishda xato";
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
    _nameController.dispose();
    _passwordController.dispose();
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
                "Ozgina qoldi",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 10),
              const Text(
                "Ismingiz va parol — keyin yana kerakmas",
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),

              const SizedBox(height: 36),

              _Label("Ismingiz"),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(hintText: "Masalan: Shohruh"),
              ).animate().fadeIn(duration: 400.ms, delay: 160.ms),

              const SizedBox(height: 18),

              _Label("Parol"),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Kamida 4 belgi",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ).animate().fadeIn(duration: 400.ms, delay: 240.ms),

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
                      : const Text("Ro'yxatdan o'tish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 320.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget _Label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      );
}
