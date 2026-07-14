import 'package:dio/dio.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';

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
      appBar: AppBar(
          title: Text(tr(ref, 'shop.nav.admins', "Adminlar"),
              style: AppText.titleMd)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () {
          AppHaptics.medium();
          _openForm(context, ref);
        },
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(tr(ref, 'mobile.shop.admins.addBtn', "Admin qo'shish"),
            style: AppText.button.copyWith(color: Colors.white)),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(_adminsProvider),
        ),
        data: (res) {
          final list = res.data;
          final pages = res.totalPages;
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: tr(ref, 'mobile.shop.admins.empty',
                  "Hali admin qo'shilmagan"),
              message: tr(
                ref,
                'mobile.shop.admins.emptyHint',
                "Yordamchi admin qo'shsangiz — u ham salon bilan boshqara oladi.",
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_adminsProvider(_page).future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ...list.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  final isOwner = a['isOwner'] == true;
                  final tint =
                      isOwner ? AppColors.warning : AppColors.primary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                                tint.withValues(alpha: 0.25),
                                tint.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                              isOwner
                                  ? Icons.workspace_premium
                                  : Icons.admin_panel_settings,
                              color: tint,
                              size: 20),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((a['name'] ?? '').toString(),
                                  style: AppText.titleSm
                                      .copyWith(fontSize: 14)),
                              const SizedBox(height: 2),
                              Text((a['phone'] ?? '').toString(),
                                  style: AppText.caption),
                            ],
                          ),
                        ),
                        AppBadge(
                          label: isOwner ? "OWNER" : "ADMIN",
                          variant: isOwner
                              ? AppBadgeVariant.warning
                              : AppBadgeVariant.info,
                        ),
                        if (!isOwner) ...[
                          const SizedBox(width: AppSpacing.xs),
                          _RoundBtn(
                            icon: Icons.edit_outlined,
                            color: context.colors.textSecondary,
                            onTap: () =>
                                _openForm(context, ref, existing: a),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _RoundBtn(
                            icon: Icons.delete_outline,
                            color: AppColors.danger,
                            onTap: () =>
                                _remove(context, ref, a['id'].toString()),
                          ),
                        ],
                      ]),
                    ),
                  ).animate().fadeIn(
                      duration: 200.ms, delay: (i * 20).ms);
                }),
                if (pages > 1) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppButton(
                        label: tr(ref, 'common.prev', "Oldingi"),
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        leadingIcon: Icons.chevron_left,
                        onPressed: _page <= 1
                            ? null
                            : () => setState(() => _page--),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.rPill,
                        ),
                        child: Text("$_page / $pages",
                            style: AppText.button
                                .copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppButton(
                        label: tr(ref, 'common.next', "Keyingi"),
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        trailingIcon: Icons.chevron_right,
                        onPressed: _page >= pages
                            ? null
                            : () => setState(() => _page++),
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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => Padding(
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
                        color: context.colors.border,
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
                      isEdit ? Icons.edit_outlined : Icons.person_add_alt_1,
                      color: AppColors.primary,
                      size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                      isEdit
                          ? tr(ref, 'mobile.shop.admins.editTitle',
                              "Adminni tahrirlash")
                          : tr(ref, 'mobile.shop.admins.addBtn',
                              "Admin qo'shish"),
                      style: AppText.titleMd),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: tr(ref, 'shop.client.name', "Ism"),
                  hintText:
                      tr(ref, 'shop.client.nameHint', "Familya Ism"),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Prefer AppPhoneField over a raw TextField so the
              // '+998' prefix is always pinned and paste normalises
              // any accepted format into `+998 XX-XXX-XX-XX`. Save
              // path uses AppPhoneField.rawPhone(phone.text) to send
              // canonical `+998XXXXXXXXX` to the backend.
              AppPhoneField(
                controller: phone,
                hintText: '+998 XX-XXX-XX-XX',
              ),
              const SizedBox(height: AppSpacing.sm),
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
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                      tr(ref, 'auth.shortPassword',
                          "Parol kamida 6 belgi"),
                      style: AppText.caption),
                ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: tr(ref, 'common.save', "Saqlash"),
                onPressed: () => Navigator.of(sheetCtx).pop(true),
                fullWidth: true,
              ),
            ]),
      ),
    );
    if (ok != true) {
      name.dispose();
      phone.dispose();
      password.dispose();
      return;
    }
    final n = name.text.trim();
    // Send the canonical `+998XXXXXXXXX` string — AppPhoneField's
    // rendered value has spaces and dashes that aren't valid E.164.
    final p = AppPhoneField.rawPhone(phone.text);
    final pw = password.text;
    try {
      if (!isEdit && (n.isEmpty || p.isEmpty || pw.length < 6)) {
        if (!context.mounted) return;
        AppSnack.warning(
            context,
            tr(ref, 'mobile.shop.admins.fillAll',
                "Barcha maydonlar majburiy (parol ≥ 6 belgi)"));
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
      if (context.mounted) {
        AppSnack.success(context, tr(ref, 'common.saved', 'Saqlandi'));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
    } finally {
      name.dispose();
      phone.dispose();
      password.dispose();
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'mobile.shop.admins.removeTitle',
                "Adminni olib tashlash?"),
            style: AppText.titleMd),
        content: Text(
          tr(ref, 'mobile.shop.admins.removeBody',
              "Bu admin salon boshqaruvidan olib tashlanadi. Bu jarayonni bekor qilib bo'lmaydi."),
          style: AppText.bodySm,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.no', "Yo'q"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'common.yes', 'Ha')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).delete('/barbershop/admins/$id');
      ref.invalidate(_adminsProvider);
      if (context.mounted) {
        AppSnack.success(context,
            tr(ref, 'mobile.shop.admins.removed', 'Admin olib tashlandi'));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
    }
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
      // 44px hit area (Material touch-target minimum) with a smaller
      // visual pill inside — keeps the row layout compact while
      // meeting the accessibility target.
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
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
