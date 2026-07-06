import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../auth/presentation/auth_controller.dart';

/// Mirrors `BarberCardsScreen.tsx` 1:1.
///   - Header with back button + CreditCard icon + title
///   - "Yangi karta qo'shish" full-width button
///   - List of payment cards, each rendered as a beautiful gradient credit
///     card (HUMO green, UZCARD blue, VISA sky, MASTERCARD red, fallback slate)
///   - Each card: chip + wifi icon top-left, brand + default-star badge
///     top-right, masked card number in monospace, holder name bottom
///   - Below each card: Set Default / Edit / Delete buttons
class BarberCardsScreen extends ConsumerWidget {
  const BarberCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barberId = ref.watch(authControllerProvider).user?.id;
    if (barberId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(_cardsProvider(barberId));
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
              const Icon(Icons.credit_card, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(tr(ref, 'mobile.barber.cards.title', "Mening kartalarim"),
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
                  child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}", style: const TextStyle(color: AppColors.textMuted))),
              data: (list) => RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.refresh(_cardsProvider(barberId).future),
                child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    tr(ref, 'mobile.barber.cards.hint',
                        "Pul olish uchun kartalaringizni boshqaring"),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  // ===== Add card button =====
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(tr(ref, 'mobile.barber.cards.addNew', "Yangi karta qo'shish")),
                      onPressed: () => _openEditor(context, ref),
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (list.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.credit_card_off,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(tr(ref, 'mobile.barber.cards.empty', "Hali karta qo'shilmagan"),
                              style: const TextStyle(
                                  color: AppColors.textBright, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                        ],
                      ),
                    )
                  else
                    ...list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final card = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CardItem(
                          card: card,
                          onSetDefault: () => _setDefault(ref, card['id'].toString()),
                          onEdit: () => _openEditor(context, ref, existing: card),
                          onDelete: () => _confirmDelete(context, ref, card),
                        ).animate().fadeIn(duration: 200.ms, delay: (i * 60).ms),
                      );
                    }),
                ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _setDefault(WidgetRef ref, String id) async {
    final barberId = ref.read(authControllerProvider).user?.id;
    if (barberId == null) return;
    try {
      // Backend: POST /barbers/:barberId/cards/:cardId/set-default
      await ref
          .read(dioProvider)
          .post('/barbers/$barberId/cards/$id/set-default');
      ref.invalidate(_cardsProvider);
    } catch (_) {}
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> card) async {
    final masked = _maskNumber(card['cardNumber']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'mobile.barber.cards.deleteTitle', "Kartani o'chirish?")),
        content: Text(tr(ref, 'mobile.barber.cards.deleteConfirm',
            "{{masked}} karta o'chiriladi", {'masked': masked})),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'common.delete', "O'chirish")),
          ),
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    final number = TextEditingController(text: (existing?['cardNumber'] ?? '').toString());
    final holder = TextEditingController(text: (existing?['holderName'] ?? '').toString());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              existing == null
                  ? tr(ref, 'mobile.barber.cards.newCard', "Yangi karta")
                  : tr(ref, 'common.edit', "Tahrirlash"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textBright, letterSpacing: -0.3)),
          const SizedBox(height: 14),
          ShadLabel(tr(ref, 'mobile.barber.cards.cardNumber', "Karta raqami")),
          const SizedBox(height: 6),
          TextField(
            controller: number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
            style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: "9860 0000 0000 0000"),
          ),
          const SizedBox(height: 10),
          ShadLabel(tr(ref, 'mobile.barber.cards.holderName', "Egasining ismi")),
          const SizedBox(height: 6),
          TextField(
            controller: holder,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: "AZIMOV SHOHRUH"),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(true),
              child: Text(tr(ref, 'common.save', "Saqlash")),
            ),
          ),
        ]),
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
            .patch('/barbers/$barberId/cards/${existing['id']}', data: body);
      }
      ref.invalidate(_cardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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

/// Pick brand colors based on the BIN prefix (Humo 9860 / Uzcard 8600 /
/// Visa 4 / Mastercard 5[1-5] | 2[2-7]). Falls back to a slate gradient.
({String name, List<Color> colors}) _getBrand(String num) {
  final d = num.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('9860')) {
    return (
      name: 'HUMO',
      colors: [const Color(0xFF10B981), const Color(0xFF0D9488), const Color(0xFF0E7490)]
    );
  }
  if (d.startsWith('8600')) {
    return (
      name: 'UZCARD',
      colors: [const Color(0xFF2563EB), const Color(0xFF4338CA), const Color(0xFF6D28D9)]
    );
  }
  if (d.startsWith('4')) {
    return (
      name: 'VISA',
      colors: [const Color(0xFF0284C7), const Color(0xFF1D4ED8), const Color(0xFF3730A3)]
    );
  }
  if (RegExp(r'^5[1-5]').hasMatch(d) || RegExp(r'^2[2-7]').hasMatch(d)) {
    return (
      name: 'MASTERCARD',
      colors: [const Color(0xFFE11D48), const Color(0xFFDC2626), const Color(0xFFEA580C)]
    );
  }
  return (
    name: 'CARD',
    colors: [const Color(0xFF334155), const Color(0xFF1E293B), const Color(0xFF18181B)]
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
    final masked = BarberCardsScreen._maskNumber(card['cardNumber']?.toString() ?? '');

    return Column(children: [
      // ===== Credit card visual =====
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: isDefault
              ? Border.all(color: const Color(0xFFFBBF24), width: 2)
              : null,
        ),
        padding: isDefault ? const EdgeInsets.all(2) : EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: Stack(children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: brand.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Decorative blob
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -30, left: -20,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Top row: chip + wifi (left), brand + default star (right)
              Positioned(
                top: 14, left: 16, right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chip
                    Container(
                      width: 36, height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDE68A), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.rotate(
                      angle: 1.57,
                      child: const Icon(Icons.wifi, color: Colors.white, size: 16),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(brand.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            )),
                        if (isDefault) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star, color: Color(0xFFA16207), size: 10),
                              const SizedBox(width: 3),
                              Text(tr(ref, 'mobile.barber.cards.primary', "Asosiy"),
                                  style: const TextStyle(
                                    color: Color(0xFFA16207),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Card number center
              Positioned(
                left: 16, right: 16, top: 0, bottom: 0,
                child: Center(
                  child: Text(
                    masked,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

              // Bottom: holder
              Positioned(
                left: 16, right: 16, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        tr(ref, 'mobile.barber.cards.cardHolder', "KARTA EGASI"),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      holder.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),

      const SizedBox(height: 8),

      // ===== Action buttons =====
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              icon: Icon(
                isDefault ? Icons.star : Icons.star_border,
                size: 14,
                color: isDefault ? const Color(0xFFFBBF24) : AppColors.textMuted,
              ),
              label: Text(
                isDefault ? "Asosiy" : "Asosiy qil",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDefault ? const Color(0xFFFBBF24) : AppColors.textBright,
                ),
              ),
              onPressed: isDefault ? null : onSetDefault,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44, height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onEdit,
            child: const Icon(Icons.edit, size: 14, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 44, height: 36,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            onPressed: onDelete,
            child: const Icon(Icons.delete_outline, size: 14, color: AppColors.danger),
          ),
        ),
      ]),
    ]);
  }
}

/// Family on barberId — backend endpoint is /barbers/:barberId/cards.
/// All previous `/barber/cards` calls 404'd in production.
final _cardsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
    (ref, barberId) async {
  final res = await ref.watch(dioProvider).get('/barbers/$barberId/cards');
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
  return list.cast<Map<String, dynamic>>();
});
