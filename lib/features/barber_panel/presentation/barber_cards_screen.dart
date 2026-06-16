import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../shared/theme/colors.dart';

/// Cards the barber uses to receive payouts. Backend: GET /barber/cards,
/// POST /barber/cards { number, holder, expiry }, DELETE /barber/cards/:id.
class BarberCardsScreen extends ConsumerWidget {
  const BarberCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_barberCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Kartalarim")),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text("Karta qo'shish"),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card_outlined, size: 56, color: AppColors.textMuted),
                    SizedBox(height: 14),
                    Text("Hali karta qo'shilmagan",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_barberCardsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = list[i];
                final masked = _maskNumber(c['number']?.toString() ?? '');
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.credit_card, color: Colors.white),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white70),
                          onPressed: () => _confirmDelete(context, ref, c['id'].toString()),
                        ),
                      ]),
                      Text(masked,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: Text((c['holder'] ?? '').toString().toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Text((c['expiry'] ?? '').toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  String _maskNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return raw;
    final last4 = digits.substring(digits.length - 4);
    return '•••• •••• •••• $last4';
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final number = TextEditingController();
    final holder = TextEditingController();
    final expiry = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Yangi karta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16)],
              decoration: const InputDecoration(hintText: "Karta raqami (16 raqam)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: holder,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: "Egasining ismi"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: expiry,
              keyboardType: TextInputType.datetime,
              inputFormatters: [LengthLimitingTextInputFormatter(5)],
              decoration: const InputDecoration(hintText: "MM/YY"),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: const Text("Saqlash"),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/barber/cards', data: {
        'number': number.text.trim(),
        'holder': holder.text.trim(),
        'expiry': expiry.text.trim(),
      });
      ref.invalidate(_barberCardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Kartani o'chirish?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text("Bekor")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text("O'chirish"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/barber/cards/$id');
      ref.invalidate(_barberCardsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }
}

final _barberCardsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.watch(dioProvider).get('/barber/cards');
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
  return list.cast<Map<String, dynamic>>();
});
