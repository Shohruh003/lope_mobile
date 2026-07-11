import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sms_history_repository.dart';

class BarberSmsHistoryScreen extends ConsumerStatefulWidget {
  const BarberSmsHistoryScreen({super.key});

  @override
  ConsumerState<BarberSmsHistoryScreen> createState() =>
      _BarberSmsHistoryScreenState();
}

class _BarberSmsHistoryScreenState
    extends ConsumerState<BarberSmsHistoryScreen> {
  // Locale-neutral formatters — the previous ru_RU version left the
  // timestamps looking like Russian localisation on a UZ-first app.
  static final _df = DateFormat('dd.MM.yyyy HH:mm');
  static final _dateOnly = DateFormat('yyyy-MM-dd');

  String _type = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;

  Future<void> _pickDate(bool isFrom) async {
    AppHaptics.light();
    final initial = (isFrom ? _from : _to) ?? DateTime.now();
    final first = DateTime(2024);
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final key = (
      barberId: user.id,
      type: _type == 'all' ? null : _type,
      from: _from == null ? null : _dateOnly.format(_from!),
      to: _to == null ? null : _dateOnly.format(_to!),
      page: _page,
    );
    final async = ref.watch(smsHistoryFilteredProvider(key));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.sms.title', 'SMS tarixi'),
          style: AppText.titleMd,
        ),
      ),
      body: Column(
        children: [
          _FilterBar(
            type: _type,
            from: _from,
            to: _to,
            allLabel: tr(ref, 'common.all', 'Hammasi'),
            confirmLabel: tr(
                ref, 'mobile.barber.sms.typeConfirm', 'Tasdiqlash'),
            reminderLabel:
                tr(ref, 'mobile.barber.sms.typeReminder', 'Eslatma'),
            retentionLabel: tr(
                ref, 'mobile.barber.sms.typeRetention', 'Qayta jalb'),
            onType: (v) => setState(() {
              _type = v;
              _page = 1;
            }),
            onFromTap: () => _pickDate(true),
            onToTap: () => _pickDate(false),
            onClearDates: () => setState(() {
              _from = null;
              _to = null;
              _page = 1;
            }),
          ),
          Expanded(
            child: async.when(
              loading: () => const AppListSkeleton(),
              error: (e, _) => AppErrorState(message: humanize(e)),
              data: (list) {
                if (list.isEmpty) {
                  // Wrap the empty state in a scrollable so pull-to-
                  // refresh works — otherwise the barber has no way
                  // to force a re-fetch after a bad filter change.
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.refresh(
                        smsHistoryFilteredProvider(key).future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: 400,
                          child: AppEmptyState(
                            icon: Icons.sms_outlined,
                            title: tr(ref, 'mobile.barber.sms.empty',
                                "SMS yo'q"),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref
                      .refresh(smsHistoryFilteredProvider(key).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => AppSpacing.gapSm,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final ok = s.status == 'delivered' ||
                          s.status == 'sent' ||
                          s.status == 'success';
                      return AppCard(
                        variant: AppCardVariant.outlined,
                        padding: AppSpacing.cardPadding,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(s.phone,
                                      style: AppText.titleSm),
                                ),
                                if ((s.type ?? '').isNotEmpty) ...[
                                  AppBadge(
                                    // Route the English enum ('confirmation',
                                    // 'reminder', 'retention') through the
                                    // same tr labels already defined for the
                                    // filter chips so the badge shows Uzbek
                                    // ("Tasdiqlash / Eslatma / Qayta jalb")
                                    // instead of raw backend strings.
                                    label: switch (s.type!.toLowerCase()) {
                                      'confirmation' => tr(
                                          ref,
                                          'mobile.barber.sms.typeConfirm',
                                          'Tasdiqlash'),
                                      'reminder' => tr(
                                          ref,
                                          'mobile.barber.sms.typeReminder',
                                          'Eslatma'),
                                      'retention' => tr(
                                          ref,
                                          'mobile.barber.sms.typeRetention',
                                          'Qayta jalb'),
                                      _ => s.type!,
                                    },
                                    variant: AppBadgeVariant.info,
                                  ),
                                  AppSpacing.hGapXs,
                                ],
                                AppBadge(
                                  label: ok
                                      ? tr(
                                          ref,
                                          'mobile.barber.sms.statusOk',
                                          'delivered')
                                      : tr(
                                          ref,
                                          'mobile.barber.sms.statusFail',
                                          'failed'),
                                  variant: ok
                                      ? AppBadgeVariant.success
                                      : AppBadgeVariant.danger,
                                  dot: true,
                                ),
                              ],
                            ),
                            AppSpacing.gapSm,
                            Container(
                              padding: const EdgeInsets.all(
                                  AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceElevated,
                                borderRadius: AppRadius.rSm,
                              ),
                              child: Text(
                                s.message,
                                style: AppText.bodySm.copyWith(
                                  color: context.colors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            AppSpacing.gapXs,
                            Text(_df.format(s.createdAt.toLocal()),
                                style: AppText.caption),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                              duration: 250.ms, delay: (i * 30).ms)
                          .slideY(begin: 0.1, end: 0);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.type,
    required this.from,
    required this.to,
    required this.allLabel,
    required this.confirmLabel,
    required this.reminderLabel,
    required this.retentionLabel,
    required this.onType,
    required this.onFromTap,
    required this.onToTap,
    required this.onClearDates,
  });
  final String type;
  final DateTime? from;
  final DateTime? to;
  final String allLabel;
  final String confirmLabel;
  final String reminderLabel;
  final String retentionLabel;
  final ValueChanged<String> onType;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onClearDates;

  static final _short = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppChip(
                  label: allLabel,
                  selected: type == 'all',
                  onTap: () => onType('all'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: confirmLabel,
                  selected: type == 'confirmation',
                  onTap: () => onType('confirmation'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: reminderLabel,
                  selected: type == 'reminder',
                  onTap: () => onType('reminder'),
                ),
                AppSpacing.hGapSm,
                AppChip(
                  label: retentionLabel,
                  selected: type == 'retention',
                  onTap: () => onType('retention'),
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: from == null
                      ? 'dd.mm.yyyy'
                      : _short.format(from!),
                  onTap: onFromTap,
                ),
              ),
              Padding(
                padding: const
                    EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text('—',
                    style: TextStyle(color: context.colors.textMuted)),
              ),
              Expanded(
                child: _DateField(
                  label: to == null
                      ? 'dd.mm.yyyy'
                      : _short.format(to!),
                  onTap: onToTap,
                ),
              ),
              if (from != null || to != null) ...[
                AppSpacing.hGapXs,
                TapScale(
                  onTap: onClearDates,
                  scale: 0.85,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close,
                        size: 16, color: context.colors.textMuted),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 14, color: context.colors.textMuted),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(label, style: AppText.bodySm),
            ),
          ],
        ),
      ),
    );
  }
}
