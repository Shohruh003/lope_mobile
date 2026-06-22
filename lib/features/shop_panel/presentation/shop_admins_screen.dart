import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Salon admins multi-management. Owner can add/remove admins; admins
/// themselves see read-only.
class ShopAdminsScreen extends ConsumerWidget {
  const ShopAdminsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_adminsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text("Adminlar")),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text("Admin qo'shish"),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text("Hali admin qo'shilmagan", style: TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_adminsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = list[i];
                final isOwner = a['role'] == 'owner';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (isOwner ? AppColors.warning : AppColors.primary).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(isOwner ? Icons.workspace_premium : Icons.admin_panel_settings,
                          color: isOwner ? AppColors.warning : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((a['name'] ?? '').toString(),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text((a['phone'] ?? '').toString(),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOwner ? AppColors.warning : AppColors.primary).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isOwner ? "OWNER" : "ADMIN",
                          style: TextStyle(
                              color: isOwner ? AppColors.warning : AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (!isOwner) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                        onPressed: () => _remove(context, ref, a['id'].toString()),
                      ),
                    ],
                  ]),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final phone = TextEditingController();
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
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Admin qo'shish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Foydalanuvchi telefon raqamini kiriting — u akkauntda ro'yxatdan o'tgan bo'lishi kerak",
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: "+998 90 123 45 67"),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(true),
              child: const Text("Qo'shish"),
            ),
          ),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/barbershop/admins', data: {'phone': phone.text.trim()});
      ref.invalidate(_adminsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Adminni olib tashlash?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text("Bekor")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text("Olib tashlash"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/barbershop/admins/$id');
      ref.invalidate(_adminsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
  }
}

final _adminsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershop/admins');
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
  return list.cast<Map<String, dynamic>>();
});
