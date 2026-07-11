import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

class BarberReminderSettingsScreen extends ConsumerStatefulWidget {
  const BarberReminderSettingsScreen({super.key});

  @override
  ConsumerState<BarberReminderSettingsScreen> createState() =>
      _BarberReminderSettingsScreenState();
}

class _BarberReminderSettingsScreenState
    extends ConsumerState<BarberReminderSettingsScreen> {
  int _hours = 1;
  int _days = 14;
  int _origHours = 1;
  int _origDays = 14;
  bool _saving = false;
  bool _seeded = false;

  bool get _isDirty => _hours != _origHours || _days != _origDays;

  Future<void> _save(String barberId) async {
    AppHaptics.medium();
    setState(() => _saving = true);
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .updateBarber(barberId, {
        'reminderHoursBefore': _hours,
        'reminderDays': _days,
      });
      ref.invalidate(barberProfileProvider(barberId));
      AppHaptics.success();
      // Reset the baseline so the Save button flips back to disabled
      // until the next edit.
      _origHours = _hours;
      _origDays = _days;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.reminders.title',
              'Eslatma sozlamalari'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _hours =
                ((b['reminderHoursBefore'] ?? 1) as num).toInt().clamp(1, 6);
            _days =
                ((b['reminderDays'] ?? 14) as num).toInt().clamp(7, 30);
            // Baseline so the Save button starts disabled — enables
            // only when the barber actually bumps a stepper.
            _origHours = _hours;
            _origDays = _days;
          }
          final isShopManaged =
              (b['barbershopId'] ?? '').toString().isNotEmpty;
          if (isShopManaged) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderColor:
                      AppColors.primary.withValues(alpha: 0.3),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15),
                              borderRadius: AppRadius.rSm,
                            ),
                            child: const Icon(Icons.info_outline,
                                size: 18, color: AppColors.primary),
                          ),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              tr(
                                  ref,
                                  'reminderSettings.shopManagedTitle',
                                  'Salon eslatma sozlamalarini boshqaradi'),
                              style: AppText.titleSm,
                            ),
                          ),
                        ]),
                        AppSpacing.gapSm,
                        Text(
                          tr(
                              ref,
                              'reminderSettings.shopManagedDescription',
                              'Siz salonga biriktirilgansiz. Eslatmalar vaqti va davri salon profilida belgilanadi.'),
                          style: AppText.bodySm,
                        ),
                      ]),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                tr(ref, 'mobile.barber.reminders.hint',
                    "Mijozlarga SMS bilan eslatma jo'natiladi. Quyida vaqtni va davrni sozlang."),
                style: AppText.bodyLg
                    .copyWith(color: context.colors.textSecondary),
              ),
              AppSpacing.gapXl,
              AppCard(
                variant: AppCardVariant.outlined,
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: 0.15),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: const Icon(Icons.access_time,
                            color: AppColors.primary, size: 18),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          tr(ref, 'mobile.barber.reminders.hoursLabel',
                              'Bron oldidan necha soat'),
                          style: AppText.titleSm,
                        ),
                      ),
                    ]),
                    AppSpacing.gapMd,
                    _Stepper(
                      value: _hours,
                      min: 1,
                      max: 6,
                      suffix: tr(ref,
                          'mobile.barber.reminders.hoursSuffix',
                          ' soat'),
                      onChanged: (v) => setState(() => _hours = v),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapMd,
              AppCard(
                variant: AppCardVariant.outlined,
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.warning
                              .withValues(alpha: 0.15),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: const Icon(Icons.calendar_month,
                            color: AppColors.warning, size: 18),
                      ),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          tr(ref, 'mobile.barber.reminders.daysLabel',
                              'Eslatma davri (kunlarda)'),
                          style: AppText.titleSm,
                        ),
                      ),
                    ]),
                    AppSpacing.gapMd,
                    _Stepper(
                      value: _days,
                      min: 7,
                      max: 30,
                      suffix: tr(ref,
                          'mobile.barber.reminders.daysSuffix', ' kun'),
                      onChanged: (v) => setState(() => _days = v),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: tr(ref, 'common.save', 'Saqlash'),
                leadingIcon: Icons.check,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.lg,
                fullWidth: true,
                loading: _saving,
                onPressed: (_saving || !_isDirty)
                    ? null
                    : () => _save(user.id),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          TapScale(
            onTap: value > min
                ? () {
                    AppHaptics.selection();
                    onChanged(value - 1);
                  }
                : null,
            scale: 0.85,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: value > min
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : context.colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.remove,
                color: value > min
                    ? AppColors.primary
                    : context.colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value$suffix',
                style: AppText.numeric.copyWith(fontSize: 22),
              ),
            ),
          ),
          TapScale(
            onTap: value < max
                ? () {
                    AppHaptics.selection();
                    onChanged(value + 1);
                  }
                : null,
            scale: 0.85,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: value < max
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : context.colors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                color: value < max
                    ? AppColors.primary
                    : context.colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
