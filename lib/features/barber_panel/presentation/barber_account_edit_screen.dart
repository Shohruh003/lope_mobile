import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// Account-level edits — login phone (read-only), password change. Different
/// from the profile editor which covers bio / services / gallery.
class BarberAccountEditScreen extends ConsumerStatefulWidget {
  const BarberAccountEditScreen({super.key});
  @override
  ConsumerState<BarberAccountEditScreen> createState() => _BarberAccountEditScreenState();
}

class _BarberAccountEditScreenState extends ConsumerState<BarberAccountEditScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_newCtrl.text.length < 4) {
      setState(() {
        _msg = "Yangi parol kamida 4 belgi bo'lishi kerak";
        _ok = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await ref.read(dioProvider).post('/auth/change-password', data: {
        'currentPassword': _currentCtrl.text,
        'newPassword': _newCtrl.text,
      });
      setState(() {
        _msg = "Parol yangilandi";
        _ok = true;
      });
      _currentCtrl.clear();
      _newCtrl.clear();
    } on DioException catch (e) {
      String msg = "Xato — qaytadan urinib ko'ring";
      if (e.response?.statusCode == 401) msg = "Joriy parol noto'g'ri";
      setState(() {
        _msg = msg;
        _ok = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("Akkaunt")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _Label("Telefon (o'zgartirilmaydi)"),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: user.phone),
            enabled: false,
          ),
          const SizedBox(height: 22),
          _Label("Joriy parol"),
          const SizedBox(height: 6),
          TextField(
            controller: _currentCtrl,
            obscureText: _obscureCurrent,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary),
                onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Label("Yangi parol"),
          const SizedBox(height: 6),
          TextField(
            controller: _newCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
          ),
          if (_msg != null) ...[
            const SizedBox(height: 14),
            Text(_msg!,
                style: TextStyle(color: _ok ? AppColors.success : AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _change,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Parolni yangilash"),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Widget _Label(String text) => Text(text,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600));
}
