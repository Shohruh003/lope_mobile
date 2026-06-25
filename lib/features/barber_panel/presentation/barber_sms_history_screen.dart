import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/sms_history_repository.dart';

/// SMS history with date range + type filter — mirrors web's
/// BarberSmsHistoryScreen. The list reloads as the filter state changes;
/// status badge colors and timestamps stay parity-matched (24h ru-RU format).
class BarberSmsHistoryScreen extends ConsumerStatefulWidget {
  const BarberSmsHistoryScreen({super.key});

  @override
  ConsumerState<BarberSmsHistoryScreen> createState() =>
      _BarberSmsHistoryScreenState();
}

class _BarberSmsHistoryScreenState
    extends ConsumerState<BarberSmsHistoryScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _dateOnly = DateFormat('yyyy-MM-dd');

  // 'all' | 'confirmation' | 'reminder' | 'retention'
  String _type = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;

  Future<void> _pickDate(bool isFrom) async {
    final initial = (isFrom ? _from : _to) ?? DateTime.now();
    final first = DateTime(2024);
    final last = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          title: Text(tr(ref, 'mobile.barber.sms.title', "SMS tarixi"))),
      body: Column(
        children: [
          _FilterBar(
            type: _type,
            from: _from,
            to: _to,
            allLabel: tr(ref, 'common.all', 'Hammasi'),
            confirmLabel:
                tr(ref, 'mobile.barber.sms.typeConfirm', "Tasdiqlash"),
            reminderLabel:
                tr(ref, 'mobile.barber.sms.typeReminder', "Eslatma"),
            retentionLabel:
                tr(ref, 'mobile.barber.sms.typeRetention', "Qayta jalb"),
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(
                      "${tr(ref, 'common.error', 'Xatolik')}: $e",
                      style:
                          const TextStyle(color: AppColors.textMuted))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                          tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 15)),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.refresh(smsHistoryFilteredProvider(key).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final ok = s.status == 'delivered' ||
                          s.status == 'sent' ||
                          s.status == 'success';
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(s.phone,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                ),
                                if ((s.type ?? '').isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(s.type!.toLowerCase(),
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (ok
                                            ? AppColors.success
                                            : AppColors.danger)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      ok
                                          ? tr(ref,
                                              'mobile.barber.sms.statusOk',
                                              'delivered')
                                          : tr(ref,
                                              'mobile.barber.sms.statusFail',
                                              'failed'),
                                      style: TextStyle(
                                          color: ok
                                              ? AppColors.success
                                              : AppColors.danger,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(s.message,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            Text(_df.format(s.createdAt.toLocal()),
                                style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11)),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 250.ms, delay: (i * 30).ms)
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(label: allLabel, on: type == 'all', onTap: () => onType('all')),
                _Chip(
                    label: confirmLabel,
                    on: type == 'confirmation',
                    onTap: () => onType('confirmation')),
                _Chip(
                    label: reminderLabel,
                    on: type == 'reminder',
                    onTap: () => onType('reminder')),
                _Chip(
                    label: retentionLabel,
                    on: type == 'retention',
                    onTap: () => onType('retention')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: from == null ? 'dd.mm.yyyy' : _short.format(from!),
                  onTap: onFromTap,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('—', style: TextStyle(color: AppColors.textMuted)),
              ),
              Expanded(
                child: _DateField(
                  label: to == null ? 'dd.mm.yyyy' : _short.format(to!),
                  onTap: onToTap,
                ),
              ),
              if (from != null || to != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClearDates,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: on ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
