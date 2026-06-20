import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../lopepay/data/balance_repository.dart';
import '../data/ai_style_repository.dart';

/// Mirrors `CustomerAIStyleScreen.tsx` 1:1:
///   - Balance pill at the top
///   - Style options horizontal row (cards 72px wide, multi-select; under each
///     selected card a reference-image upload tile appears)
///   - Big photo area: empty → dashed Camera card; with photo → preview + X
///   - Generate button (full-width primary at bottom)
///   - After generation: 2-col split (Original | Result) + Download/Try Again
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
    final f = await ImagePickerService.instance.pickFromSheet(context);
    if (f != null) setState(() => _selfie = f);
  }

  Future<void> _pickRef(String key) async {
    final f = await ImagePickerService.instance.pickFromSheet(context, allowCamera: false);
    if (f != null) setState(() => _refImages[key] = f);
  }

  Future<void> _generate() async {
    if (_selfie == null) {
      setState(() => _error = "Avval o'zingizning rasmingizni yuklang");
      return;
    }
    if (_selectedStyles.isEmpty) {
      setState(() => _error = "Kamida bitta stil tanlang");
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
            references: _refImages.values.toList(),
          );
      setState(() => _resultUrl = r.imageUrl);
      final user = ref.read(authControllerProvider).user;
      if (user != null) ref.invalidate(myBalanceProvider(user.id));
    } on Object catch (e) {
      String msg = "Generatsiya bajarilmadi";
      final s = e.toString();
      if (s.contains('402') || s.contains('balance')) {
        msg = "Balansingiz yetarli emas. Hisobni to'ldiring.";
      }
      if (s.contains('SocketException')) msg = "Internet bilan muammo";
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
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

    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ===== Title + free-quota line =====
            Text(tr(ref, 'aiStyle.title', "AI Stil"),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright)),
            const SizedBox(height: 4),
            balance == null
                ? const SizedBox.shrink()
                : balance.when(
                    loading: () => const SizedBox(height: 14),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (b) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          b.aiFreeRemaining != null && b.aiFreeRemaining! > 0
                              ? tr(ref, 'aiStyle.todayFree',
                                  "Bugun {{count}} ta bepul · 1000 so'm",
                                  {'count': '${b.aiFreeRemaining}'})
                              : tr(ref, 'aiStyle.perGen',
                                  "1000 so'm har generatsiya"),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 14),

            // ===== Gender pill toggle (since mobile doesn't have profile gender) =====
            Row(children: [
              Expanded(
                child: _GenderChip(
                  label: "👨 ${tr(ref, 'auth.genderMale', 'Erkak')}",
                  on: _gender == 'male',
                  onTap: () => setState(() {
                    _gender = 'male';
                    _selectedStyles
                      ..clear()
                      ..add('hair');
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GenderChip(
                  label: "👩 ${tr(ref, 'auth.genderFemale', 'Ayol')}",
                  on: _gender == 'female',
                  onTap: () => setState(() {
                    _gender = 'female';
                    _selectedStyles
                      ..clear()
                      ..add('hair');
                  }),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ===== Style options row (only when no result yet) =====
            if (_resultUrl == null) ...[
              Text(tr(ref, 'aiStyle.styleQuestion', "Qaysi qismni o'zgartirmoqchisiz?"),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              SizedBox(
                height: 144,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _options.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final opt = _options[i];
                    final on = _selectedStyles.contains(opt.key);
                    // Renamed from `ref` to `refImage` so it doesn't shadow the
                    // ConsumerState's WidgetRef and break tr() calls inside.
                    final refImage = _refImages[opt.key];
                    return SizedBox(
                      width: 76,
                      child: Column(children: [
                        // Style card
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() {
                            if (on) {
                              _selectedStyles.remove(opt.key);
                            } else {
                              _selectedStyles.add(opt.key);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            decoration: BoxDecoration(
                              color: on
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: on ? AppColors.primary : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(opt.icon,
                                        style:
                                            const TextStyle(fontSize: 24)),
                                    const SizedBox(height: 6),
                                    Text(opt.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: on
                                                ? AppColors.primary
                                                : AppColors.textBright)),
                                  ],
                                ),
                                if (on)
                                  Positioned(
                                    top: -6, right: -6,
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check,
                                          size: 10, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Reference image tile under the selected card
                        if (on) ...[
                          if (refImage != null)
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    refImage,
                                    width: 72,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: -4, right: -4,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _refImages.remove(opt.key)),
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _pickRef(opt.key),
                              child: Container(
                                width: 72, height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate_outlined,
                                        size: 10,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 2),
                                    Text(tr(ref, 'aiStyle.reference', "Namuna"),
                                        style: const TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ]),
                    );
                  },
                ),
              ),
              if (_selectedStyles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(tr(ref, 'aiStyle.selectAtLeastOne', "Kamida bitta stilni tanlang"),
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 11)),
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // ===== Main photo area =====
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _busy
                    ? _LoadingView()
                    : (_resultUrl != null && _resultUrl!.isNotEmpty)
                        ? _ResultView(
                            original: _selfie,
                            resultUrl: _resultUrl!,
                            onReset: _reset,
                          )
                        : (_selfie != null
                            ? _PreviewView(
                                file: _selfie!,
                                onRemove: _reset,
                                onGenerate: _generate,
                              )
                            : _EmptyView(onTap: _pickSelfie)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 12)),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StyleOpt {
  const _StyleOpt(this.key, this.label, this.icon);
  final String key;
  final String label;
  final String icon;
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primary : AppColors.textPrimary)),
      ),
    );
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt,
                  color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: 16),
            Text(tr(ref, 'aiStyle.uploadPhoto', "Rasmingizni yuklang"),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBright)),
            const SizedBox(height: 4),
            Text(tr(ref, 'aiStyle.uploadHint', "Yuzni aniq ko'rsatuvchi selfie tanlang"),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PreviewView extends ConsumerWidget {
  const _PreviewView({
    required this.file,
    required this.onRemove,
    required this.onGenerate,
  });
  final File file;
  final VoidCallback onRemove;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: 380),
        ),
        Positioned(
          top: 8, right: 8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(tr(ref, 'aiStyle.generate', "Yaratish"),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          onPressed: onGenerate,
        ),
      ),
    ]);
  }
}

class _LoadingView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 380,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80, height: 80,
                child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary.withValues(alpha: 0.4))),
              ),
              const Icon(Icons.auto_awesome,
                  size: 32, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 20),
          Text(tr(ref, 'aiStyle.generating', "Sizning yangi stil tayyorlanmoqda..."),
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).fade(begin: 0.7, end: 1, duration: 1200.ms);
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
        // Original
        Expanded(
          child: Column(children: [
            Text(tr(ref, 'aiStyle.original', "Asl"),
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: original != null
                    ? Image.file(original!, fit: BoxFit.cover)
                    : Container(color: AppColors.surfaceElevated),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        // Result
        Expanded(
          child: Column(children: [
            Text(tr(ref, 'aiStyle.result', "Natija"),
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: resultUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, _) => Container(
                      color: AppColors.surfaceElevated,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator()),
                ),
              ),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: Text(tr(ref, 'aiStyle.download', "Yuklab olish")),
              onPressed: () {},
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(tr(ref, 'aiStyle.tryAgain', "Qaytadan")),
              onPressed: onReset,
            ),
          ),
        ),
      ]),
    ]);
  }
}
