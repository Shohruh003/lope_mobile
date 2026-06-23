import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

class ShopBarbersScreen extends ConsumerStatefulWidget {
  const ShopBarbersScreen({super.key});

  @override
  ConsumerState<ShopBarbersScreen> createState() => _ShopBarbersScreenState();
}

class _ShopBarbersScreenState extends ConsumerState<ShopBarbersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopBarbersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.shop.masters.title', "Mastera"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.shop.masters.addBtn', "Qo'shish")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (rawList) {
          final list = _query.isEmpty
              ? rawList
              : rawList.where((b) {
                  final q = _query.toLowerCase();
                  return b.name.toLowerCase().contains(q) ||
                      (b.phone ?? '').contains(_query);
                }).toList();
          if (rawList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 60, color: AppColors.textMuted),
                    const SizedBox(height: 14),
                    Text(tr(ref, 'mobile.shop.masters.empty', "Hali masterlar qo'shilmagan"),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(shopBarbersProvider.future),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textBright),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 22),
                    hintText: tr(ref, 'mobile.lopepay.customers.searchHint', "Ism yoki telefon"),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(tr(ref, 'common.noResults', "Hech narsa topilmadi"),
                              style: const TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.push('/shop/barbers/${b.id}'),
                  child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
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
                            Text(tr(ref, 'mobile.shop.masters.experience',
                                'Tajriba: {{value}}', {'value': b.experience}),
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
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
              },
            ),
              ),
            ]),
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
            Text(
                existing == null
                    ? tr(ref, 'mobile.shop.masters.newTitle', "Yangi master")
                    : tr(ref, 'mobile.shop.masters.editTitle', "Tahrirlash"),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: name,
                decoration: InputDecoration(hintText: tr(ref, 'mobile.shop.masters.namePh', "Ism"))),
            const SizedBox(height: 10),
            TextField(
                controller: exp,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.shop.masters.expPh',
                        "Tajriba (masalan: 3 yil)"))),
            const SizedBox(height: 10),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    hintText: tr(ref, 'mobile.shop.masters.phonePh',
                        "Telefon (ixtiyoriy)"))),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                child: Text(tr(ref, 'common.save', "Saqlash")),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ShopBarber b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'mobile.shop.masters.deleteTitle', "Masterni o'chirish?")),
        content: Text(tr(ref, 'mobile.shop.masters.deleteAsk',
            "\"{{name}}\" salondan olib tashlansinmi?", {'name': b.name})),
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
      await ref.read(shopRepositoryProvider).deleteBarber(b.id);
      ref.invalidate(shopBarbersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }
}
