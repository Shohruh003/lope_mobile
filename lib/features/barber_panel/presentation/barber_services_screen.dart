import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/barber_profile_repository.dart';

class BarberServicesScreen extends ConsumerWidget {
  const BarberServicesScreen({super.key, required this.barberId});
  final String barberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberServicesProvider(barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.services.title', 'Xizmatlarim'),
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
              tr(ref, 'mobile.barber.services.addBtn', 'Yangi xizmat'),
              style: AppText.button.copyWith(color: Colors.white),
            ),
          ]),
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.content_cut_rounded,
              title: tr(ref, 'mobile.barber.services.empty',
                  "Hali xizmat qo'shilmagan"),
              message: tr(ref, 'mobile.barber.services.emptyHint',
                  "Pastdagi tugma orqali qo'shing"),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.refresh(barberServicesProvider(barberId).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final svc = list[i];
                final name =
                    (svc['nameUz'] ?? svc['name'] ?? '').toString();
                final price = ((svc['price'] ?? 0) as num).toInt();
                final dur = ((svc['duration'] ?? 30) as num).toInt();
                final iconText = (svc['icon'] ?? '').toString();
                return AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.rMd,
                        ),
                        alignment: Alignment.center,
                        child: iconText.isNotEmpty
                            ? Text(iconText,
                                style: const TextStyle(fontSize: 26))
                            : const Icon(Icons.content_cut,
                                color: AppColors.primary, size: 24),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: AppText.titleSm),
                            const SizedBox(height: 2),
                            Row(children: [
                              Text(
                                "${_fmt(price)} ${tr(ref, 'common.currency', "so'm")}",
                                style: AppText.body.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              AppSpacing.hGapSm,
                              Text('·', style: AppText.caption),
                              AppSpacing.hGapSm,
                              const Icon(Icons.access_time_outlined,
                                  size: 12,
                                  color: AppColors.textMuted),
                              AppSpacing.hGapXs,
                              Text(
                                "$dur ${tr(ref, 'booking.duration', 'daq')}",
                                style: AppText.caption,
                              ),
                            ]),
                          ],
                        ),
                      ),
                      TapScale(
                        onTap: () =>
                            _openEditor(context, ref, existing: svc),
                        scale: 0.9,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_outlined,
                              color: AppColors.textSecondary, size: 18),
                        ),
                      ),
                      AppSpacing.hGapXs,
                      TapScale(
                        onTap: () => _confirmDelete(context, ref, svc),
                        scale: 0.9,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_outline,
                              color: AppColors.danger, size: 18),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (i * 40).ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    AppHaptics.light();
    final name = TextEditingController(
        text: (existing?['nameUz'] ?? existing?['name'] ?? '').toString());
    final nameRu =
        TextEditingController(text: (existing?['nameRu'] ?? '').toString());
    final icon =
        TextEditingController(text: (existing?['icon'] ?? '').toString());
    final price =
        TextEditingController(text: existing?['price']?.toString() ?? '');
    final priceMax = TextEditingController(
        text: existing?['priceMax']?.toString() ?? '');
    final dur = TextEditingController(
        text: existing?['duration']?.toString() ?? '30');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => Padding(
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
                  color: AppColors.border,
                  borderRadius: AppRadius.rPill,
                ),
              ),
            ),
            AppSpacing.gapMd,
            Text(
              existing == null
                  ? tr(ref, 'mobile.barber.services.newTitle',
                      'Yangi xizmat')
                  : tr(ref, 'mobile.barber.services.editTitle',
                      'Xizmatni tahrirlash'),
              style: AppText.titleMd,
            ),
            AppSpacing.gapLg,
            Row(children: [
              SizedBox(
                width: 68,
                child: TextField(
                  controller: icon,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26),
                  decoration: const InputDecoration(
                    hintText: '✂️',
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: TextField(
                  controller: name,
                  style: AppText.body,
                  decoration: InputDecoration(
                    labelText: tr(ref,
                        'mobile.barber.services.namePh', 'Nomi (UZ)'),
                  ),
                ),
              ),
            ]),
            AppSpacing.gapSm,
            TextField(
              controller: nameRu,
              style: AppText.body,
              decoration: const InputDecoration(
                  labelText: 'Название (RU)', hintText: 'Стрижка'),
            ),
            AppSpacing.gapMd,
            Row(children: [
              Expanded(
                child: TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  style: AppText.body,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'mobile.barber.services.pricePh',
                        "Narxi (so'm)"),
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: TextField(
                  controller: priceMax,
                  keyboardType: TextInputType.number,
                  style: AppText.body,
                  decoration: InputDecoration(
                    labelText: tr(
                        ref,
                        'mobile.barber.services.priceMaxPh',
                        'Maks (ixtiyoriy)'),
                  ),
                ),
              ),
            ]),
            AppSpacing.gapMd,
            TextField(
              controller: dur,
              keyboardType: TextInputType.number,
              style: AppText.body,
              decoration: InputDecoration(
                labelText: tr(ref,
                    'mobile.barber.services.durationPh',
                    'Davomiyligi (daqiqa)'),
              ),
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
    );
    try {
      if (result != true) return;
      final pMax = int.tryParse(priceMax.text.trim());
      final iconText = icon.text.trim();
      final nameRuText = nameRu.text.trim();
      final body = <String, dynamic>{
        'nameUz': name.text.trim(),
        'name': name.text.trim(),
        'nameRu': nameRuText,
        'icon': iconText.isEmpty ? '✂️' : iconText,
        'price': int.tryParse(price.text.trim()) ?? 0,
        'priceMax': pMax != null && pMax > 0 ? pMax : null,
        'duration': int.tryParse(dur.text.trim()) ?? 30,
      };
      final repo = ref.read(barberProfileRepositoryProvider);
      if (existing == null) {
        await repo.createService(barberId, body);
      } else {
        await repo.updateService(barberId, existing['id'] as String, body);
      }
      AppHaptics.success();
      ref.invalidate(barberServicesProvider(barberId));
    } catch (e) {
      AppHaptics.error();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      name.dispose();
      nameRu.dispose();
      icon.dispose();
      price.dispose();
      priceMax.dispose();
      dur.dispose();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      Map<String, dynamic> svc) async {
    AppHaptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.barber.services.deleteTitle',
                    "Xizmatni o'chirish?"),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(
                    ref,
                    'mobile.barber.services.deleteAsk',
                    '"{{name}}" o\'chirilsinmi?',
                    {
                      'name': (svc['nameUz'] ?? svc['name'] ?? '')
                          .toString()
                    }),
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
      await ref
          .read(barberProfileRepositoryProvider)
          .deleteService(barberId, svc['id'] as String);
      ref.invalidate(barberServicesProvider(barberId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
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
