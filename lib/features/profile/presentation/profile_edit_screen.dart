import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _gender;
  File? _avatarFile;
  String? _avatarUrl;
  bool _seeded = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  // Snapshot of the seeded values so the Save button only lights up
  // when the user has actually changed something. Prior version would
  // POST /users/:id/profile on every tap even with no diff.
  String? _origName;
  String? _origGender;

  bool get _isDirty {
    if (_avatarFile != null) return true;
    if (_nameCtrl.text.trim() != (_origName ?? '')) return true;
    if ((_gender ?? '') != (_origGender ?? '')) return true;
    if (_oldPassCtrl.text.isNotEmpty || _newPassCtrl.text.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    AppHaptics.light();
    final file = await ImagePickerService.instance
        .pickFromSheet(context, ref: ref);
    if (!mounted || file == null) return;
    setState(() => _avatarFile = file);
  }

  Future<void> _save(String userId) async {
    AppHaptics.medium();
    if (_newPassCtrl.text.isNotEmpty &&
        _newPassCtrl.text != _confirmPassCtrl.text) {
      AppHaptics.error();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.validation.passwordMismatch',
              'Yangi parol mos kelmadi'))));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      if (_avatarFile != null) {
        setState(() => _uploadingAvatar = true);
        final form = FormData.fromMap({
          'avatar': await MultipartFile.fromFile(_avatarFile!.path),
        });
        await dio.post('/users/$userId/avatar', data: form);
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
      }
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (_oldPassCtrl.text.isNotEmpty &&
            _newPassCtrl.text.isNotEmpty) ...{
          'oldPassword': _oldPassCtrl.text,
          'newPassword': _newPassCtrl.text,
        },
      };
      await dio.patch('/users/$userId/profile', data: payload);
      await ref
          .read(authControllerProvider.notifier)
          .refreshFromServer();
      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(
                ref, 'profile.profileUpdated', 'Profil yangilandi'))));
        context.pop();
      }
    } on DioException catch (e) {
      AppHaptics.error();
      String msg = tr(ref, 'profile.saveFailed', 'Saqlanmadi');
      if (e.response?.statusCode == 401) {
        msg = tr(ref, 'backend.oldPasswordWrong',
            "Eski parol noto'g'ri");
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (!_seeded) {
      _seeded = true;
      _nameCtrl.text = user.name;
      _avatarUrl = user.avatar;
      _gender = user.gender;
      // Snapshot for the dirty check.
      _origName = user.name;
      _origGender = user.gender;
      // Rebuild whenever the name field changes so the Save button
      // toggles between enabled / disabled without a manual setState.
      _nameCtrl.addListener(() => setState(() {}));
      _oldPassCtrl.addListener(() => setState(() {}));
      _newPassCtrl.addListener(() => setState(() {}));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'profile.editProfile', 'Profilni tahrirlash'),
          style: AppText.titleMd,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
          children: [
            // Hero avatar with gradient ring
            Center(
              child: Stack(children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow:
                        AppShadows.primaryGlow(AppColors.primary),
                  ),
                  child: ClipOval(
                    child: _avatarFile != null
                        ? Image.file(_avatarFile!,
                            width: 112, height: 112, fit: BoxFit.cover)
                        : (_avatarUrl?.isNotEmpty == true
                            ? CachedNetworkImage(
                                imageUrl: assetUrl(_avatarUrl),
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    _Fallback(name: user.name),
                              )
                            : _Fallback(name: user.name)),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: TapScale(
                    onTap: _pickAvatar,
                    scale: 0.85,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.colors.background, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: _uploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              color: AppColors.primary, size: 18),
                    ),
                  ),
                ),
              ]),
            ),
            AppSpacing.gapMd,
            Center(child: Text(user.name, style: AppText.titleMd)),
            AppSpacing.gapXl,

            // Name card
            AppCard(
              variant: AppCardVariant.outlined,
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(ref, 'profile.name', 'Ism'),
                      style: AppText.overline),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: AppText.body,
                  ),
                ],
              ),
            ),

            AppSpacing.gapMd,

            // Phone number — read-only. Changing the phone requires
            // an OTP re-verification flow that lives on a separate
            // screen, so surface the current number here for clarity
            // (previously missing — users had no way to see their
            // registered phone from the edit screen).
            if (user.phone.isNotEmpty) ...[
              AppCard(
                variant: AppCardVariant.outlined,
                padding: AppSpacing.cardPadding,
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.rSm,
                    ),
                    child: const Icon(Icons.phone_outlined,
                        color: AppColors.primary, size: 18),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(ref, 'auth.phoneNumber', 'Telefon raqami'),
                            style: AppText.overline),
                        const SizedBox(height: 2),
                        Text(user.phone,
                            style: AppText.body
                                .copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_outline,
                      size: 16, color: context.colors.textMuted),
                ]),
              ),
              AppSpacing.gapMd,
            ],

            // Gender card
            AppCard(
              variant: AppCardVariant.outlined,
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr(ref, 'auth.gender', 'Jins'),
                      style: AppText.titleSm),
                  AppSpacing.gapMd,
                  Row(children: [
                    Expanded(
                      child: _genderBtn('MALE',
                          "рџ‘Ё ${tr(ref, 'auth.genderMale', 'Erkak')}"),
                    ),
                    AppSpacing.hGapSm,
                    Expanded(
                      child: _genderBtn('FEMALE',
                          "рџ‘© ${tr(ref, 'auth.genderFemale', 'Ayol')}"),
                    ),
                  ]),
                ],
              ),
            ),

            AppSpacing.gapMd,

            // Password card
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
                        color:
                            AppColors.warning.withValues(alpha: 0.15),
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
                  _passField(
                      tr(ref, 'profile.oldPassword', 'Eski parol'),
                      _oldPassCtrl,
                      _hideOld,
                      () => setState(() => _hideOld = !_hideOld)),
                  AppSpacing.gapSm,
                  _passField(
                      tr(ref, 'profile.newPassword', 'Yangi parol'),
                      _newPassCtrl,
                      _hideNew,
                      () => setState(() => _hideNew = !_hideNew)),
                  AppSpacing.gapSm,
                  _passField(
                      tr(ref, 'auth.verify', 'Tasdiqlash'),
                      _confirmPassCtrl,
                      _hideConfirm,
                      () => setState(
                          () => _hideConfirm = !_hideConfirm)),
                ],
              ),
            ),

            AppSpacing.gapXl,

            AppButton(
              label: _saving
                  ? tr(ref, 'common.loading', 'Yuklanmoqda...')
                  : tr(ref, 'common.save', 'Saqlash'),
              leadingIcon: Icons.check,
              variant: AppButtonVariant.primary,
              size: AppButtonSize.lg,
              fullWidth: true,
              loading: _saving,
              // Gate on _isDirty so we don't POST a no-op profile
              // update on every tap.
              onPressed: (_saving || !_isDirty)
                  ? null
                  : () => _save(user.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderBtn(String key, String label) {
    final on = _gender == key;
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        setState(() {
          _gender = on ? null : key;
        });
      },
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: on ? AppColors.primaryGradient : null,
          color: on ? null : context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: on ? AppColors.primary : context.colors.border,
            width: on ? 2 : 1,
          ),
          boxShadow:
              on ? AppShadows.primaryGlow(AppColors.primary) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.body.copyWith(
            color: on ? Colors.white : context.colors.textPrimary,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _passField(String label, TextEditingController ctrl, bool hide,
      VoidCallback onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.overline),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: hide,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: '••••••',
            suffixIcon: IconButton(
              icon: Icon(
                  hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: context.colors.textMuted,
                  size: 20),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      color: context.colors.surface,
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.display.copyWith(
          color: context.colors.textBright,
          fontSize: 40,
        ),
      ),
    );
  }
}
