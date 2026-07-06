import 'package:dio/dio.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Mirrors web `BarbershopAdmins.tsx` — owner can create new admin
/// accounts (name + phone + password), edit existing ones (incl.
/// password reset), and remove non-owner admins.
class ShopAdminsScreen extends ConsumerStatefulWidget {
  const ShopAdminsScreen({super.key});
  @override
  ConsumerState<ShopAdminsScreen> createState() => _ShopAdminsScreenState();
}

class _ShopAdminsScreenState extends ConsumerState<ShopAdminsScreen> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_adminsProvider(_page));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'shop.nav.admins', "Adminlar"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(tr(ref, 'mobile.shop.admins.addBtn', "Admin qo'shish")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (res) {
          final list = res.data;
          final pages = res.totalPages;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    tr(ref, 'mobile.shop.admins.empty',
                        "Hali admin qo'shilmagan"),
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_adminsProvider(_page).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...list.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  // Backend returns {isOwner: true} on the owner row
                  // (barbershop.service.ts:694) — never a `role` key.
                  // Reading 'role' meant the OWNER badge never lit up and
                  // shop-admins always appeared as ADMIN.
                  final isOwner = a['isOwner'] == true;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
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
                            color: (isOwner
                                    ? AppColors.warning
                                    : AppColors.primary)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                              isOwner
                                  ? Icons.workspace_premium
                                  : Icons.admin_panel_settings,
                              color: isOwner
                                  ? AppColors.warning
                                  : AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((a['name'] ?? '').toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14)),
                              const SizedBox(height: 2),
                              Text((a['phone'] ?? '').toString(),
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isOwner
                                    ? AppColors.warning
                                    : AppColors.primary)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(isOwner ? "OWNER" : "ADMIN",
                              style: TextStyle(
                                  color: isOwner
                                      ? AppColors.warning
                                      : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                        ),
                        if (!isOwner) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.textSecondary, size: 20),
                            onPressed: () =>
                                _openForm(context, ref, existing: a),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.danger, size: 20),
                            onPressed: () =>
                                _remove(context, ref, a['id'].toString()),
                          ),
                        ],
                      ]),
                    ),
                  ).animate().fadeIn(
                      duration: 200.ms, delay: (i * 20).ms);
                }),
                if (pages > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _page <= 1
                            ? null
                            : () => setState(() => _page--),
                        child: Text(tr(ref, 'common.prev', "Oldingi")),
                      ),
                      const SizedBox(width: 12),
                      Text("$_page / $pages",
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _page >= pages
                            ? null
                            : () => setState(() => _page++),
                        child: Text(tr(ref, 'common.next', "Keyingi")),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final name =
        TextEditingController(text: (existing?['name'] ?? '').toString());
    final phone =
        TextEditingController(text: (existing?['phone'] ?? '').toString());
    final password = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
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
                      ? tr(ref, 'mobile.shop.admins.editTitle',
                          "Adminni tahrirlash")
                      : tr(ref, 'mobile.shop.admins.addBtn',
                          "Admin qo'shish"),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                decoration: InputDecoration(
                    labelText:
                        tr(ref, 'shop.client.name', "Ism"),
                    hintText: "Shohruh Azimov"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                    labelText: tr(ref, 'shop.client.phone', "Telefon"),
                    hintText: '+998 90 123 45 67'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: isEdit
                        ? tr(ref, 'mobile.shop.admins.newPassword',
                            "Yangi parol (ixtiyoriy)")
                        : tr(ref, 'auth.password', "Parol"),
                    hintText: "********"),
              ),
              if (!isEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      tr(ref, 'auth.shortPassword',
                          "Parol kamida 6 belgi"),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                  child: Text(tr(ref, 'common.save', "Saqlash")),
                ),
              ),
            ]),
      ),
    );
    if (ok != true) {
      // Modal dismissed without saving — still clean up so we don't leak
      // the three controllers on every cancel.
      name.dispose();
      phone.dispose();
      password.dispose();
      return;
    }
    final n = name.text.trim();
    final p = phone.text.trim();
    final pw = password.text;
    try {
      if (!isEdit && (n.isEmpty || p.isEmpty || pw.length < 6)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'mobile.shop.admins.fillAll',
                "Barcha maydonlar majburiy (parol ≥ 6 belgi)"))));
        return;
      }
      final dio = ref.read(dioProvider);
      if (isEdit) {
        await dio.patch('/barbershop/admins/${existing['id']}', data: {
          'name': ?(n.isEmpty ? null : n),
          'phone': ?(p.isEmpty ? null : p),
          'password': ?(pw.isEmpty ? null : pw),
        });
      } else {
        await dio.post('/barbershop/admins', data: {
          'name': n,
          'phone': p,
          'password': pw,
        });
      }
      ref.invalidate(_adminsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    } finally {
      // Always release the controllers after the save attempt — they
      // were allocated locally in this method.
      name.dispose();
      phone.dispose();
      password.dispose();
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'mobile.shop.admins.removeTitle',
            "Adminni olib tashlash?")),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'mobile.shop.admins.removeBtn',
                "Olib tashlash")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/barbershop/admins/$id');
      ref.invalidate(_adminsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }
}

final _adminsProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total, int totalPages}),
    int>((ref, page) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershop/admins',
      queryParameters: {'page': page, 'limit': 20});
  final data = res.data;
  final list = (data is List)
      ? data
      : (data is Map && data['data'] is List ? data['data'] as List : <dynamic>[]);
  final meta = data is Map && data['meta'] is Map
      ? (data['meta'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  return (
    data: list.cast<Map<String, dynamic>>(),
    total: ((meta['total'] ?? list.length) as num).toInt(),
    totalPages: ((meta['totalPages'] ?? 1) as num).toInt(),
  );
});
