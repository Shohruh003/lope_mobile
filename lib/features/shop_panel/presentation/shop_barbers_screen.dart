import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

class ShopBarbersScreen extends ConsumerWidget {
  const ShopBarbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shopBarbersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Mastera")),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text("Qo'shish"),
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
                    Icon(Icons.people_alt_outlined, size: 60, color: AppColors.textMuted),
                    SizedBox(height: 14),
                    Text("Hali masterlar qo'shilmagan",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(shopBarbersProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = list[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    ClipOval(
                      child: (b.avatar != null && b.avatar!.isNotEmpty)
                          ? CachedNetworkImage(imageUrl: b.avatar!, width: 48, height: 48, fit: BoxFit.cover)
                          : Container(width: 48, height: 48, color: AppColors.background, child: const Icon(Icons.person, color: AppColors.textMuted)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          if (b.experience.isNotEmpty)
                            Text("Tajriba: ${b.experience}",
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          if (b.phone?.isNotEmpty == true)
                            Text(b.phone!,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                      onPressed: () => _openEditor(context, ref, existing: b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                      onPressed: () => _confirmDelete(context, ref, b),
                    ),
                  ]),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {ShopBarber? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final exp = TextEditingController(text: existing?.experience ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final result = await showModalBottomSheet<bool>(
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
            Text(existing == null ? "Yangi master" : "Tahrirlash",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(hintText: "Ism")),
            const SizedBox(height: 10),
            TextField(controller: exp, decoration: const InputDecoration(hintText: "Tajriba (masalan: 3 yil)")),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: "Telefon (ixtiyoriy)")),
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
    if (result != true) return;
    try {
      final repo = ref.read(shopRepositoryProvider);
      if (existing == null) {
        await repo.createBarber(name: name.text.trim(), experience: exp.text.trim(), phone: phone.text.trim());
      } else {
        await repo.updateBarber(existing.id, {
          'name': name.text.trim(),
          'experience': exp.text.trim(),
          if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        });
      }
      ref.invalidate(shopBarbersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ShopBarber b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Masterni o'chirish?"),
        content: Text("\"${b.name}\" salondan olib tashlansinmi?"),
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
      await ref.read(shopRepositoryProvider).deleteBarber(b.id);
      ref.invalidate(shopBarbersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }
}
