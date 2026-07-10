import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';

class BarberCardsScreen extends ConsumerWidget {
  const BarberCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(_cardsProvider(barberId));
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.credit_card,
              color: AppColors.primary, size: 22),
          AppSpacing.hGapSm,
          Text(
            tr(ref, 'mobile.barber.cards.title', 'Mening kartalarim'),
            style: AppText.titleMd,
          ),
        ]),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (list) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async =>
              ref.refresh(_cardsProvider(barberId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                tr(ref, 'mobile.barber.cards.hint',
                    'Pul olish uchun kartalaringizni boshqaring'),
                style: AppText.bodyLg
                    .copyWith(color: AppColors.textSecondary),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: tr(ref, 'mobile.barber.cards.addNew',
                    "Yangi karta qo'shish"),
                leadingIcon: Icons.add,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                onPressed: () => _openEditor(context, ref),
              ),
              AppSpacing.gapLg,
              if (list.isEmpty)
                AppEmptyState(
                  icon: Icons.credit_card_off,
                  title: tr(ref, 'mobile.barber.cards.empty',
                      "Hali karta qo'shilmagan"),
                )
              else
                ...list.asMap().entries.map((entry) {
                  final i = entry.key;
                  final card = entry.value;
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _CardItem(
                      card: card,
                      onSetDefault: () =>
                          _setDefault(ref, card['id'].toString()),
                      onEdit: () =>
                          _openEditor(context, ref, existing: card),
                      onDelete: () =>
                          _confirmDelete(context, ref, card),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (i * 60).ms),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setDefault(WidgetRef ref, String id) async {
    AppHaptics.medium();
    final barberId = ref.read(authControllerProvider).user?.id;
    if (barberId == null) return;
    try {
      await ref
          .read(dioProvider)
          .post('/barbers/$barberId/cards/$id/set-default');
      AppHaptics.success();
      ref.invalidate(_cardsProvider);
    } catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> card) async {
    AppHaptics.light();
    final masked =
        _maskNumber(card['cardNumber']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.barber.cards.deleteTitle',
                    "Kartani o'chirish?"),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(
                    ref,
                    'mobile.barber.cards.deleteConfirm',
                    "{{masked}} karta o'chiriladi",
                    {'masked': masked}),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx, false),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.delete', "O'chirish"),
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.pop(dCtx, true),
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      final barberId = ref.read(authControllerProvider).user?.id;
      if (barberId == null) return;
      await ref
          .read(dioProvider)
          .delete('/barbers/$barberId/cards/${card['id']}');
      ref.invalidate(_cardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    AppHaptics.light();
    final number = TextEditingController(
        text: (existing?['cardNumber'] ?? '').toString());
    final holder = TextEditingController(
        text: (existing?['holderName'] ?? '').toString());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom:
              AppSpacing.lg + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.rPill,
                ),
              ),
            ),
            AppSpacing.gapMd,
            Text(
              existing == null
                  ? tr(ref, 'mobile.barber.cards.newCard', 'Yangi karta')
                  : tr(ref, 'common.edit', 'Tahrirlash'),
              style: AppText.titleMd,
            ),
            AppSpacing.gapLg,
            Text(
              tr(ref, 'mobile.barber.cards.cardNumber',
                  'Karta raqami'),
              style: AppText.overline,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: number,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16)
              ],
              style: AppText.body.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                  hintText: '9860 0000 0000 0000'),
            ),
            AppSpacing.gapSm,
            Text(
              tr(ref, 'mobile.barber.cards.holderName',
                  'Egasining ismi'),
              style: AppText.overline,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: holder,
              textCapitalization: TextCapitalization.characters,
              style: AppText.body.copyWith(fontWeight: FontWeight.w700),
              decoration:
                  const InputDecoration(hintText: 'AZIMOV SHOHRUH'),
            ),
            AppSpacing.gapLg,
            AppButton(
              label: tr(ref, 'common.save', 'Saqlash'),
              variant: AppButtonVariant.primary,
              size: AppButtonSize.lg,
              fullWidth: true,
              onPressed: () => Navigator.of(sheetCtx).pop(true),
            ),
          ],
        ),
      ),
    );
    try {
      if (ok != true) return;
      final body = {
        'cardNumber': number.text.trim(),
        'holderName': holder.text.trim(),
      };
      final barberId = ref.read(authControllerProvider).user?.id;
      if (barberId == null) return;
      if (existing == null) {
        await ref
            .read(dioProvider)
            .post('/barbers/$barberId/cards', data: body);
      } else {
        await ref
            .read(dioProvider)
            .patch('/barbers/$barberId/cards/${existing['id']}',
                data: body);
      }
      AppHaptics.success();
      ref.invalidate(_cardsProvider);
    } catch (e) {
      AppHaptics.error();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      number.dispose();
      holder.dispose();
    }
  }

  static String _maskNumber(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length < 8) return d;
    final first = d.substring(0, 4);
    final last = d.substring(d.length - 4);
    final middleLen = d.length - 8;
    final middleGroups = (middleLen / 4).ceil();
    final middle =
        List.generate(middleGroups, (_) => '••••').join(' ');
    return [first, if (middle.isNotEmpty) middle, last].join(' ');
  }
}

({String name, List<Color> colors}) _getBrand(String num) {
  final d = num.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('9860')) {
    return (
      name: 'HUMO',
      colors: [
        const Color(0xFF10B981),
        const Color(0xFF0D9488),
        const Color(0xFF0E7490)
      ]
    );
  }
  if (d.startsWith('8600')) {
    return (
      name: 'UZCARD',
      colors: [
        const Color(0xFF2563EB),
        const Color(0xFF4338CA),
        const Color(0xFF6D28D9)
      ]
    );
  }
  if (d.startsWith('4')) {
    return (
      name: 'VISA',
      colors: [
        const Color(0xFF0284C7),
        const Color(0xFF1D4ED8),
        const Color(0xFF3730A3)
      ]
    );
  }
  if (RegExp(r'^5[1-5]').hasMatch(d) ||
      RegExp(r'^2[2-7]').hasMatch(d)) {
    return (
      name: 'MASTERCARD',
      colors: [
        const Color(0xFFE11D48),
        const Color(0xFFDC2626),
        const Color(0xFFEA580C)
      ]
    );
  }
  return (
    name: 'CARD',
    colors: [
      const Color(0xFF334155),
      const Color(0xFF1E293B),
      const Color(0xFF18181B)
    ]
  );
}

class _CardItem extends ConsumerWidget {
  const _CardItem({
    required this.card,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> card;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = _getBrand(card['cardNumber']?.toString() ?? '');
    final isDefault = card['isDefault'] == true;
    final holder = (card['holderName'] ?? '—').toString();
    final masked =
        BarberCardsScreen._maskNumber(card['cardNumber']?.toString() ?? '');

    return Column(children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.rXl,
          border: isDefault
              ? Border.all(color: const Color(0xFFFBBF24), width: 2)
              : null,
        ),
        padding: isDefault ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: AppRadius.rLg,
          child: AspectRatio(
            aspectRatio: 1.6,
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: brand.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFDE68A),
                            Color(0xFFD97706)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppRadius.rSm,
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Transform.rotate(
                      angle: 1.57,
                      child: const Icon(Icons.wifi,
                          color: Colors.white, size: 16),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(brand.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            )),
                        if (isDefault) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: AppRadius.rPill,
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      color: Color(0xFFA16207),
                                      size: 10),
                                  const SizedBox(width: 3),
                                  Text(
                                      tr(
                                          ref,
                                          'mobile.barber.cards.primary',
                                          'Asosiy'),
                                      style: const TextStyle(
                                        color: Color(0xFFA16207),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    masked,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(ref, 'mobile.barber.cards.cardHolder',
                          'KARTA EGASI'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      holder.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
      AppSpacing.gapSm,
      Row(children: [
        Expanded(
          child: AppButton(
            label: isDefault ? 'Asosiy' : 'Asosiy qil',
            leadingIcon: isDefault ? Icons.star : Icons.star_border,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            fullWidth: true,
            onPressed: isDefault ? null : onSetDefault,
          ),
        ),
        AppSpacing.hGapSm,
        TapScale(
          onTap: onEdit,
          scale: 0.9,
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.rMd,
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.edit,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
        AppSpacing.hGapXs,
        TapScale(
          onTap: onDelete,
          scale: 0.9,
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: AppRadius.rMd,
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.danger),
          ),
        ),
      ]),
    ]);
  }
}

final _cardsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, barberId) async {
  final res =
      await ref.watch(dioProvider).get('/barbers/$barberId/cards');
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List
          ? data['data'] as List
          : <dynamic>[]);
  return list.cast<Map<String, dynamic>>();
});
