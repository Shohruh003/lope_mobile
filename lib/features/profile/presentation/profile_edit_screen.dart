import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

/// Mirrors `CustomerProfileEditScreen.tsx` 1:1.
///   - Sticky header with back arrow + "Profilni tahrirlash"
///   - Centered avatar (96px) with camera button overlay → pick from gallery
///   - "Ism" card (name field)
///   - "Jins" card with 👨 Erkak / 👩 Ayol toggle buttons (2-col)
///   - "Parolni o'zgartirish" card with 3 password fields + eye toggles
///   - Bottom "Saqlash" button
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? _gender; // 'MALE' | 'FEMALE' | null
  File? _avatarFile;
  String? _avatarUrl;
  bool _seeded = false;
  bool _saving = false;
  bool _uploadingAvatar = false;

  bool _hideOld = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePickerService.instance.pickFromSheet(context, ref: ref);
    if (file == null) return;
    setState(() {
      _avatarFile = file;
    });
  }

  Future<void> _save(String userId) async {
    if (_newPassCtrl.text.isNotEmpty &&
        _newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.validation.passwordMismatch',
              "Yangi parol mos kelmadi"))));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);

      // 1) Upload avatar if changed. Backend FileInterceptor field name
      // is 'avatar' (users.controller.ts:79), not 'file' — old name made
      // every customer avatar upload 400.
      if (_avatarFile != null) {
        setState(() => _uploadingAvatar = true);
        final form = FormData.fromMap({
          'avatar': await MultipartFile.fromFile(_avatarFile!.path),
        });
        await dio.post('/users/$userId/avatar', data: form);
        setState(() => _uploadingAvatar = false);
      }

      // 2) Patch profile. PATCH /users/:id is admin-only — regular users
      // must hit /users/:id/profile (users.controller.ts:58), so the
      // previous endpoint returned 403 for non-admins and the customer
      // saw "Saqlanmadi" with no idea why.
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        if (_gender != null) 'gender': _gender,
        if (_oldPassCtrl.text.isNotEmpty && _newPassCtrl.text.isNotEmpty) ...{
          'oldPassword': _oldPassCtrl.text,
          'newPassword': _newPassCtrl.text,
        },
      };
      await dio.patch('/users/$userId/profile', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'profile.profileUpdated', "Profil yangilandi"))));
        context.pop();
      }
    } on DioException catch (e) {
      String msg = tr(ref, 'profile.saveFailed', "Saqlanmadi");
      if (e.response?.statusCode == 401) {
        msg = tr(ref, 'backend.oldPasswordWrong', "Eski parol noto'g'ri");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_seeded) {
      _seeded = true;
      _nameCtrl.text = user.name;
      _avatarUrl = user.avatar;
      // Seed gender from the cached user record so the matching pill is
      // pre-selected when the screen opens — was always null before.
      _gender = user.gender;
    }

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(children: [
          // ===== Sticky header =====
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
              Text(tr(ref, 'profile.editProfile', "Profilni tahrirlash"),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright)),
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // ===== Avatar =====
                Center(
                  child: Stack(children: [
                    ClipOval(
                      child: _avatarFile != null
                          ? Image.file(_avatarFile!, width: 96, height: 96, fit: BoxFit.cover)
                          : (_avatarUrl?.isNotEmpty == true
                              ? CachedNetworkImage(
                                  imageUrl: _avatarUrl!,
                                  width: 96, height: 96,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, err) => _Fallback(name: user.name),
                                )
                              : _Fallback(name: user.name)),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 32, height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: _uploadingAvatar
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(user.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textBright)),
                ),

                const SizedBox(height: 16),

                // ===== Name card =====
                ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ShadLabel(tr(ref, 'profile.name', "Ism")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                    ),
                  ]),
                ),

                const SizedBox(height: 10),

                // ===== Gender card =====
                ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(tr(ref, 'auth.gender', "Jins"),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textBright)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: _genderBtn('MALE',
                              "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}")),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _genderBtn('FEMALE',
                              "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}")),
                    ]),
                  ]),
                ),

                const SizedBox(height: 10),

                // ===== Password card =====
                ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(tr(ref, 'profile.changePassword', "Parolni o'zgartirish"),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 10),

                    _passField(tr(ref, 'profile.oldPassword', "Eski parol"),
                        _oldPassCtrl, _hideOld,
                        () => setState(() => _hideOld = !_hideOld)),
                    const SizedBox(height: 10),
                    _passField(tr(ref, 'profile.newPassword', "Yangi parol"),
                        _newPassCtrl, _hideNew,
                        () => setState(() => _hideNew = !_hideNew)),
                    const SizedBox(height: 10),
                    _passField(tr(ref, 'auth.verify', "Tasdiqlash"),
                        _confirmPassCtrl, _hideConfirm,
                        () => setState(() => _hideConfirm = !_hideConfirm)),
                  ]),
                ),

                const SizedBox(height: 14),

                // ===== Save =====
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(user.id),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(tr(ref, 'common.save', "Saqlash")),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _genderBtn(String key, String label) {
    final on = _gender == key;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _gender = on ? null : key;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: on ? AppColors.primary : Colors.transparent,
          border: Border.all(color: on ? AppColors.primary : AppColors.border, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: on ? Colors.white : AppColors.textMuted,
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _passField(String label, TextEditingController ctrl, bool hide, VoidCallback onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: hide,
          style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: "••••••",
            suffixIcon: IconButton(
              icon: Icon(
                  hide ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 18),
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
      width: 96, height: 96,
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: const TextStyle(
            color: AppColors.primary, fontSize: 36, fontWeight: FontWeight.w700),
      ),
    );
  }
}
