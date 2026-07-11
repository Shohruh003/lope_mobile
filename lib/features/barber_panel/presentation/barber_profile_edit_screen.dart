import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart'
    show BarberBookingActions, barberPanelRepositoryProvider;
import '../data/barber_profile_repository.dart';

class BarberProfileEditScreen extends ConsumerStatefulWidget {
  const BarberProfileEditScreen({super.key});
  @override
  ConsumerState<BarberProfileEditScreen> createState() =>
      _BarberProfileEditScreenState();
}

class _BarberProfileEditScreenState
    extends ConsumerState<BarberProfileEditScreen> {
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
  String _targetGender = 'ALL';
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
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      final newName = _nameCtrl.text.trim();
      if (newName.isNotEmpty) {
        await ref.read(authRepositoryProvider).updateMyName(barberId, newName);
        // ignore: unawaited_futures
        ref.read(authControllerProvider.notifier).refreshFromServer();
      }
      await ref.read(barberProfileRepositoryProvider).updateBarber(barberId, {
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
      AppHaptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
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

  Future<void> _pickAvatar(String userId) async {
    AppHaptics.light();
    final file =
        await ImagePickerService.instance.pickFromSheet(context, ref: ref);
    if (!mounted || file == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .uploadAvatar(userId, file);
      ref.invalidate(barberProfileProvider(userId));
      await ref.read(authControllerProvider.notifier).refreshFromServer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'profile.barberProfile', 'Profilim'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          final nestedUser = b['user'] is Map
              ? (b['user'] as Map).cast<String, dynamic>()
              : const <String, dynamic>{};
          if (_seedKey != b['id']) {
            _seedKey = b['id']?.toString();
            _nameCtrl.text =
                (b['name'] ?? nestedUser['name'] ?? user.name).toString();
            _bioCtrl.text = (b['bioUz'] ?? b['bio'] ?? '').toString();
            _bioRuCtrl.text = (b['bioRu'] ?? '').toString();
            _locationCtrl.text =
                (b['locationUz'] ?? b['location'] ?? '').toString();
            _locationRuCtrl.text = (b['locationRu'] ?? '').toString();
            _experienceCtrl.text = (b['experience'] ?? '').toString();
            _targetGender = (b['targetGender'] ?? 'ALL').toString();
            _instagramCtrl.text = (b['instagram'] ?? '').toString();
            _telegramCtrl.text = (b['telegram'] ?? '').toString();
            _facebookCtrl.text = (b['facebook'] ?? '').toString();
          }
          final avatarUrl =
              (b['avatar'] ?? nestedUser['avatar'] ?? '').toString();
          final isAvailable = b['isAvailable'] != false;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.primaryGlow(AppColors.primary),
                    ),
                    child: ClipOval(
                      child: avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: assetUrl(avatarUrl),
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  _Fallback(name: user.name),
                            )
                          : _Fallback(name: user.name),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: TapScale(
                      onTap: () => _pickAvatar(user.id),
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
                                    color: AppColors.primary),
                              )
                            : const Icon(Icons.camera_alt,
                                color: AppColors.primary, size: 18),
                      ),
                    ),
                  ),
                ]),
              ),
              AppSpacing.gapMd,
              Center(
                child: Text(
                  (b['name'] ?? nestedUser['name'] ?? user.name).toString(),
                  style: AppText.titleMd,
                ),
              ),
              Center(child: Text(user.phone, style: AppText.bodySm)),
              AppSpacing.gapLg,
              AppCard(
                variant: AppCardVariant.outlined,
                padding: AppSpacing.cardPadding,
                color: isAvailable
                    ? AppColors.success.withValues(alpha: 0.06)
                    : null,
                borderColor: isAvailable
                    ? AppColors.success.withValues(alpha: 0.3)
                    : null,
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isAvailable
                              ? AppColors.success
                              : context.colors.textMuted)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAvailable
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isAvailable
                          ? AppColors.success
                          : context.colors.textMuted,
                      size: 20,
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                              ref,
                              'mobile.barber.profileEdit.acceptClients',
                              'Mijozlar qabul qilaman'),
                          style: AppText.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAvailable
                              ? tr(
                                  ref,
                                  'mobile.barber.profileEdit.availableHint',
                                  'Yangi bronlar tushishi mumkin')
                              : tr(
                                  ref,
                                  'mobile.barber.profileEdit.unavailableHint',
                                  "Bron qabul qilmayapsiz — profil yashirin"),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isAvailable,
                    activeThumbColor: AppColors.success,
                    onChanged: (_) async {
                      AppHaptics.selection();
                      try {
                        await ref
                            .read(barberPanelRepositoryProvider)
                            .toggleAvailability(user.id);
                        ref.invalidate(barberProfileProvider(user.id));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
                        }
                      }
                    },
                  ),
                ]),
              ),
              AppSpacing.gapLg,
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: AppRadius.rMd,
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(children: List.generate(4, (i) {
                  final labels = [
                    tr(ref, 'mobile.barber.profileEdit.tabBio', 'Bio'),
                    tr(ref, 'mobile.barber.profileEdit.tabHours',
                        'Soatlar'),
                    tr(ref, 'mobile.barber.profileEdit.tabServices',
                        'Xizmatlar'),
                    tr(ref, 'mobile.barber.profileEdit.tabGallery',
                        'Galereya'),
                  ];
                  final on = i == _tab;
                  return Expanded(
                    child: TapScale(
                      onTap: () => setState(() => _tab = i),
                      haptic: HapticStrength.selection,
                      scale: 0.97,
                      child: AnimatedContainer(
                        duration: AppMotion.base,
                        curve: AppMotion.emphasized,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color:
                              on ? context.colors.background : Colors.transparent,
                          borderRadius: AppRadius.rSm,
                          border: on
                              ? Border.all(color: context.colors.border)
                              : null,
                          boxShadow: on ? AppShadows.subtle : null,
                        ),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: AppText.caption.copyWith(
                              fontSize: 12,
                              fontWeight: on
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: on
                                  ? context.colors.textBright
                                  : context.colors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                })),
              ),
              AppSpacing.gapLg,
              if (_tab == 0) _bioTab(user.id),
              if (_tab == 1)
                _navTile(
                  icon: Icons.schedule,
                  title:
                      tr(ref, 'profile.workingHours', 'Ish soatlari'),
                  subtitle: tr(ref,
                      'mobile.barber.profileEdit.hoursSub',
                      'Har kun uchun ish vaqtini sozlash'),
                  onTap: () => context.push('/barber/hours'),
                ),
              if (_tab == 2)
                _navTile(
                  icon: Icons.content_cut,
                  title: tr(ref, 'profile.services', 'Xizmatlar'),
                  subtitle: tr(ref,
                      'mobile.barber.profileEdit.servicesSub',
                      "Narx va davomiyligi bilan xizmat ro'yxati"),
                  onTap: () => context.push('/barber/services'),
                ),
              if (_tab == 3)
                _navTile(
                  icon: Icons.photo_library_outlined,
                  title: tr(ref,
                      'mobile.barber.profileEdit.tabGallery',
                      'Galereya'),
                  subtitle: tr(ref,
                      'mobile.barber.profileEdit.gallerySub',
                      'Ishlaringizdan rasmlar yuklash'),
                  onTap: () => context.push('/barber/gallery'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _genderBtn(String value, String label) {
    final on = _targetGender == value;
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        setState(() => _targetGender = value);
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
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(
            color: on ? Colors.white : context.colors.textPrimary,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _bioTab(String userId) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lbl(tr(ref, 'profile.name', 'Ism')),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: AppText.body,
          ),
          AppSpacing.gapMd,
          _lbl("${tr(ref, 'mobile.barber.profileEdit.bio', 'Bio')} (UZ)"),
          const SizedBox(height: 6),
          TextField(
            controller: _bioCtrl,
            maxLines: 4,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: tr(ref, 'mobile.barber.profileEdit.bioPlaceholder',
                  "O'zingiz haqingizda qisqacha"),
            ),
          ),
          AppSpacing.gapSm,
          _lbl("${tr(ref, 'mobile.barber.profileEdit.bio', 'Bio')} (RU)"),
          const SizedBox(height: 6),
          TextField(
            controller: _bioRuCtrl,
            maxLines: 4,
            style: AppText.body,
            decoration: const InputDecoration(
                hintText: 'Кратко о себе (для русскоязычных клиентов)'),
          ),
          AppSpacing.gapMd,
          _lbl(
              "${tr(ref, 'mobile.barber.profileEdit.location', 'Manzil matni')} (UZ)"),
          const SizedBox(height: 6),
          TextField(
            controller: _locationCtrl,
            style: AppText.body,
            decoration: InputDecoration(
              hintText: tr(ref,
                  'mobile.barber.profileEdit.locationPlaceholder',
                  'Toshkent, Yunusobod'),
            ),
          ),
          AppSpacing.gapSm,
          _lbl(
              "${tr(ref, 'mobile.barber.profileEdit.location', 'Manzil matni')} (RU)"),
          const SizedBox(height: 6),
          TextField(
            controller: _locationRuCtrl,
            style: AppText.body,
            decoration:
                const InputDecoration(hintText: 'Ташкент, Юнусабад'),
          ),
          AppSpacing.gapMd,
          _lbl(tr(ref, 'profile.targetGender', 'Mijoz turi')),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _genderBtn(
                    'ALL',
                    "👥 ${tr(ref, 'profile.targetAll', 'Hammasi')}")),
            AppSpacing.hGapSm,
            Expanded(
                child: _genderBtn(
                    'MALE',
                    "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}")),
            AppSpacing.hGapSm,
            Expanded(
                child: _genderBtn(
                    'FEMALE',
                    "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}")),
          ]),
          AppSpacing.gapMd,
          _lbl(tr(ref, 'profile.experience', 'Tajriba')),
          const SizedBox(height: 6),
          TextField(
            controller: _experienceCtrl,
            style: AppText.body,
            decoration: const InputDecoration(hintText: '5, 8+, 10+'),
          ),
          AppSpacing.gapMd,
          _lbl(tr(ref, 'profile.instagram', 'Instagram')),
          const SizedBox(height: 6),
          TextField(
            controller: _instagramCtrl,
            style: AppText.body,
            decoration: const InputDecoration(hintText: 'username'),
          ),
          AppSpacing.gapSm,
          _lbl(tr(ref, 'profile.telegram', 'Telegram')),
          const SizedBox(height: 6),
          TextField(
            controller: _telegramCtrl,
            style: AppText.body,
            decoration: const InputDecoration(hintText: 'username'),
          ),
          AppSpacing.gapSm,
          _lbl(tr(ref, 'profile.facebook', 'Facebook')),
          const SizedBox(height: 6),
          TextField(
            controller: _facebookCtrl,
            style: AppText.body,
            decoration: const InputDecoration(hintText: 'username'),
          ),
          AppSpacing.gapLg,
          AppButton(
            label:
                tr(ref, 'mobile.barber.profileEdit.saveBio', "Bio'ni saqlash"),
            leadingIcon: Icons.check,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.lg,
            fullWidth: true,
            loading: _saving,
            onPressed: _saving ? null : () => _saveBio(userId),
          ),
        ]).animate().fadeIn(duration: 200.ms);
  }

  Widget _lbl(String text) => Text(text, style: AppText.overline);

  Widget _navTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: AppRadius.rMd,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleSm),
              const SizedBox(height: 2),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
        Icon(Icons.chevron_right,
            color: context.colors.textMuted, size: 18),
      ]),
    ).animate().fadeIn(duration: 200.ms);
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
