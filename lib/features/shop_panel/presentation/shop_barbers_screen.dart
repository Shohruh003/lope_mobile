import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

class ShopBarbersScreen extends ConsumerStatefulWidget {
  const ShopBarbersScreen({super.key});

  @override
  ConsumerState<ShopBarbersScreen> createState() =>
      _ShopBarbersScreenState();
}

class _ShopBarbersScreenState extends ConsumerState<ShopBarbersScreen> {
  String _query = '';
  int _page = 1;

  ShopBarbersKey get _key => (
        search: _query.isEmpty ? null : _query,
        page: _page,
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopBarbersPagedProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.shop.masters.title', 'Mastera'),
          style: AppText.titleMd,
        ),
      ),
      floatingActionButton: TapScale(
        onTap: () => _openEditor(context, ref),
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.rPill,
            boxShadow: AppShadows.primaryGlow(AppColors.primary),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add, color: Colors.white, size: 20),
            AppSpacing.hGapSm,
            Text(
              tr(ref, 'mobile.shop.masters.addBtn', "Qo'shish"),
              style: AppText.button.copyWith(color: Colors.white),
            ),
          ]),
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (res) {
          final list = res.data;
          final totalPages = res.totalPages;
          if (list.isEmpty && _query.isEmpty && _page == 1) {
            return AppEmptyState(
              icon: Icons.people_alt_outlined,
              title: tr(ref, 'mobile.shop.masters.empty',
                  "Hali masterlar qo'shilmagan"),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(shopBarbersPagedProvider);
              ref.invalidate(shopBarbersProvider);
            },
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _query = v;
                      _page = 1;
                    }),
                    style: AppText.body,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      prefixIcon: Icon(Icons.search,
                          color: context.colors.textMuted, size: 20),
                      hintText: tr(ref,
                          'mobile.lopepay.customers.searchHint',
                          'Ism yoki telefon'),
                      hintStyle: AppText.body
                          .copyWith(color: context.colors.textMuted),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? AppEmptyState(
                        icon: Icons.search_off,
                        title: tr(ref, 'common.noResults',
                            'Hech narsa topilmadi'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          96,
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => AppSpacing.gapSm,
                        itemBuilder: (context, i) {
                          final b = list[i];
                          return AppCard(
                            variant: AppCardVariant.outlined,
                            padding: AppSpacing.cardPadding,
                            onTap: () =>
                                context.push('/shop/barbers/${b.id}'),
                            child: Row(children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child: (b.avatar != null &&
                                          b.avatar!.isNotEmpty)
                                      ? CachedNetworkImage(
                                          imageUrl: assetUrl(b.avatar),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          placeholder: (_, _) =>
                                              const SkeletonCircle(
                                                  size: 48),
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          color: context.colors.surface,
                                          alignment: Alignment.center,
                                          child: Text(
                                            (b.name.isNotEmpty
                                                    ? b.name[0]
                                                    : '?')
                                                .toUpperCase(),
                                            style: AppText.titleMd,
                                          ),
                                        ),
                                ),
                              ),
                              AppSpacing.hGapMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(b.name,
                                        style: AppText.titleSm),
                                    if (b.experience.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        tr(
                                            ref,
                                            'mobile.shop.masters.experience',
                                            'Tajriba: {{value}}',
                                            {
                                              'value': b.experience
                                            }),
                                        style: AppText.caption,
                                      ),
                                    ],
                                    if (b.phone?.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 2),
                                      Text(b.phone!,
                                          style: AppText.caption),
                                    ],
                                  ],
                                ),
                              ),
                              AppSpacing.hGapSm,
                              TapScale(
                                onTap: () => _openEditor(context, ref,
                                    existing: b),
                                scale: 0.9,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceElevated,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                      Icons.edit_outlined,
                                      color:
                                          context.colors.textSecondary,
                                      size: 18),
                                ),
                              ),
                              AppSpacing.hGapXs,
                              TapScale(
                                onTap: () =>
                                    _confirmDelete(context, ref, b),
                                scale: 0.9,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.danger,
                                      size: 18),
                                ),
                              ),
                            ]),
                          )
                              .animate()
                              .fadeIn(
                                  duration: 250.ms,
                                  delay: (i * 30).ms)
                              .slideY(begin: 0.1, end: 0);
                        },
                      ),
              ),
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppButton(
                        label: tr(ref, 'common.prev', 'Oldingi'),
                        leadingIcon: Icons.chevron_left,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        onPressed: _page <= 1
                            ? null
                            : () => setState(() => _page--),
                      ),
                      AppSpacing.hGapMd,
                      Text(
                        '$_page / $totalPages',
                        style: AppText.body.copyWith(
                          color: context.colors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AppSpacing.hGapMd,
                      AppButton(
                        label: tr(ref, 'common.next', 'Keyingi'),
                        trailingIcon: Icons.chevron_right,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        onPressed: _page >= totalPages
                            ? null
                            : () => setState(() => _page++),
                      ),
                    ],
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {ShopBarber? existing}) async {
    AppHaptics.light();
    final name = TextEditingController(text: existing?.name ?? '');
    final exp = TextEditingController(text: existing?.experience ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    String? gender =
        (existing?.gender == 'MALE' || existing?.gender == 'FEMALE')
            ? existing!.gender
            : null;
    String role = existing?.role == 'stylist'
        ? 'stylist'
        : existing?.role == 'cosmetologist'
            ? 'cosmetologist'
            : 'barber';
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                    color: context.colors.border,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
              ),
              AppSpacing.gapMd,
              Text(
                existing == null
                    ? tr(ref, 'mobile.shop.masters.newTitle',
                        'Yangi master')
                    : tr(ref, 'mobile.shop.masters.editTitle',
                        'Tahrirlash'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapLg,
              TextField(
                controller: name,
                style: AppText.body,
                decoration: InputDecoration(
                  labelText:
                      tr(ref, 'mobile.shop.masters.namePh', 'Ism'),
                ),
              ),
              AppSpacing.gapSm,
              TextField(
                controller: exp,
                style: AppText.body,
                decoration: InputDecoration(
                  labelText: tr(ref, 'mobile.shop.masters.expPh',
                      'Tajriba (masalan: 3 yil)'),
                ),
              ),
              AppSpacing.gapSm,
              AppPhoneField(
                controller: phone,
                hintText: tr(ref, 'mobile.shop.masters.phonePh',
                    'Telefon (ixtiyoriy)'),
              ),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'mobile.shop.masters.gender', 'Jinsi'),
                style: AppText.overline,
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: _PickerBtn(
                    label:
                        "👨 ${tr(ref, 'admin.filterGenderMale', 'Erkak')}",
                    on: gender == 'MALE',
                    onTap: () => setSheetState(() =>
                        gender = gender == 'MALE' ? null : 'MALE'),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _PickerBtn(
                    label:
                        "👩 ${tr(ref, 'admin.filterGenderFemale', 'Ayol')}",
                    on: gender == 'FEMALE',
                    onTap: () => setSheetState(() => gender =
                        gender == 'FEMALE' ? null : 'FEMALE'),
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'mobile.shop.masters.role', 'Kasbi'),
                style: AppText.overline,
              ),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: _PickerBtn(
                    label: tr(ref, 'auth.roleBarber', 'Sartarosh'),
                    on: role == 'barber',
                    onTap: () =>
                        setSheetState(() => role = 'barber'),
                  ),
                ),
                AppSpacing.hGapXs,
                Expanded(
                  child: _PickerBtn(
                    label: tr(ref, 'auth.roleStylist', 'Stilist'),
                    on: role == 'stylist',
                    onTap: () =>
                        setSheetState(() => role = 'stylist'),
                  ),
                ),
                AppSpacing.hGapXs,
                Expanded(
                  child: _PickerBtn(
                    label: tr(ref, 'auth.roleCosmetologist',
                        'Kosmetolog'),
                    on: role == 'cosmetologist',
                    onTap: () => setSheetState(
                        () => role = 'cosmetologist'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                tr(ref, 'mobile.shop.masters.roleHint',
                    "Mijozlarga yuboriladigan SMS'da shu so'z ishlatiladi."),
                style: AppText.caption,
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
      ),
    );
    try {
      if (result != true) return;
      final repo = ref.read(shopRepositoryProvider);
      // Canonical +998XXXXXXXXX (empty when the field wasn't filled).
      final canonicalPhone = AppPhoneField.rawPhone(phone.text);
      if (existing == null) {
        await repo.createBarber(
          name: name.text.trim(),
          experience: exp.text.trim(),
          phone: canonicalPhone,
          gender: gender,
          role: role,
        );
      } else {
        await repo.updateBarber(existing.id, {
          'name': name.text.trim(),
          'experience': exp.text.trim(),
          if (canonicalPhone.isNotEmpty) 'phone': canonicalPhone,
          if (gender == 'MALE' || gender == 'FEMALE')
            'gender': gender,
          'role': role,
        });
      }
      AppHaptics.success();
      ref.invalidate(shopBarbersProvider);
      ref.invalidate(shopBarbersPagedProvider);
    } catch (e) {
      AppHaptics.error();
      if (context.mounted) {
        AppSnack.error(context, humanize(e));
      }
    } finally {
      name.dispose();
      exp.dispose();
      phone.dispose();
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ShopBarber b) async {
    AppHaptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.shop.masters.deleteTitle',
                    "Masterni o'chirish?"),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(
                    ref,
                    'mobile.shop.masters.deleteAsk',
                    '"{{name}}" salondan olib tashlansinmi?',
                    {'name': b.name}),
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
      await ref.read(shopRepositoryProvider).deleteBarber(b.id);
      ref.invalidate(shopBarbersProvider);
      ref.invalidate(shopBarbersPagedProvider);
      if (context.mounted) {
        AppSnack.success(context,
            tr(ref, 'mobile.shop.masters.removed', 'Master olib tashlandi'));
      }
    } catch (e) {
      if (context.mounted) {
        AppSnack.error(context, humanize(e));
      }
    }
  }
}

class _PickerBtn extends StatelessWidget {
  const _PickerBtn({
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      scale: 0.96,
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          gradient: on ? AppColors.primaryGradient : null,
          color: on ? null : context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: on ? AppColors.primary : context.colors.border,
            width: on ? 2 : 1,
          ),
          boxShadow:
              on ? AppShadows.primaryGlow(AppColors.primary) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(
            color: on ? Colors.white : context.colors.textPrimary,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
