import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';

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
      appBar: AppBar(
          title: Text(tr(ref, 'mobile.lopepay.products.title', "Mahsulotlar"),
              style: AppText.titleMd)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {
          AppHaptics.medium();
          _showForm(context, null);
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
            tr(ref, 'mobile.lopepay.products.addBtn', "Mahsulot qo'shish"),
            style: AppText.button.copyWith(color: Colors.white)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.rMd,
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: AppText.body,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textMuted, size: 20),
                hintText:
                    tr(ref, 'mobile.lopepay.products.searchHint', "Mahsulot nomi"),
                hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const AppListSkeleton(),
            error: (e, _) => AppErrorState(
              message: humanize(e),
              onRetry: () {
                ref.invalidate(lopepayProductsFilteredProvider);
                ref.invalidate(lopepayProductsProvider);
              },
            ),
            data: (list) {
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: tr(ref, 'mobile.lopepay.products.empty',
                      "Hali mahsulot yo'q"),
                  message: tr(
                    ref,
                    'mobile.lopepay.products.emptyHint',
                    "Rassrochka uchun mahsulot qo'shsangiz — mijozlarga tanlash imkoniyati beriladi.",
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
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return Opacity(
                      opacity: p.isActive ? 1.0 : 0.6,
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.25),
                                  AppColors.primary.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppRadius.rMd,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.shopping_bag_outlined,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.titleSm),
                                  ),
                                  if (!p.isActive) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    AppBadge(
                                      label: tr(ref,
                                          'mobile.lopepay.products.inactive',
                                          "Faol emas"),
                                      variant: AppBadgeVariant.neutral,
                                    ),
                                  ],
                                ]),
                                if (p.price > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                      "${_fmt(p.price)} ${tr(ref, 'common.currency', "so'm")}",
                                      style: AppText.bodySm.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textBright)),
                                ],
                                Text(
                                    tr(
                                        ref,
                                        'mobile.lopepay.products.usedTimes',
                                        "{{n}} marta ishlatilgan",
                                        {'n': '${p.installmentsCount}'}),
                                    style: AppText.caption),
                              ],
                            ),
                          ),
                          _RoundBtn(
                            icon: Icons.edit_outlined,
                            color: AppColors.textMuted,
                            onTap: () => _showForm(context, p),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _RoundBtn(
                            icon: Icons.delete_outline,
                            color: AppColors.danger,
                            onTap: () => _delete(context, p),
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
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.lg,
            bottom: AppSpacing.xl + MediaQuery.of(sheetCtx).viewInsets.bottom,
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
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.rMd,
                    ),
                    child: Icon(
                        isEdit
                            ? Icons.edit_outlined
                            : Icons.shopping_bag_outlined,
                        color: AppColors.primary,
                        size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                        isEdit
                            ? tr(ref, 'mobile.lopepay.products.editTitle',
                                "Mahsulotni tahrirlash")
                            : tr(ref, 'mobile.lopepay.products.newProduct',
                                "Yangi mahsulot"),
                        style: AppText.titleMd),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                TextField(
                    controller: name,
                    decoration: InputDecoration(
                        hintText:
                            tr(ref, 'mobile.lopepay.products.namePh', "Nomi"))),
                const SizedBox(height: AppSpacing.sm),
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
                    onChanged: (v) {
                      AppHaptics.selection();
                      setSheet(() => active = v);
                    },
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        tr(ref, 'mobile.lopepay.products.active', "Faol"),
                        style: AppText.titleSm.copyWith(fontSize: 14)),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: tr(ref, 'common.save', "Saqlash"),
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  fullWidth: true,
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
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'mobile.lopepay.products.deleteTitle',
                "Mahsulotni o'chirish?"),
            style: AppText.titleMd),
        content: Text(p.name, style: AppText.body),
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
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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

class _RoundBtn extends StatelessWidget {
  const _RoundBtn(
      {required this.icon, required this.color, required this.onTap});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.light,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
