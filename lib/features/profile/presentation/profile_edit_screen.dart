import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// Lightweight profile editor for the `user` role: name + avatar. Phone is
/// locked because it's the login key — changing it would require an OTP
/// re-verification flow we'll add separately.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameController = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String userId) async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/users/$userId', data: {'name': _nameController.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi")));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Saqlanmadi: ${e.response?.statusCode ?? ''} ${e.message ?? ''}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(String userId) async {
    final file = await ImagePickerService.instance.pickFromSheet(context);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final dio = ref.read(dioProvider);
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
      });
      final res = await dio.post('/users/$userId/avatar', data: form);
      if (res.data is Map && (res.data as Map)['avatar'] != null) {
        setState(() => _avatarUrl = (res.data as Map)['avatar'].toString());
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avatar yangilandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_seeded) {
      _seeded = true;
      _nameController.text = user.name;
      _avatarUrl = user.avatar;
    }
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.customer.profileEdit.title', "Profil"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Center(
            child: Stack(
              children: [
                ClipOval(
                  child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? CachedNetworkImage(imageUrl: _avatarUrl!, width: 100, height: 100, fit: BoxFit.cover)
                      : Container(
                          width: 100, height: 100, color: AppColors.surface,
                          child: const Icon(Icons.person, size: 48, color: AppColors.textMuted),
                        ),
                ),
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _pickAvatar(user.id),
              child: Text(tr(ref, 'mobile.customer.profileEdit.changeAvatar', "Avatarni o'zgartirish")),
            ),
          ),
          const SizedBox(height: 14),
          Text(tr(ref, 'mobile.auth.name', "Ism"),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: _nameController),
          const SizedBox(height: 14),
          Text(tr(ref, 'mobile.auth.phone', "Telefon"),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: user.phone),
            enabled: false,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _saveName(user.id),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(tr(ref, 'mobile.common.save', "Saqlash")),
            ),
          ),
        ],
      ),
    );
  }
}
