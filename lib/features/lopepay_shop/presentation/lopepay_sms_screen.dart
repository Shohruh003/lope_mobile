import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Lope Pay shop SMS log. Mirrors the web ShopSmsHistory page:
/// search input + type filter chips over the chronological list.
class LopepaySmsScreen extends ConsumerStatefulWidget {
  const LopepaySmsScreen({super.key});

  @override
  ConsumerState<LopepaySmsScreen> createState() => _LopepaySmsScreenState();
}

class _LopepaySmsScreenState extends ConsumerState<LopepaySmsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  String _query = '';
  String _type = 'all'; // 'all' | 'INSTALLMENT_PRE_DUE' | 'INSTALLMENT_DUE' | 'INSTALLMENT_OVERDUE'

  String _typeLabel(WidgetRef ref, String t) {
    switch (t) {
      case 'INSTALLMENT_PRE_DUE':
        return tr(ref, 'mobile.lopepay.sms.typePreDue', 'Ertaga eslatma');
      case 'INSTALLMENT_DUE':
        return tr(ref, 'mobile.lopepay.sms.typeDue', "Bugun to'lov");
      case 'INSTALLMENT_OVERDUE':
        return tr(ref, 'mobile.lopepay.sms.typeOverdue', 'Kechikkan');
      default:
        return t;
    }
  }

  bool _matchesFilter(Map<String, dynamic> s) {
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      final phone = (s['phone'] ?? '').toString();
      final message = (s['message'] ?? '').toString().toLowerCase();
      if (!phone.contains(_query) && !message.contains(q)) return false;
    }
    if (_type != 'all' && (s['type'] ?? '').toString() != _type) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepaySmsProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(ref, 'mobile.barber.sms.title', "SMS tarixi"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (raw) {
          final list = raw.where(_matchesFilter).toList();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(lopepaySmsProvider.future),
            child: Column(children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textBright),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMuted, size: 22),
                    hintText: tr(ref, 'mobile.lopepay.customers.searchHint',
                        "Ism yoki telefon"),
                    isDense: true,
                  ),
                ),
              ),
              // Type filter chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _Chip(
                        label: tr(ref, 'common.all', "Hammasi"),
                        on: _type == 'all',
                        onTap: () => setState(() => _type = 'all')),
                    _Chip(
                        label: _typeLabel(ref, 'INSTALLMENT_PRE_DUE'),
                        on: _type == 'INSTALLMENT_PRE_DUE',
                        onTap: () => setState(() => _type = 'INSTALLMENT_PRE_DUE')),
                    _Chip(
                        label: _typeLabel(ref, 'INSTALLMENT_DUE'),
                        on: _type == 'INSTALLMENT_DUE',
                        onTap: () => setState(() => _type = 'INSTALLMENT_DUE')),
                    _Chip(
                        label: _typeLabel(ref, 'INSTALLMENT_OVERDUE'),
                        on: _type == 'INSTALLMENT_OVERDUE',
                        onTap: () => setState(() => _type = 'INSTALLMENT_OVERDUE')),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              raw.isEmpty
                                  ? tr(ref, 'mobile.barber.sms.empty',
                                      "SMS yo'q")
                                  : tr(ref, 'common.noResults',
                                      "Hech narsa topilmadi"),
                              style: const TextStyle(color: AppColors.textMuted)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final ok = s['status'] == 'delivered' || s['status'] == 'sent';
                          final type = (s['type'] ?? '').toString();
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
                                Row(children: [
                                  Expanded(
                                      child: Text((s['phone'] ?? '').toString(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700))),
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
                                            ? tr(ref, 'mobile.barber.sms.statusOk',
                                                'delivered')
                                            : tr(ref, 'mobile.barber.sms.statusFail',
                                                'failed'),
                                        style: TextStyle(
                                            color: ok
                                                ? AppColors.success
                                                : AppColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                                if (type.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(_typeLabel(ref, type),
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 10)),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text((s['message'] ?? '').toString(),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                        height: 1.4)),
                                if (s['createdAt'] != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                      _df.format(
                                          DateTime.parse(s['createdAt'].toString())
                                              .toLocal()),
                                      style: const TextStyle(
                                          color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ],
                            ),
                          ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                        },
                      ),
              ),
            ]),
          );
        },
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
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: on ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? AppColors.primary : AppColors.textMuted)),
        ),
      ),
    );
  }
}
