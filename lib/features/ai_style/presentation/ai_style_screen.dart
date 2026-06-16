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

/// AI-driven hair / beard / makeup styler. The flow:
///   1. Pick a selfie
///   2. Pick 1–4 reference style images
///   3. Call /ai-style/generate (FormData)
///   4. Show the composite + balance impact
class AiStyleScreen extends ConsumerStatefulWidget {
  const AiStyleScreen({super.key});

  @override
  ConsumerState<AiStyleScreen> createState() => _AiStyleScreenState();
}

class _AiStyleScreenState extends ConsumerState<AiStyleScreen> {
  File? _selfie;
  final List<File> _refs = [];
  String _gender = 'male';
  bool _busy = false;
  String? _resultUrl;
  String? _errorText;

  Future<void> _pickSelfie() async {
    final f = await ImagePickerService.instance.pickFromSheet(context);
    if (f != null) setState(() => _selfie = f);
  }

  Future<void> _addReference() async {
    if (_refs.length >= 4) return;
    final f = await ImagePickerService.instance.pickFromSheet(context, allowCamera: false);
    if (f != null) setState(() => _refs.add(f));
  }

  Future<void> _generate() async {
    if (_selfie == null) {
      setState(() => _errorText = tr(ref, 'mobile.customer.aiStyle.selfieMissing', "Avval o'zingizning rasmingizni yuklang"));
      return;
    }
    if (_refs.isEmpty) {
      setState(() => _errorText = tr(ref, 'mobile.customer.aiStyle.refMissing', "Kamida bitta stil namunasi yuklang"));
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
      _resultUrl = null;
    });
    try {
      final r = await ref.read(aiStyleRepositoryProvider).generate(
            selfie: _selfie!,
            gender: _gender,
            references: _refs,
          );
      setState(() => _resultUrl = r.imageUrl);
      // refresh balance card so deduction is visible
      final user = ref.read(authControllerProvider).user;
      if (user != null) ref.invalidate(myBalanceProvider(user.id));
    } on Object catch (e) {
      String msg = tr(ref, 'mobile.customer.aiStyle.errorGeneric', "Generatsiya bajarilmadi");
      final s = e.toString();
      if (s.contains('402') || s.contains('balance')) {
        msg = tr(ref, 'mobile.customer.aiStyle.errorBalance', "Balansingiz yetarli emas. Hisobni to'ldiring.");
      }
      if (s.contains('SocketException')) {
        msg = tr(ref, 'mobile.customer.aiStyle.errorInternet', "Internet bilan muammo");
      }
      setState(() => _errorText = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final balance = user == null ? null : ref.watch(myBalanceProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.customer.aiStyle.title', "AI Stil"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (balance != null)
            balance.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                        tr(ref, 'mobile.customer.aiStyle.balance', "Balans: {{amount}} so'm",
                            {'amount': _fmt(b.amount)}),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const Spacer(),
                    if (b.aiFreeRemaining != null && b.aiFreeRemaining! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            tr(ref, 'mobile.customer.aiStyle.freeRemaining', "Bugun {{n}} ta bepul",
                                {'n': '${b.aiFreeRemaining}'}),
                            style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          _SectionTitle(tr(ref, 'mobile.customer.aiStyle.step1', "1. O'zingizning rasmingiz")),
          GestureDetector(
            onTap: _pickSelfie,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: _selfie == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 32),
                          const SizedBox(height: 8),
                          Text(tr(ref, 'mobile.customer.aiStyle.addSelfie', "Selfie qo'shing"),
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(_selfie!, fit: BoxFit.cover, width: double.infinity),
                    ),
            ),
          ),

          const SizedBox(height: 18),
          _SectionTitle(tr(ref, 'mobile.customer.aiStyle.step2', "2. Stil namunalari (1-4 ta)")),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              ..._refs.asMap().entries.map((e) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(e.value, width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: InkWell(
                          onTap: () => setState(() => _refs.removeAt(e.key)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  )),
              if (_refs.length < 4)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _addReference,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: const Icon(Icons.add, color: AppColors.primary),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),
          _SectionTitle(tr(ref, 'mobile.customer.aiStyle.step3', "3. Jins")),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  label: Text(tr(ref, 'mobile.customer.aiStyle.male', "Erkak")),
                  selected: _gender == 'male',
                  onSelected: (_) => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  selectedColor: AppColors.primary.withValues(alpha: 0.25),
                  label: Text(tr(ref, 'mobile.customer.aiStyle.female', "Ayol")),
                  selected: _gender == 'female',
                  onSelected: (_) => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),

          if (_errorText != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorText!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.auto_awesome),
              label: Text(_busy
                  ? tr(ref, 'mobile.customer.aiStyle.generating', "Generatsiya...")
                  : tr(ref, 'mobile.customer.aiStyle.generate', "AI orqali yaratish")),
              onPressed: _busy ? null : _generate,
            ),
          ),

          if (_resultUrl != null && _resultUrl!.isNotEmpty) ...[
            const SizedBox(height: 26),
            _SectionTitle(tr(ref, 'mobile.customer.aiStyle.result', "Natija")),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: _resultUrl!,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  height: 200, color: AppColors.surface,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
          ],
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
      );
}
