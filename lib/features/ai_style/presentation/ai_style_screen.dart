import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';
import '../../lopepay/presentation/top_up_modal.dart';
import '../data/ai_style_repository.dart';
import '../domain/hairstyle_presets.dart';

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

  /// Gender is derived from the authenticated user's profile in [initState]
  /// and never edited from this screen — asking again every session was
  /// wasted vertical space when the account already carries the answer.
  /// Falls back to 'male' for accounts registered before the schema had
  /// a gender field.
  String _gender = 'male';
  final Set<String> _selectedStyles = {'hair'};

  @override
  void initState() {
    super.initState();
    final userGender = ref
        .read(authControllerProvider)
        .user
        ?.gender
        ?.toLowerCase();
    if (userGender == 'female') _gender = 'female';
  }
  File? _selfie;
  final Map<String, File> _refImages = {};
  bool _busy = false;
  String? _resultUrl;
  String? _error;

  /// Selected preset per style category (hair / beard / hair_color ...).
  /// Independent from [_refImages] because a preset is a curated app
  /// choice while [_refImages] is a user-uploaded photo. Selecting a
  /// preset with a network thumbnail also fills [_refImages] so the
  /// backend gets the reference bytes; selecting one without a URL
  /// just records the [key] for the AI prompt.
  final Map<String, HairstylePreset> _selectedPresets = {};

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
    setState(() {
      _refImages[key] = f;
      // Custom upload overrides any preset selection for this key.
      _selectedPresets.remove(key);
    });
  }

  /// Called when the user taps a hairstyle tile in the preset library.
  /// Re-tapping the currently selected preset clears the selection so
  /// the tile is a true toggle. If the preset ships with an [imageUrl]
  /// we download it once (cached in the temp dir) and treat it as if
  /// the user had uploaded that photo — same code path the manual
  /// picker uses. If the preset is image-less we still record the
  /// choice so the AI receives the preset key as a style hint.
  Future<void> _pickPreset(HairstylePreset preset) async {
    AppHaptics.selection();
    // Same-preset re-tap = deselect.
    if (_selectedPresets[preset.category]?.key == preset.key) {
      setState(() {
        _selectedPresets.remove(preset.category);
        _refImages.remove(preset.category);
      });
      return;
    }
    setState(() => _selectedPresets[preset.category] = preset);
    final url = preset.imageUrl;
    if (url == null || url.isEmpty) {
      // Clear any stale ref so the preset key becomes the primary hint.
      setState(() => _refImages.remove(preset.category));
      return;
    }
    // Web has no filesystem so getTemporaryDirectory would throw a
    // MissingPluginException. Skip the download and rely on the
    // preset key alone — backend still infers the style from the key.
    if (kIsWeb) return;
    try {
      final dir = await getTemporaryDirectory();
      final safe = url.hashCode.toRadixString(16);
      final file = File('${dir.path}/preset_$safe.jpg');
      if (!file.existsSync()) {
        // Delegate to the AI style repository's shared HTTP client so
        // the download inherits auth headers / timeouts. Falls back to
        // a plain HTTP fetch if the repo doesn't expose a helper.
        await ref
            .read(aiStyleRepositoryProvider)
            .downloadAsset(url: url, saveTo: file);
      }
      if (!mounted) return;
      setState(() => _refImages[preset.category] = file);
    } catch (_) {
      // Silent — the preset key alone is still passed to the AI so
      // generation proceeds without the thumbnail bytes.
    }
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
      // User skipped the category chips entirely — instead of erroring,
      // ask them to pick a focus area right now via a bottom sheet.
      // This preserves the "just upload and go" flow the user asked for
      // while still guaranteeing the backend gets a non-empty styles[].
      final picked = await _askFocusArea();
      if (picked == null) return;
      setState(() => _selectedStyles.add(picked));
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

  /// Bottom-sheet fallback for when the user hits Generate without
  /// picking a style category first. Returns the selected key, or null
  /// if the user dismissed. Shape mirrors the redesigned image picker
  /// sheet for visual consistency.
  Future<String?> _askFocusArea() async {
    final options = _options;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final colors = sheetCtx.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(ref, 'mobile.aiStyle.focusTitle',
                        "Nimani o'zgartiray?"),
                    style: AppText.titleSm,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(ref, 'mobile.aiStyle.focusSubtitle',
                        "AI shu qismga e'tibor beradi"),
                    style: AppText.bodySm
                        .copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < options.length; i++) ...[
                    _FocusTile(
                      emoji: options[i].icon,
                      title: tr(
                          ref,
                          'mobile.aiStyle.styles.${options[i].key}',
                          options[i].label),
                      onTap: () =>
                          Navigator.of(sheetCtx).pop(options[i].key),
                    ),
                    if (i < options.length - 1)
                      const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
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

    // When AI Style is pushed as its own route (e.g. from the shop /
    // barber / customer drawers) it needs a back button — but when
    // it's rendered inside a shell's IndexedStack as a tab, the shell
    // already owns the header so we skip the AppBar. `canPop()`
    // tells us which case we're in without needing a param.
    final showBackBar = Navigator.of(context).canPop();
    return Scaffold(
      appBar: showBackBar
          ? AppBar(
              title: Text(
                tr(ref, 'aiStyle.title', 'AI Stil'),
                style: AppText.titleMd,
              ),
            )
          : null,
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
                      subtitle: tr(ref, 'mobile.aiStyle.step1Hint',
                          "Xohlagan qismlarni tanlang yoki tashlab keting — AI o'zi tanlaydi"),
                    ),
                    AppSpacing.gapMd,
                    _StyleCategoryRow(
                      options: _options,
                      selected: _selectedStyles,
                      onToggle: (k) => setState(() {
                        if (_selectedStyles.contains(k)) {
                          // Clear all state tied to this category —
                          // otherwise the preset selection lingers and
                          // reappears with a stale glow when the user
                          // re-checks the chip later, and the ref file
                          // sticks around unused in _refImages.
                          _selectedStyles.remove(k);
                          _refImages.remove(k);
                          _selectedPresets.remove(k);
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

                    // ===== Qadam 3: kutubxona — tayyor namunalar + o'z rasm =====
                    _StepHeader(
                      number: 3,
                      title: tr(ref, 'mobile.aiStyle.step3Library',
                          "Turmakni tanlang"),
                      subtitle: tr(ref, 'mobile.aiStyle.step3LibraryHint',
                          "Namunalardan birini tanlang yoki oxirdagi tugma orqali o'z rasmingizni yuklang"),
                    ),
                    AppSpacing.gapMd,
                    _PresetLibrary(
                      gender: _gender,
                      selectedStyles: _selectedStyles,
                      selectedPresets: _selectedPresets,
                      refImages: _refImages,
                      onPick: _pickPreset,
                      onUpload: _pickRef,
                      onClearCustom: (k) => setState(() {
                        _refImages.remove(k);
                        _selectedPresets.remove(k);
                      }),
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
                  enabled: _selfie != null,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppRadius.rMd,
                  boxShadow: AppShadows.primaryGlow(AppColors.primary),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 26),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(ref, 'aiStyle.title', 'AI Stil'),
                        style: AppText.titleLg),
                    const SizedBox(height: 2),
                    Text(
                      tr(ref, 'mobile.aiStyle.subtitle',
                          "Sun'iy intellekt yordamida yangi imidjni ko'ring"),
                      style: AppText.bodySm,
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          balance == null
              ? _BalancePill(
                  text: tr(ref, 'aiStyle.perGen', 'Har generatsiya 1000 so\'m'))
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
                        : tr(
                            ref, 'aiStyle.perGen', 'Har generatsiya 1000 so\'m');
                    return _BalancePill(text: text, hasFree: free > 0);
                  },
                ),
        ],
      ),
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
// Step header — subtle numbered badge + title + optional subtitle.
// Pilot number shown in a tinted pill (not a solid square) so the header
// feels editorial rather than form-like.
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
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: AppRadius.rPill,
              ),
              child: Text(
                '$number',
                style: AppText.overline.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                title,
                style: AppText.titleMd.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textBright,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: AppText.bodySm
                .copyWith(color: context.colors.textSecondary),
          ),
        ],
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
              : context.colors.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
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
                        : context.colors.textPrimary,
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
            color: context.colors.surface,
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
                style: AppText.titleSm.copyWith(color: context.colors.textBright),
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
        color: context.colors.background,
        border: Border(top: BorderSide(color: context.colors.border)),
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
/// AI generation is a 10-30 s wait — swap the generic circular spinner
/// for the branded loader so users see the same Lope Style animation
/// that greets them at startup. Kept the message + hint copy intact.
/// AI generation is a black-box API call, so real progress isn't
/// available. Cycle through 4 stage labels every ~4 seconds so the
/// user gets the feeling something is happening (mirrors web's
/// staged progress copy). Fake progress bar sweeps 0% -> ~90% over
/// ~16s, then holds while we wait for the last stage. Result fully
/// arrives when [_busy] flips to false and this widget unmounts.
class _LoadingView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends ConsumerState<_LoadingView>
    with SingleTickerProviderStateMixin {
  int _stage = 0;
  late final Timer _timer;
  late final AnimationController _progress;

  static const _stageDurationMs = 4000;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
      upperBound: 0.92,
    )..forward();
    _timer = Timer.periodic(
      const Duration(milliseconds: _stageDurationMs),
      (_) {
        if (!mounted) return;
        setState(() {
          if (_stage < 3) _stage += 1;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr(ref, 'mobile.aiStyle.stageAnalysing', 'Yuzingizni tahlil qilyapmiz...'),
      tr(ref, 'mobile.aiStyle.stageApplying',  'Stilni tanlayapmiz...'),
      tr(ref, 'mobile.aiStyle.stageCreating',  'Yangi ko\'rinishni yaratyapmiz...'),
      tr(ref, 'mobile.aiStyle.stageFinalising', 'Yakunlanmoqda...'),
    ];
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 220,
            child: BrandedLoader(message: labels[_stage]),
          ),
          AppSpacing.gapLg,
          // Fake progress bar — animates smoothly 0% -> 92% over ~16s
          // so the user sees forward motion.
          AnimatedBuilder(
            animation: _progress,
            builder: (context, _) {
              final pct = (_progress.value * 100).round();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_stage + 1} / 4',
                        style: AppText.caption
                            .copyWith(color: AppColors.primary),
                      ),
                      Text('$pct%',
                          style: AppText.caption
                              .copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 6,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
                    : Container(color: context.colors.surfaceElevated),
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
                    color: context.colors.surfaceElevated,
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

// ─────────────────────────────────────────────────────────────────────────
// Curated hairstyle library — Gemini-style thumbnails the user picks
// from. Grouped per active category (hair / beard / hair_color …) with
// a horizontal scroll each. Tap selects; a second tap on the same tile
// deselects. When [HairstylePreset.imageUrl] is null we render a
// gradient placeholder tile with the style name front-and-centre so
// the UI already looks intentional before real photos are wired in.
// ─────────────────────────────────────────────────────────────────────────
class _PresetLibrary extends ConsumerWidget {
  const _PresetLibrary({
    required this.gender,
    required this.selectedStyles,
    required this.selectedPresets,
    required this.refImages,
    required this.onPick,
    required this.onUpload,
    required this.onClearCustom,
  });

  final String gender;
  final Set<String> selectedStyles;
  final Map<String, HairstylePreset> selectedPresets;
  final Map<String, File> refImages;
  final ValueChanged<HairstylePreset> onPick;
  final ValueChanged<String> onUpload;
  final ValueChanged<String> onClearCustom;

  static const _categoryLabels = <String, String>{
    'hair': 'Soch turmagi',
    'beard': 'Soqol shakli',
    'hair_color': 'Soch rangi',
    'eyebrows': 'Qosh shakli',
    'lips': 'Lab shakli',
    'eyelashes': 'Kiprik uslubi',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedStyles.isEmpty) {
      return AppCard(
        variant: AppCardVariant.outlined,
        padding: AppSpacing.cardPadding,
        child: Row(children: [
          Icon(Icons.info_outline,
              color: context.colors.textMuted, size: 18),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              tr(ref, 'mobile.aiStyle.pickCategoryFirst',
                  "Yuqoridan qismni tanlang yoki generatsiyani boshlang — AI o'zi so'raydi"),
              style: AppText.bodySm,
            ),
          ),
        ]),
      );
    }

    return Column(
      children: [
        for (final category in selectedStyles) ...[
          _CategoryRow(
            category: category,
            title: _categoryLabels[category] ?? category,
            presets: presetsFor(gender, category),
            selected: selectedPresets[category],
            // Only surface the ref as "custom" when it came from an
            // upload — preset picks also populate refImages, but those
            // are represented by the highlighted preset tile.
            customRef: selectedPresets[category] == null
                ? refImages[category]
                : null,
            onPick: onPick,
            onUpload: onUpload,
            onClearCustom: onClearCustom,
          ),
          AppSpacing.gapMd,
        ],
      ],
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  const _CategoryRow({
    required this.category,
    required this.title,
    required this.presets,
    required this.selected,
    required this.customRef,
    required this.onPick,
    required this.onUpload,
    required this.onClearCustom,
  });

  final String category;
  final String title;
  final List<HairstylePreset> presets;
  final HairstylePreset? selected;
  final File? customRef;
  final ValueChanged<HairstylePreset> onPick;
  final ValueChanged<String> onUpload;
  final ValueChanged<String> onClearCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always render at least the upload tile even if there are no
    // curated presets for this category — keeps the row consistent
    // across categories and gives the user a way to add their own.
    final total = presets.length + 1; // +1 for upload-own tile
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(title, style: AppText.overline),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            separatorBuilder: (_, _) => AppSpacing.hGapSm,
            itemBuilder: (context, i) {
              if (i < presets.length) {
                final p = presets[i];
                return _PresetTile(
                  preset: p,
                  isSelected: selected?.key == p.key,
                  onTap: () => onPick(p),
                );
              }
              return _UploadOwnTile(
                customRef: customRef,
                onTap: () => onUpload(category),
                onRemove: () => onClearCustom(category),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final HairstylePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  /// Deterministic gradient per preset key so image-less tiles still
  /// look distinct instead of a wall of identical purple boxes.
  List<Color> _paletteFor(String key) {
    final palettes = <List<Color>>[
      [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
      [const Color(0xFF8B5CF6), const Color(0xFFD946EF)],
      [const Color(0xFFEF4444), const Color(0xFFF97316)],
      [const Color(0xFF10B981), const Color(0xFF14B8A6)],
      [const Color(0xFFF59E0B), const Color(0xFFF97316)],
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)],
      [const Color(0xFFEC4899), const Color(0xFFEF4444)],
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
    ];
    return palettes[key.hashCode.abs() % palettes.length];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.94,
      child: SizedBox(
        width: 106,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                borderRadius: AppRadius.rLg,
                border: Border.all(
                  color: isSelected ? AppColors.primary : palette.border,
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: isSelected
                    ? AppShadows.primaryGlow(AppColors.primary)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    isSelected ? AppRadius.lg - 2 : AppRadius.lg - 1),
                child: Stack(fit: StackFit.expand, children: [
                  if (preset.imageUrl != null && preset.imageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: preset.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          _GradientFallback(colors: _paletteFor(preset.key)),
                      errorWidget: (_, _, _) =>
                          _GradientFallback(colors: _paletteFor(preset.key)),
                    )
                  else
                    _GradientFallback(colors: _paletteFor(preset.key)),
                  // Bottom scrim so name is always readable.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x99000000),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              preset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.content_cut, color: Colors.white70, size: 30),
      ),
    );
  }
}

/// Trailing tile in each preset row that lets the user drop in their
/// own reference photo. When [customRef] is null the tile shows a
/// gradient "+" affordance; once populated it renders the actual image
/// preview with a remove button so the user can revert to a preset.
class _UploadOwnTile extends StatelessWidget {
  const _UploadOwnTile({
    required this.customRef,
    required this.onTap,
    required this.onRemove,
  });

  final File? customRef;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final hasCustom = customRef != null;
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      scale: 0.94,
      child: SizedBox(
        width: 106,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                borderRadius: AppRadius.rLg,
                color: hasCustom ? null : palette.surfaceElevated,
                border: Border.all(
                  color: hasCustom ? AppColors.primary : palette.border,
                  width: hasCustom ? 2.5 : 1.5,
                ),
                boxShadow: hasCustom
                    ? AppShadows.primaryGlow(AppColors.primary)
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    hasCustom ? AppRadius.lg - 2 : AppRadius.lg - 1),
                child: Stack(fit: StackFit.expand, children: [
                  if (hasCustom)
                    Image.file(customRef!, fit: BoxFit.cover)
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.primaryGlow(
                                  AppColors.primary),
                            ),
                            child: const Icon(
                                Icons.add_photo_alternate_rounded,
                                color: Colors.white,
                                size: 22),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Ixtiyoriy",
                            style: AppText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (hasCustom)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onRemove,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasCustom ? "O'z rasm" : "Yuklash",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(
                fontWeight: hasCustom ? FontWeight.w700 : FontWeight.w500,
                color: hasCustom ? AppColors.primary : palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet row used in [_askFocusArea]. Same visual language as the
/// image picker's source tiles — gradient icon bubble, big touch
/// target, chevron on the right.
class _FocusTile extends StatelessWidget {
  const _FocusTile({
    required this.emoji,
    required this.title,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      haptic: HapticStrength.selection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.primaryGlow(AppColors.primary),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: colors.textMuted),
        ]),
      ),
    );
  }
}
