import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';
import '../../lopepay/presentation/top_up_modal.dart';
import '../data/ai_style_repository.dart';

/// Redesigned AI Stil screen. 3 qadamli aniq oqim — foydalanuvchi har qadamda
/// nima qilishini biladi. Ilgari "Namuna" tugmasi 72x28 kichik dashed border
/// bo'lgani sabab ko'pchilik reference rasm yuklash mumkinligini bilmayapti
/// edi — endi u alohida qadam sifatida ko'rinadi.
///
///   Qadam 1  — kim uchun (jins) + qaysi qismni o'zgartirmoqchi (Soch/Soqol)
///   Qadam 2  — selfi yuklash (asosiy rasm)
///   Qadam 3  — namuna qo'shish (ixtiyoriy) — reference image per style
///
/// Generatsiya tugmasi ekranning pastki qismida sticky bo'lib turadi.
class AiStyleScreen extends ConsumerStatefulWidget {
  const AiStyleScreen({super.key});

  @override
  ConsumerState<AiStyleScreen> createState() => _AiStyleScreenState();
}

class _AiStyleScreenState extends ConsumerState<AiStyleScreen> {
  // Web's MALE_STYLE_KEYS / FEMALE_STYLE_KEYS
  static const _maleOptions = [
    _StyleOpt('hair', 'Soch', '💇‍♂️'),
    _StyleOpt('beard', 'Soqol', '🧔'),
  ];
  static const _femaleOptions = [
    _StyleOpt('hair', 'Soch', '💇‍♀️'),
    _StyleOpt('hair_color', 'Soch rangi', '🎨'),
    _StyleOpt('eyebrows', 'Qoshlar', '✏️'),
    _StyleOpt('lips', 'Labbo', '💋'),
    _StyleOpt('eyelashes', 'Kiprik', '👁️'),
  ];

  String _gender = 'male';
  final Set<String> _selectedStyles = {'hair'};
  File? _selfie;
  final Map<String, File> _refImages = {};
  bool _busy = false;
  String? _resultUrl;
  String? _error;

  List<_StyleOpt> get _options =>
      _gender == 'female' ? _femaleOptions : _maleOptions;

  Future<void> _pickSelfie() async {
    AppHaptics.light();
    final f = await ImagePickerService.instance.pickFromSheet(context, ref: ref);
    if (!mounted || f == null) return;
    setState(() => _selfie = f);
  }

  Future<void> _pickRef(String key) async {
    AppHaptics.light();
    final f = await ImagePickerService.instance
        .pickFromSheet(context, allowCamera: false, ref: ref);
    if (!mounted || f == null) return;
    setState(() => _refImages[key] = f);
  }

  Future<void> _generate() async {
    AppHaptics.medium();
    if (_selfie == null) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'mobile.aiStyle.selfieMissing',
          "Avval o'zingizning rasmingizni yuklang"));
      return;
    }
    if (_selectedStyles.isEmpty) {
      AppHaptics.error();
      setState(() => _error = tr(ref, 'mobile.aiStyle.errorPickStyle',
          "Kamida bitta stil tanlang"));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _resultUrl = null;
    });
    try {
      final r = await ref.read(aiStyleRepositoryProvider).generate(
            selfie: _selfie!,
            gender: _gender,
            styles: _selectedStyles.toList(),
            references: Map<String, File>.from(_refImages),
          );
      if (!mounted) return;
      AppHaptics.success();
      setState(() => _resultUrl = r.imageUrl);
      final user = ref.read(authControllerProvider).user;
      if (user != null) ref.invalidate(myBalanceProvider(user.id));
    } on Object catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      String msg = tr(ref, 'mobile.aiStyle.errorGeneric',
          "Generatsiya bajarilmadi");
      final s = e.toString();
      final isBalance = s.contains('402') ||
          s.contains('balance') ||
          s.contains('yetarli');
      if (isBalance) {
        msg = tr(ref, 'mobile.aiStyle.errorBalance',
            "Balansingiz yetarli emas. Hisobni to'ldiring.");
      }
      if (s.contains('SocketException')) {
        msg = tr(ref, 'mobile.aiStyle.errorInternet', "Internet bilan muammo");
      }
      setState(() => _error = msg);
      if (isBalance && mounted) {
        await TopUpModal.show(context);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    AppHaptics.light();
    setState(() {
      _selfie = null;
      _resultUrl = null;
      _refImages.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final balance = user == null ? null : ref.watch(myBalanceProvider(user.id));
    final hasResult = _resultUrl != null && _resultUrl!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                if (user != null) ref.invalidate(myBalanceProvider(user.id));
                setState(() {
                  _error = null;
                  _resultUrl = null;
                });
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  hasResult ? AppSpacing.xxl : 96, // pastda sticky tugma joyi
                ),
                children: [
                  // ===== Header: title + balance pill =====
                  _HeaderBlock(balance: balance),

                  AppSpacing.gapXl,

                  // ===== Result view (result mavjud bo'lsa faqat shu) =====
                  if (hasResult) ...[
                    _ResultView(
                      original: _selfie,
                      resultUrl: _resultUrl!,
                      onReset: _reset,
                    ),
                  ] else if (_busy) ...[
                    _LoadingView(),
                  ] else ...[
                    // ===== Qadam 1: jins + soha =====
                    _StepHeader(
                      number: 1,
                      title: tr(ref, 'mobile.aiStyle.step1',
                          "Nimani o'zgartirmoqchisiz?"),
                    ),
                    AppSpacing.gapMd,
                    _GenderRow(
                      gender: _gender,
                      onChange: (g) => setState(() {
                        _gender = g;
                        _selectedStyles
                          ..clear()
                          ..add('hair');
                        _refImages.clear();
                      }),
                    ),
                    AppSpacing.gapMd,
                    _StyleCategoryRow(
                      options: _options,
                      selected: _selectedStyles,
                      onToggle: (k) => setState(() {
                        if (_selectedStyles.contains(k)) {
                          _selectedStyles.remove(k);
                          _refImages.remove(k);
                        } else {
                          _selectedStyles.add(k);
                        }
                      }),
                    ),

                    AppSpacing.gapXxl,

                    // ===== Qadam 2: selfi =====
                    _StepHeader(
                      number: 2,
                      title: tr(ref, 'mobile.aiStyle.step2',
                          "Selfingizni yuklang"),
                      subtitle: tr(ref, 'mobile.aiStyle.step2Hint',
                          "Yuz aniq ko'rinadigan yorug' rasm eng yaxshi natija beradi"),
                    ),
                    AppSpacing.gapMd,
                    _SelfieBlock(
                      file: _selfie,
                      onPick: _pickSelfie,
                      onRemove: () => setState(() => _selfie = null),
                    ),

                    AppSpacing.gapXxl,

                    // ===== Qadam 3: namuna (asosiy UX ta'mirlash) =====
                    _StepHeader(
                      number: 3,
                      title: tr(ref, 'mobile.aiStyle.step3',
                          "Namuna qo'shing (ixtiyoriy)"),
                      subtitle: tr(ref, 'mobile.aiStyle.step3Hint',
                          "Yoqtirgan soch turmagi rasmini yuklasangiz — natija 3x aniqroq bo'ladi"),
                    ),
                    AppSpacing.gapMd,
                    _ReferenceBlock(
                      options: _options,
                      selected: _selectedStyles,
                      refs: _refImages,
                      onPick: _pickRef,
                      onRemove: (k) => setState(() => _refImages.remove(k)),
                    ),

                    if (_error != null) ...[
                      AppSpacing.gapLg,
                      _ErrorBanner(message: _error!),
                    ],
                  ],
                ],
              ),
            ),

            // ===== Sticky generate button — pastki qismda doim ko'rinadi =====
            if (!hasResult && !_busy)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StickyGenerateBar(
                  enabled: _selfie != null && _selectedStyles.isNotEmpty,
                  onTap: _generate,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header — title + balance pill
// ─────────────────────────────────────────────────────────────────────────
class _HeaderBlock extends ConsumerWidget {
  const _HeaderBlock({required this.balance});
  final AsyncValue<dynamic>? balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: AppRadius.rMd,
                boxShadow: AppShadows.primaryGlow(AppColors.primary),
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 22),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(ref, 'aiStyle.title', 'AI Stil'),
                      style: AppText.titleLg),
                  Text(
                    tr(ref, 'mobile.aiStyle.subtitle',
                        "Sun'iy intellekt yordamida"),
                    style: AppText.bodySm,
                  ),
                ],
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        balance == null
            ? _BalancePill(text: tr(ref, 'aiStyle.perGen', 'Har generatsiya 1000 so\'m'))
            : balance!.when(
                loading: () => const SkeletonLine(width: 200, height: 28),
                error: (e, _) => const SizedBox.shrink(),
                data: (b) {
                  final free = (b.aiFreeRemaining as int?) ?? 0;
                  final text = free > 0
                      ? tr(
                          ref,
                          'aiStyle.todayFree',
                          "Bugun {{count}} ta bepul · keyingisi 1000 so'm",
                          {'count': '$free'},
                        )
                      : tr(ref, 'aiStyle.perGen', 'Har generatsiya 1000 so\'m');
                  return _BalancePill(text: text, hasFree: free > 0);
                },
              ),
      ],
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.text, this.hasFree = false});
  final String text;
  final bool hasFree;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (hasFree ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.1),
        borderRadius: AppRadius.rPill,
        border: Border.all(
          color: (hasFree ? AppColors.success : AppColors.primary)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFree ? Icons.card_giftcard : Icons.info_outline,
            size: 14,
            color: hasFree ? AppColors.success : AppColors.primary,
          ),
          AppSpacing.hGapXs,
          Flexible(
            child: Text(
              text,
              style: AppText.caption.copyWith(
                color: hasFree ? AppColors.success : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step header — number badge + title + optional subtitle
// ─────────────────────────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.number,
    required this.title,
    this.subtitle,
  });
  final int number;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.rSm,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: AppText.button.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(child: Text(title, style: AppText.titleSm)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(subtitle!, style: AppText.bodySm),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 1 — gender picker
// ─────────────────────────────────────────────────────────────────────────
class _GenderRow extends ConsumerWidget {
  const _GenderRow({required this.gender, required this.onChange});
  final String gender;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(children: [
      Expanded(
        child: AppCard(
          variant: AppCardVariant.outlined,
          color: gender == 'male'
              ? AppColors.primary.withValues(alpha: 0.12)
              : null,
          borderColor: gender == 'male' ? AppColors.primary : null,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          onTap: () => onChange('male'),
          child: _GenderInner(
            emoji: '👨',
            label: tr(ref, 'auth.genderMale', 'Erkak'),
            selected: gender == 'male',
          ),
        ),
      ),
      AppSpacing.hGapSm,
      Expanded(
        child: AppCard(
          variant: AppCardVariant.outlined,
          color: gender == 'female'
              ? AppColors.primary.withValues(alpha: 0.12)
              : null,
          borderColor: gender == 'female' ? AppColors.primary : null,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          onTap: () => onChange('female'),
          child: _GenderInner(
            emoji: '👩',
            label: tr(ref, 'auth.genderFemale', 'Ayol'),
            selected: gender == 'female',
          ),
        ),
      ),
    ]);
  }
}

class _GenderInner extends StatelessWidget {
  const _GenderInner({
    required this.emoji,
    required this.label,
    required this.selected,
  });
  final String emoji;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        AppSpacing.hGapSm,
        Text(
          label,
          style: AppText.body.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 1 — style category chips (Soch / Soqol / Soch rangi / ...)
// ─────────────────────────────────────────────────────────────────────────
class _StyleCategoryRow extends ConsumerWidget {
  const _StyleCategoryRow({
    required this.options,
    required this.selected,
    required this.onToggle,
  });
  final List<_StyleOpt> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => AppSpacing.hGapSm,
        itemBuilder: (context, i) {
          final opt = options[i];
          final on = selected.contains(opt.key);
          return _StyleCategoryCard(
            emoji: opt.icon,
            label: tr(ref, 'mobile.aiStyle.styles.${opt.key}', opt.label),
            selected: on,
            onTap: () => onToggle(opt.key),
          );
        },
      ),
    );
  }
}

class _StyleCategoryCard extends StatelessWidget {
  const _StyleCategoryCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        width: 88,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.primaryGlow(AppColors.primary),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 2 — selfie upload
// ─────────────────────────────────────────────────────────────────────────
class _SelfieBlock extends ConsumerWidget {
  const _SelfieBlock({
    required this.file,
    required this.onPick,
    required this.onRemove,
  });
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (file == null) {
      return TapScale(
        onTap: onPick,
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.rXl,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    color: AppColors.primary, size: 30),
              ),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'aiStyle.uploadPhoto', "Rasmingizni yuklang"),
                style: AppText.titleSm.copyWith(color: AppColors.textBright),
              ),
              const SizedBox(height: 4),
              Text(
                tr(ref, 'mobile.aiStyle.uploadHint2',
                    "Kameradan yoki galereyadan tanlash"),
                style: AppText.bodySm,
              ),
            ],
          ),
        ),
      );
    }
    // Selfi tanlangan
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadius.rXl,
          child: Image.file(
            file!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 280,
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: TapScale(
            onTap: onRemove,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ),
        Positioned(
          left: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: AppRadius.rPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    size: 14, color: AppColors.success),
                AppSpacing.hGapXs,
                Text(
                  tr(ref, 'mobile.aiStyle.selfieReady', 'Rasm tayyor'),
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Step 3 — reference images (the key UX fix)
// ─────────────────────────────────────────────────────────────────────────
class _ReferenceBlock extends ConsumerWidget {
  const _ReferenceBlock({
    required this.options,
    required this.selected,
    required this.refs,
    required this.onPick,
    required this.onRemove,
  });
  final List<_StyleOpt> options;
  final Set<String> selected;
  final Map<String, File> refs;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = options.where((o) => selected.contains(o.key)).toList();
    if (active.isEmpty) {
      return AppCard(
        variant: AppCardVariant.outlined,
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                color: AppColors.textMuted, size: 18),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                tr(ref, 'mobile.aiStyle.pickCategoryFirst',
                    "Avval yuqoridan qismni tanlang"),
                style: AppText.bodySm,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadius.rSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tips_and_updates,
                        size: 12, color: AppColors.warning),
                    AppSpacing.hGapXs,
                    Text(
                      tr(ref, 'mobile.aiStyle.proTip', 'Maslahat'),
                      style: AppText.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          Text(
            tr(ref, 'mobile.aiStyle.refTip',
                "Yoqtirgan namunani yuklang — AI shu uslubga taqlid qiladi"),
            style: AppText.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          AppSpacing.gapMd,
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: active.length,
              separatorBuilder: (_, _) => AppSpacing.hGapMd,
              itemBuilder: (context, i) {
                final opt = active[i];
                final img = refs[opt.key];
                return _RefTile(
                  emoji: opt.icon,
                  label: tr(ref, 'mobile.aiStyle.styles.${opt.key}', opt.label),
                  file: img,
                  onPick: () => onPick(opt.key),
                  onRemove: () => onRemove(opt.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RefTile extends StatelessWidget {
  const _RefTile({
    required this.emoji,
    required this.label,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });
  final String emoji;
  final String label;
  final File? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return SizedBox(
        width: 92,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: AppRadius.rMd,
              child: Image.file(
                file!,
                width: 92,
                height: 92,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: TapScale(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.md),
                    bottomRight: Radius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  '$emoji $label',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: 92,
      child: TapScale(
        onTap: onPick,
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              const Icon(Icons.add_photo_alternate_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption
                      .copyWith(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sticky generate CTA
// ─────────────────────────────────────────────────────────────────────────
class _StickyGenerateBar extends ConsumerWidget {
  const _StickyGenerateBar({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.elevated,
      ),
      child: SafeArea(
        top: false,
        child: AppButton(
          label: tr(ref, 'aiStyle.generate', 'Yaratish'),
          onPressed: enabled ? onTap : null,
          leadingIcon: Icons.auto_awesome,
          size: AppButtonSize.lg,
          fullWidth: true,
          hapticStrength: HapticStrength.medium,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Loading + Result + Error banner
// ─────────────────────────────────────────────────────────────────────────
class _LoadingView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.35))),
              ),
              const Icon(Icons.auto_awesome,
                  size: 32, color: AppColors.primary),
            ],
          ),
          AppSpacing.gapLg,
          Text(
            tr(ref, 'aiStyle.generating',
                "Sizning yangi stilingiz tayyorlanmoqda..."),
            style: AppText.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            tr(ref, 'mobile.aiStyle.generatingHint',
                "Bu 10-30 soniya oladi"),
            style: AppText.caption,
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).fade(
        begin: 0.7, end: 1, duration: 1200.ms);
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.original,
    required this.resultUrl,
    required this.onReset,
  });
  final File? original;
  final String resultUrl;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(ref, 'aiStyle.original', 'Asl'), style: AppText.overline),
            AppSpacing.gapSm,
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: AppRadius.rLg,
                child: original != null
                    ? Image.file(original!, fit: BoxFit.cover)
                    : Container(color: AppColors.surfaceElevated),
              ),
            ),
          ]),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(tr(ref, 'aiStyle.result', 'Natija'), style: AppText.overline),
              AppSpacing.hGapXs,
              const Icon(Icons.auto_awesome,
                  size: 12, color: AppColors.primary),
            ]),
            AppSpacing.gapSm,
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: AppRadius.rLg,
                child: CachedNetworkImage(
                  imageUrl: resultUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, _) =>
                      const SkeletonRect(radius: AppRadius.lg),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.surfaceElevated,
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.broken_image, color: AppColors.danger),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
      AppSpacing.gapLg,
      Row(children: [
        Expanded(
          child: AppButton(
            label: tr(ref, 'aiStyle.download', 'Yuklab olish'),
            leadingIcon: Icons.download,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.md,
            fullWidth: true,
            onPressed: () async {
              final uri = Uri.tryParse(resultUrl);
              if (uri == null) return;
              if (uri.scheme != 'http' && uri.scheme != 'https') return;
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: AppButton(
            label: tr(ref, 'aiStyle.tryAgain', 'Qaytadan'),
            leadingIcon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.md,
            fullWidth: true,
            onPressed: onReset,
          ),
        ),
      ]),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            message,
            style: AppText.bodySm.copyWith(color: AppColors.danger),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _StyleOpt {
  const _StyleOpt(this.key, this.label, this.icon);
  final String key;
  final String label;
  final String icon;
}
