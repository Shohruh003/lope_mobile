import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_panel_repository.dart';

/// Barber / barbershop admin panel screen for declaring vacation
/// ranges. The schedule generator refuses to create slots for any
/// day intersecting a vacation, so booking-blocking is fully
/// backend-enforced — this UI is just the CRUD surface.
///
/// Works for two roles:
///   - Barber viewing themselves — no `barberId` arg, uses the
///     logged-in user's id. Falls under the `barber` role check on
///     the backend.
///   - Shop admin viewing one of their barbers — passes the barber's
///     id via the constructor. Backend `barbershop` role check
///     verifies the barber is under the shop.
class BarberVacationsScreen extends ConsumerWidget {
  const BarberVacationsScreen({super.key, this.barberId});
  final String? barberId;

  static final _ymd = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final effectiveId = barberId ?? user?.id;
    if (effectiveId == null || effectiveId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(ref, 'mobile.barber.vacations.title', "Ta'til kunlari"),
              style: AppText.titleMd),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final async = ref.watch(barberVacationsProvider(effectiveId));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.vacations.title', "Ta'til kunlari"),
            style: AppText.titleMd),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(itemCount: 3),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(barberVacationsProvider(effectiveId)),
        ),
        data: (list) {
          final today = _ymd.format(DateTime.now());
          final upcoming =
              list.where((v) => v.endDate.compareTo(today) >= 0).toList();
          final past =
              list.where((v) => v.endDate.compareTo(today) < 0).toList();
          if (list.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.invalidate(barberVacationsProvider(effectiveId)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.pageBottom(context)),
                children: [
                  SizedBox(
                    height: 360,
                    child: AppEmptyState(
                      icon: Icons.beach_access,
                      title: tr(ref, 'mobile.barber.vacations.empty',
                          "Hali ta'til belgilanmagan"),
                      message: tr(
                          ref,
                          'mobile.barber.vacations.emptyHint',
                          "Ta'til kunlarini oldindan belgilab qo'ying — mijozlar bu kunlarga bron qila olmaydi."),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.invalidate(barberVacationsProvider(effectiveId)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.pageBottom(context)),
              children: [
                if (upcoming.isNotEmpty) ...[
                  Text(
                      tr(
                          ref,
                          'mobile.barber.vacations.upcoming',
                          'Kelayotgan ({{n}})',
                          {'n': '${upcoming.length}'}),
                      style: AppText.overline
                          .copyWith(color: AppColors.primary)),
                  AppSpacing.gapSm,
                  ...upcoming.asMap().entries.map((e) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _VacationRow(
                          v: e.value,
                          barberId: effectiveId,
                          isPast: false,
                        ).animate().fadeIn(
                            duration: 200.ms, delay: (e.key * 25).ms),
                      )),
                  AppSpacing.gapLg,
                ],
                if (past.isNotEmpty) ...[
                  Text(
                      tr(
                          ref,
                          'mobile.barber.vacations.past',
                          "O'tgan ({{n}})",
                          {'n': '${past.length}'}),
                      style: AppText.overline),
                  AppSpacing.gapSm,
                  ...past.asMap().entries.map((e) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _VacationRow(
                          v: e.value,
                          barberId: effectiveId,
                          isPast: true,
                        ),
                      )),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref, effectiveId),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.barber.vacations.add', "Ta'til qo'shish")),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _openAddSheet(
      BuildContext context, WidgetRef ref, String effectiveId) async {
    AppHaptics.selection();
    DateTime? startDate;
    DateTime? endDate;
    final reasonCtrl = TextEditingController();
    var saving = false;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom:
                AppSpacing.lg + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                tr(ref, 'mobile.barber.vacations.add', "Ta'til qo'shish"),
                style: AppText.titleMd,
              ),
              const SizedBox(height: 4),
              Text(
                tr(ref, 'mobile.barber.vacations.addHint',
                    "Ta'til kunlariga mijozlar bron qila olmaydi"),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: _DateField(
                    label: tr(
                        ref, 'mobile.barber.vacations.startDate', 'Boshlanish'),
                    value: startDate,
                    onTap: () async {
                      final picked = await AppDatePicker.show(
                        sheetCtx,
                        ref: ref,
                        initial: startDate ?? DateTime.now(),
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) {
                        setSheet(() {
                          startDate = picked;
                          if (endDate != null &&
                              endDate!.isBefore(picked)) {
                            endDate = picked;
                          }
                        });
                      }
                    },
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: _DateField(
                    label: tr(
                        ref, 'mobile.barber.vacations.endDate', 'Tugash'),
                    value: endDate,
                    onTap: () async {
                      final picked = await AppDatePicker.show(
                        sheetCtx,
                        ref: ref,
                        initial: endDate ?? startDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime.now(),
                        lastDate: DateTime.now()
                            .add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setSheet(() => endDate = picked);
                    },
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              TextField(
                controller: reasonCtrl,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: tr(ref, 'mobile.barber.vacations.reason',
                      'Sabab (ixtiyoriy)'),
                  hintText: tr(ref, 'mobile.barber.vacations.reasonHint',
                      "Masalan: Sayohat, Sport"),
                ),
              ),
              AppSpacing.gapLg,
              AppButton(
                label: tr(ref, 'common.save', 'Saqlash'),
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                loading: saving,
                onPressed: (saving ||
                        startDate == null ||
                        endDate == null)
                    ? null
                    : () async {
                        setSheet(() => saving = true);
                        try {
                          await ref
                              .read(barberPanelRepositoryProvider)
                              .createVacation(
                                barberId: effectiveId,
                                startDate: _ymd.format(startDate!),
                                endDate: _ymd.format(endDate!),
                                reason: reasonCtrl.text.trim(),
                              );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop(true);
                        } catch (e) {
                          setSheet(() => saving = false);
                          if (sheetCtx.mounted) {
                            AppSnack.error(sheetCtx, humanize(e));
                          }
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
    reasonCtrl.dispose();
    if (ok == true) {
      ref.invalidate(barberVacationsProvider(effectiveId));
    }
  }
}

class _VacationRow extends ConsumerWidget {
  const _VacationRow({
    required this.v,
    required this.barberId,
    required this.isPast,
  });
  final BarberVacation v;
  final String barberId;
  final bool isPast;

  static final _pretty = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startD = DateTime.tryParse(v.startDate);
    final endD = DateTime.tryParse(v.endDate);
    final rangeLabel = (startD != null && endD != null)
        ? (v.startDate == v.endDate
            ? _pretty.format(startD)
            : '${_pretty.format(startD)} – ${_pretty.format(endD)}')
        : '${v.startDate} – ${v.endDate}';
    final days = (startD != null && endD != null)
        ? endD.difference(startD).inDays + 1
        : 0;
    final accent = isPast ? context.colors.textMuted : AppColors.warning;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: AppRadius.rSm,
          ),
          child: Icon(Icons.beach_access, color: accent, size: 20),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rangeLabel,
                style: AppText.titleSm
                    .copyWith(color: isPast ? context.colors.textMuted : null),
              ),
              if (days > 0) ...[
                const SizedBox(height: 2),
                Text(
                  tr(ref, 'mobile.barber.vacations.days', '{{n}} kun',
                      {'n': '$days'}),
                  style: AppText.caption,
                ),
              ],
              if ((v.reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(v.reason!, style: AppText.bodySm),
              ],
            ],
          ),
        ),
        if (!isPast)
          IconButton(
            tooltip: tr(ref, 'common.delete', "O'chirish"),
            icon: Icon(Icons.close,
                color: AppColors.danger.withValues(alpha: 0.75), size: 20),
            onPressed: () => _confirmDelete(context, ref),
          ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
          tr(ref, 'mobile.barber.vacations.deleteTitle',
              "Ta'til o'chirilsinmi?"),
          style: AppText.titleMd,
        ),
        content: Text(
          tr(ref, 'mobile.barber.vacations.deleteHint',
              "Ta'til kunlaridagi bloklash olib tashlanadi. Yangi jadval yaratganda bu kunlarga slotlar qayta chiqadi."),
          style: AppText.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', 'Bekor'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(tr(ref, 'common.delete', "O'chirish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(barberPanelRepositoryProvider).deleteVacation(v.id);
      ref.invalidate(barberVacationsProvider(barberId));
      if (context.mounted) {
        AppSnack.success(
            context, tr(ref, 'common.deleted', "O'chirildi"));
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, humanize(e));
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  static final _pretty = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.overline),
            const SizedBox(height: 4),
            Text(
              value == null ? '—' : _pretty.format(value!),
              style: AppText.titleSm,
            ),
          ],
        ),
      ),
    );
  }
}
