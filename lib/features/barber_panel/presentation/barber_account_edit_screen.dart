import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';

class BarberAccountEditScreen extends ConsumerStatefulWidget {
  const BarberAccountEditScreen({super.key});
  @override
  ConsumerState<BarberAccountEditScreen> createState() =>
      _BarberAccountEditScreenState();
}

class _BarberAccountEditScreenState
    extends ConsumerState<BarberAccountEditScreen> {
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
    AppHaptics.medium();
    if (_newCtrl.text.length < 4) {
      AppHaptics.error();
      setState(() {
        _msg = tr(ref, 'auth.shortPassword', 'Parol kamida 4 belgi');
        _ok = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    try {
      await ref.read(dioProvider).patch(
        '/users/${user.id}/profile',
        data: {
          'oldPassword': _currentCtrl.text,
          'newPassword': _newCtrl.text,
        },
      );
      if (!mounted) return;
      AppHaptics.success();
      setState(() {
        _msg = tr(ref, 'auth.passwordUpdated', 'Parol yangilandi');
        _ok = true;
      });
      _currentCtrl.clear();
      _newCtrl.clear();
    } on DioException catch (e) {
      AppHaptics.error();
      if (!mounted) return;
      String msg = tr(ref, 'common.errorRetry',
          "Xatolik — qaytadan urinib ko'ring");
      if (e.response?.statusCode == 401) {
        msg = tr(ref, 'backend.oldPasswordWrong',
            "Joriy parol noto'g'ri");
      }
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
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'barberApp.accountSettings', 'Akkaunt sozlamalari'),
          style: AppText.titleMd,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(ref, 'mobile.barber.account.phoneReadOnly',
                      "Telefon (o'zgartirilmaydi)"),
                  style: AppText.overline,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: TextEditingController(text: user.phone),
                  enabled: false,
                  style: AppText.body,
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: AppRadius.rSm,
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: AppColors.warning, size: 18),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      tr(ref, 'profile.changePassword',
                          "Parolni o'zgartirish"),
                      style: AppText.titleSm,
                    ),
                  ),
                ]),
                AppSpacing.gapMd,
                Text(
                  tr(ref, 'mobile.barber.account.currentPassword',
                      'Joriy parol'),
                  style: AppText.overline,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _currentCtrl,
                  obscureText: _obscureCurrent,
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                          size: 20),
                      onPressed: () => setState(
                          () => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                Text(
                  tr(ref, 'profile.newPassword', 'Yangi parol'),
                  style: AppText.overline,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _newCtrl,
                  obscureText: _obscureNew,
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: '••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                ),
                if (_msg != null) ...[
                  AppSpacing.gapMd,
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: (_ok ? AppColors.success : AppColors.danger)
                          .withValues(alpha: 0.1),
                      borderRadius: AppRadius.rSm,
                      border: Border.all(
                        color:
                            (_ok ? AppColors.success : AppColors.danger)
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                          _ok
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: _ok
                              ? AppColors.success
                              : AppColors.danger,
                          size: 16),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          _msg!,
                          style: AppText.bodySm.copyWith(
                            color: _ok
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.gapXl,
          AppButton(
            label: tr(ref, 'auth.updatePassword', 'Parolni yangilash'),
            leadingIcon: Icons.check,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.lg,
            fullWidth: true,
            loading: _busy,
            onPressed: _busy ? null : _change,
          ),
        ],
      ),
    );
  }
}
