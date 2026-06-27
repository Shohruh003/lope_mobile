import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart'
    show BarberBookingActions, barberPanelRepositoryProvider;
import '../data/barber_profile_repository.dart';

/// Mirrors `BarberProfileEditScreen.tsx` 1:1.
///
/// Structure:
///   - Sticky header (back + "Profilim" title)
///   - 4-tab pill switcher: Bio / Ish soatlari / Xizmatlar / Galereya
///   - Each tab opens the dedicated screen (services / hours / gallery) or
///     renders inline (bio).
class BarberProfileEditScreen extends ConsumerStatefulWidget {
  const BarberProfileEditScreen({super.key});
  @override
  ConsumerState<BarberProfileEditScreen> createState() => _BarberProfileEditScreenState();
}

class _BarberProfileEditScreenState extends ConsumerState<BarberProfileEditScreen> {
  int _tab = 0;
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _bioRuCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _locationRuCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  String _targetGender = 'ALL'; // 'ALL' | 'MALE' | 'FEMALE'
  String? _seedKey;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _bioRuCtrl.dispose();
    _locationCtrl.dispose();
    _locationRuCtrl.dispose();
    _experienceCtrl.dispose();
    _instagramCtrl.dispose();
    _telegramCtrl.dispose();
    _facebookCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBio(String barberId) async {
    setState(() => _saving = true);
    try {
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
        'name': _nameCtrl.text.trim(),
        'bioUz': _bioCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'bioRu': _bioRuCtrl.text.trim(),
        'locationUz': _locationCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'locationRu': _locationRuCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'targetGender': _targetGender,
        'instagram': _instagramCtrl.text.trim(),
        'telegram': _telegramCtrl.text.trim(),
        'facebook': _facebookCtrl.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar(String userId) async {
    final file = await ImagePickerService.instance.pickFromSheet(context, ref: ref);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref.read(barberProfileRepositoryProvider).uploadAvatar(userId, file);
      ref.invalidate(barberProfileProvider(userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(children: [
          // ===== Sticky header =====
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
              Text(tr(ref, 'profile.barberProfile', "Profilim"),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBright)),
            ]),
          ),

          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
              data: (b) {
                if (_seedKey != b['id']) {
                  _seedKey = b['id']?.toString();
                  _nameCtrl.text = (b['name'] ?? user.name).toString();
                  _bioCtrl.text = (b['bioUz'] ?? b['bio'] ?? '').toString();
                  _bioRuCtrl.text = (b['bioRu'] ?? '').toString();
                  _locationCtrl.text = (b['locationUz'] ?? b['location'] ?? '').toString();
                  _locationRuCtrl.text = (b['locationRu'] ?? '').toString();
                  _experienceCtrl.text = (b['experience'] ?? '').toString();
                  _targetGender = (b['targetGender'] ?? 'ALL').toString();
                  _instagramCtrl.text = (b['instagram'] ?? '').toString();
                  _telegramCtrl.text = (b['telegram'] ?? '').toString();
                  _facebookCtrl.text = (b['facebook'] ?? '').toString();
                }
                final avatarUrl = (b['avatar'] ?? '').toString();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    // ===== Avatar + name header =====
                    Center(
                      child: Stack(children: [
                        ClipOval(
                          child: avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: assetUrl(avatarUrl),
                                  width: 96, height: 96,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, err) => _Fallback(name: user.name),
                                )
                              : _Fallback(name: user.name),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: InkWell(
                            onTap: () => _pickAvatar(user.id),
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
                      child: Text((b['name'] ?? user.name).toString(),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textBright)),
                    ),
                    Center(
                      child: Text(user.phone,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),

                    const SizedBox(height: 16),

                    // ===== Availability switch =====
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SwitchListTile(
                        value: b['isAvailable'] != false,
                        activeThumbColor: AppColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onChanged: (_) async {
                          try {
                            await ref.read(barberPanelRepositoryProvider).toggleAvailability(user.id);
                            ref.invalidate(barberProfileProvider(user.id));
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
                            }
                          }
                        },
                        title: Text(tr(ref, 'mobile.barber.profileEdit.acceptClients', "Mijozlar qabul qilaman"),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textBright)),
                        subtitle: Text(
                          b['isAvailable'] != false
                              ? tr(ref, 'mobile.barber.profileEdit.availableHint', "Yangi bronlar tushishi mumkin")
                              : tr(ref, 'mobile.barber.profileEdit.unavailableHint', "Bron qabul qilmayapsiz — profil yashirin"),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== 4-tab pill switcher =====
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: List.generate(4, (i) {
                        final labels = [
                          tr(ref, 'mobile.barber.profileEdit.tabBio', "Bio"),
                          tr(ref, 'mobile.barber.profileEdit.tabHours', "Soatlar"),
                          tr(ref, 'mobile.barber.profileEdit.tabServices', "Xizmatlar"),
                          tr(ref, 'mobile.barber.profileEdit.tabGallery', "Galereya"),
                        ];
                        final on = i == _tab;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: on ? AppColors.background : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: on ? Border.all(color: AppColors.border) : null,
                              ),
                              child: Center(
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                    color: on ? AppColors.textBright : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })),
                    ),

                    const SizedBox(height: 14),

                    // ===== Tab content =====
                    if (_tab == 0) _bioTab(user.id),
                    if (_tab == 1) _navTile(
                      icon: Icons.schedule,
                      title: tr(ref, 'profile.workingHours', "Ish soatlari"),
                      subtitle: tr(ref, 'mobile.barber.profileEdit.hoursSub',
                          "Har kun uchun ish vaqtini sozlash"),
                      onTap: () => context.push('/barber/hours'),
                    ),
                    if (_tab == 2) _navTile(
                      icon: Icons.content_cut,
                      title: tr(ref, 'profile.services', "Xizmatlar"),
                      subtitle: tr(ref, 'mobile.barber.profileEdit.servicesSub',
                          "Narx va davomiyligi bilan xizmat ro'yxati"),
                      onTap: () => context.push('/barber/services'),
                    ),
                    if (_tab == 3) _navTile(
                      icon: Icons.photo_library_outlined,
                      title: tr(ref, 'mobile.barber.profileEdit.tabGallery', "Galereya"),
                      subtitle: tr(ref, 'mobile.barber.profileEdit.gallerySub',
                          "Ishlaringizdan rasmlar yuklash"),
                      onTap: () => context.push('/barber/gallery'),
                    ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _genderBtn(String value, String label) {
    final on = _targetGender == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _targetGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:
              on ? AppColors.primary.withValues(alpha: 0.12) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textMuted)),
      ),
    );
  }

  Widget _bioTab(String userId) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ShadLabel(tr(ref, 'profile.name', "Ism")),
      const SizedBox(height: 6),
      TextField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
      ),
      const SizedBox(height: 14),

      ShadLabel("${tr(ref, 'mobile.barber.profileEdit.bio', "Bio")} (UZ)"),
      const SizedBox(height: 6),
      TextField(
        controller: _bioCtrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
            hintText: tr(ref, 'mobile.barber.profileEdit.bioPlaceholder',
                "O'zingiz haqingizda qisqacha")),
      ),
      const SizedBox(height: 10),
      ShadLabel("${tr(ref, 'mobile.barber.profileEdit.bio', "Bio")} (RU)"),
      const SizedBox(height: 6),
      TextField(
        controller: _bioRuCtrl,
        maxLines: 4,
        style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBright,
            fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
            hintText: "Кратко о себе (для русскоязычных клиентов)"),
      ),
      const SizedBox(height: 14),

      ShadLabel(
          "${tr(ref, 'mobile.barber.profileEdit.location', "Manzil matni")} (UZ)"),
      const SizedBox(height: 6),
      TextField(
        controller: _locationCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
            hintText: tr(ref, 'mobile.barber.profileEdit.locationPlaceholder',
                "Toshkent, Yunusobod")),
      ),
      const SizedBox(height: 10),
      ShadLabel(
          "${tr(ref, 'mobile.barber.profileEdit.location', "Manzil matni")} (RU)"),
      const SizedBox(height: 6),
      TextField(
        controller: _locationRuCtrl,
        style: const TextStyle(
            fontSize: 14,
            color: AppColors.textBright,
            fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
            hintText: "Ташкент, Юнусабад"),
      ),
      const SizedBox(height: 14),

      // ===== Target gender =====
      ShadLabel(tr(ref, 'profile.targetGender', "Mijoz turi")),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: _genderBtn('ALL',
            "👥 ${tr(ref, 'profile.targetAll', 'Hammasi')}")),
        const SizedBox(width: 8),
        Expanded(child: _genderBtn('MALE',
            "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}")),
        const SizedBox(width: 8),
        Expanded(child: _genderBtn('FEMALE',
            "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}")),
      ]),
      const SizedBox(height: 14),

      // ===== Experience =====
      ShadLabel(tr(ref, 'profile.experience', "Tajriba")),
      const SizedBox(height: 6),
      TextField(
        controller: _experienceCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(hintText: '5, 8+, 10+'),
      ),
      const SizedBox(height: 14),

      // ===== Social links =====
      ShadLabel(tr(ref, 'profile.instagram', "Instagram")),
      const SizedBox(height: 6),
      TextField(
        controller: _instagramCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright),
        decoration: const InputDecoration(hintText: 'username'),
      ),
      const SizedBox(height: 10),
      ShadLabel(tr(ref, 'profile.telegram', "Telegram")),
      const SizedBox(height: 6),
      TextField(
        controller: _telegramCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright),
        decoration: const InputDecoration(hintText: 'username'),
      ),
      const SizedBox(height: 10),
      ShadLabel(tr(ref, 'profile.facebook', "Facebook")),
      const SizedBox(height: 6),
      TextField(
        controller: _facebookCtrl,
        style: const TextStyle(fontSize: 14, color: AppColors.textBright),
        decoration: const InputDecoration(hintText: 'username'),
      ),
      const SizedBox(height: 14),

      SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: _saving ? null : () => _saveBio(userId),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(tr(ref, 'mobile.barber.profileEdit.saveBio', "Bio'ni saqlash")),
        ),
      ),
    ]).animate().fadeIn(duration: 200.ms);
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ShadCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBright)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
        ]),
      ),
    ).animate().fadeIn(duration: 200.ms);
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
