import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Mirrors web `ShopProducts.tsx`:
///   - Search input
///   - Add/Edit dialog (name, default price, isActive toggle on edit)
///   - Per-card: icon, name + Inactive badge, price, "{N} marta ishlatildi" count
///   - Pencil (edit) + Trash (delete) actions per card
class LopepayProductsScreen extends ConsumerStatefulWidget {
  const LopepayProductsScreen({super.key});
  @override
  ConsumerState<LopepayProductsScreen> createState() =>
      _LopepayProductsScreenState();
}

class _LopepayProductsScreenState
    extends ConsumerState<LopepayProductsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepayProductsFilteredProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.lopepay.products.title',
          "Mahsulotlar"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, null),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.lopepay.products.addBtn',
            "Mahsulot qo'shish")),
      ),
      body: Column(children: [
        // ===== Search bar =====
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: AppColors.textBright),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 22),
              hintText: tr(ref, 'mobile.lopepay.products.searchHint',
                  "Mahsulot nomi"),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted))),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                        tr(ref, 'mobile.lopepay.products.empty',
                            "Hali mahsulot yo'q"),
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepayProductsFilteredProvider);
                  ref.invalidate(lopepayProductsProvider);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Opacity(
                      opacity: p.isActive ? 1.0 : 0.6,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.shopping_bag_outlined,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16)),
                                  ),
                                  if (!p.isActive) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.textMuted
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                          tr(ref,
                                              'mobile.lopepay.products.inactive',
                                              "Faol emas"),
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ]),
                                if (p.price > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                      "${_fmt(p.price)} ${tr(ref, 'common.currency', "so'm")}",
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13)),
                                ],
                                Text(
                                    tr(ref,
                                        'mobile.lopepay.products.usedTimes',
                                        "{{n}} marta ishlatilgan", {
                                      'n': '${p.installmentsCount}'
                                    }),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.textMuted, size: 20),
                            onPressed: () => _showForm(context, p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.danger, size: 20),
                            onPressed: () => _delete(context, p),
                          ),
                        ]),
                      ),
                    ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _showForm(BuildContext context, LopepayProduct? edit) async {
    final isEdit = edit != null;
    final name = TextEditingController(text: edit?.name ?? '');
    final price = TextEditingController(
        text: edit != null && edit.price > 0 ? edit.price.toString() : '');
    bool active = edit?.isActive ?? true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isEdit
                        ? tr(ref, 'mobile.lopepay.products.editTitle',
                            "Mahsulotni tahrirlash")
                        : tr(ref, 'mobile.lopepay.products.newProduct',
                            "Yangi mahsulot"),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                    controller: name,
                    decoration: InputDecoration(
                        hintText: tr(ref, 'mobile.lopepay.products.namePh',
                            "Nomi"))),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      hintText: tr(ref, 'mobile.lopepay.products.pricePh',
                          "Narxi (so'm)")),
                ),
                if (isEdit) ...[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    value: active,
                    onChanged: (v) => setSheet(() => active = v),
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        tr(ref, 'mobile.lopepay.products.active', "Faol"),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(true),
                    child: Text(tr(ref, 'common.save', "Saqlash")),
                  ),
                ),
              ]),
        );
      }),
    );
    try {
      if (ok != true) return;
      final trimmedName = name.text.trim();
      if (trimmedName.isEmpty) return;
      final parsedPrice = int.tryParse(price.text.trim());
      final repo = ref.read(lopepayRepositoryProvider);
      if (isEdit) {
        await repo.updateProduct(edit.id,
            name: trimmedName, defaultPrice: parsedPrice, isActive: active);
      } else {
        await repo.createProduct(
            name: trimmedName, defaultPrice: parsedPrice);
      }
      ref.invalidate(lopepayProductsFilteredProvider);
      ref.invalidate(lopepayProductsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    } finally {
      name.dispose();
      price.dispose();
    }
  }

  Future<void> _delete(BuildContext context, LopepayProduct p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'mobile.lopepay.products.deleteTitle',
            "Mahsulotni o'chirish?")),
        content: Text(p.name),
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
      await ref.read(lopepayRepositoryProvider).deleteProduct(p.id);
      ref.invalidate(lopepayProductsFilteredProvider);
      ref.invalidate(lopepayProductsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    }
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
