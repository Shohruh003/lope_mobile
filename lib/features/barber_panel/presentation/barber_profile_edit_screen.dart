import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart' show BarberBookingActions, barberPanelRepositoryProvider;
import '../data/barber_profile_repository.dart';

/// Hub for barber-self profile edits. Top section shows the avatar tile +
/// bio/location editor, lower section is a list of links to the deeper
/// editors (services, working hours, gallery, reminders, public link).
class BarberProfileEditScreen extends ConsumerStatefulWidget {
  const BarberProfileEditScreen({super.key});

  @override
  ConsumerState<BarberProfileEditScreen> createState() => _BarberProfileEditScreenState();
}

class _BarberProfileEditScreenState extends ConsumerState<BarberProfileEditScreen> {
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  String? _seedKey;
  bool _saving = false;
  bool _uploadingAvatar = false;

  Future<void> _saveBio(String barberId) async {
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'bioUz': _bioController.text.trim(),
        'bio': _bioController.text.trim(),
        'locationUz': _locationController.text.trim(),
        'location': _locationController.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(String userId) async {
    final file = await ImagePickerService.instance.pickFromSheet(context);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(barberProfileRepositoryProvider).uploadAvatar(userId, file);
      // Refresh both the profile fetch and the auth-cached user.
      ref.invalidate(barberProfileProvider(userId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avatar yangilandi")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Avatarni yuklashda xato: $e")));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.profileEdit.title', "Profilni tahrirlash"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (b) {
          // One-time seed on data load (use id to detect first load only).
          if (_seedKey != b['id']) {
            _seedKey = b['id']?.toString();
            _bioController.text = (b['bioUz'] ?? b['bio'] ?? '').toString();
            _locationController.text = (b['locationUz'] ?? b['location'] ?? '').toString();
          }
          final avatarUrl = (b['avatar'] ?? '').toString();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Avatar section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? CachedNetworkImage(imageUrl: avatarUrl, width: 64, height: 64, fit: BoxFit.cover)
                              : Container(width: 64, height: 64, color: AppColors.background, child: const Icon(Icons.person, color: AppColors.textMuted)),
                        ),
                        if (_uploadingAvatar)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Colors.black45,
                              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((b['name'] ?? user.name).toString(),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(user.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _pickAvatar(user.id),
                      child: Text(tr(ref, 'mobile.common.edit', "O'zgartirish")),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Availability toggle — "Bugun ish yo'q" switch
              SwitchListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                value: b['isAvailable'] != false,
                activeThumbColor: AppColors.primary,
                onChanged: (_) async {
                  try {
                    await ref.read(barberPanelRepositoryProvider).toggleAvailability(user.id);
                    ref.invalidate(barberProfileProvider(user.id));
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                    }
                  }
                },
                title: const Text("Mijozlar qabul qilaman", style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  b['isAvailable'] != false
                      ? "Yangi bronlar tushishi mumkin"
                      : "Bron qabul qilmayapsiz — profil yashirin",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 18),

              Text(tr(ref, 'mobile.barber.profileEdit.bio', "Bio"),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                  controller: _bioController,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: tr(ref, 'mobile.barber.profileEdit.bioPlaceholder', "O'zingiz haqingizda"))),

              const SizedBox(height: 14),
              Text(tr(ref, 'mobile.barber.profileEdit.location', "Manzil"),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                  controller: _locationController,
                  decoration: InputDecoration(hintText: tr(ref, 'mobile.barber.profileEdit.locationPlaceholder', "Shahar, tuman"))),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _saveBio(user.id),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr(ref, 'mobile.barber.profileEdit.saveBio', "Bio'ni saqlash")),
                ),
              ),

              const SizedBox(height: 20),
              Text(tr(ref, 'mobile.barber.profileEdit.manage', "Boshqaruv"),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              _LinkTile(icon: Icons.people_outline, label: "Mijozlarim", onTap: () => context.push('/barber/clients')),
              _LinkTile(icon: Icons.content_cut, label: tr(ref, 'mobile.barber.profileEdit.linkServices', "Xizmatlarim"), onTap: () => context.push('/barber/services')),
              _LinkTile(icon: Icons.schedule, label: tr(ref, 'mobile.barber.profileEdit.linkHours', "Ish soatlari"), onTap: () => context.push('/barber/hours')),
              _LinkTile(icon: Icons.photo_library_outlined, label: tr(ref, 'mobile.barber.profileEdit.linkGallery', "Portfolio"), onTap: () => context.push('/barber/gallery')),
              _LinkTile(icon: Icons.notifications_active_outlined, label: tr(ref, 'mobile.barber.profileEdit.linkReminders', "Eslatma sozlamalari"), onTap: () => context.push('/barber/reminders')),
              _LinkTile(icon: Icons.sms_outlined, label: tr(ref, 'mobile.barber.profileEdit.linkSms', "SMS tarixi"), onTap: () => context.push('/barber/sms')),
              _LinkTile(icon: Icons.share, label: tr(ref, 'mobile.barber.profileEdit.linkPublic', "Ommaviy havola"), onTap: () => context.push('/barber/public-link')),
            ],
          );
        },
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
