import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routes.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../data/auth_repository.dart';
import 'auth_controller.dart';

class RegisterCompleteScreen extends ConsumerStatefulWidget {
  const RegisterCompleteScreen({super.key, required this.phone});
  final String phone;
  @override
  ConsumerState<RegisterCompleteScreen> createState() => _RegisterCompleteScreenState();
}

class _RegisterCompleteScreenState extends ConsumerState<RegisterCompleteScreen> {
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (name.length < 2) {
      setState(() => _error = "Ismni kiriting");
      return;
    }
    if (password.length < 4) {
      setState(() => _error = "Parol kamida 4 belgi");
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
      if (e.toString().contains('SocketException')) msg = "Internetga ulanish yo'q";
      if (e.toString().contains('409')) msg = "Bu raqam allaqachon ro'yxatdan o'tgan";
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
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
                    child: Column(children: const [
                      ShadIconBubble(icon: Icons.person_outline),
                      SizedBox(height: 12),
                      ShadCardTitle("Ma'lumotlaringiz"),
                      SizedBox(height: 4),
                      ShadCardDescription("Ism va parol qoldi"),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  ShadField(
                    label: "Ismingiz",
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(hintText: "Masalan: Shohruh"),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ShadField(
                    label: "Parol",
                    error: _error,
                    child: TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: "••••••",
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
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
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text("Ro'yxatdan o'tish"),
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
