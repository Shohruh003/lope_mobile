import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Mirrors web `ShopSmsHistory.tsx`:
///   - Phone search input
///   - Type filter chips (PRE_DUE / DUE / OVERDUE)
///   - Filter button → collapsible panel with product dropdown + date range
///   - Server-side filtering + pagination
class LopepaySmsScreen extends ConsumerStatefulWidget {
  const LopepaySmsScreen({super.key});
  @override
  ConsumerState<LopepaySmsScreen> createState() => _LopepaySmsScreenState();
}

class _LopepaySmsScreenState extends ConsumerState<LopepaySmsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 20;

  String _phone = '';
  String _type = 'all';
  String? _productId;
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  LopepaySmsKey get _key => (
        phone: _phone.isEmpty ? null : _phone,
        type: _type == 'all' ? null : _type,
        productId: _productId,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
        page: _page,
      );

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

  Future<void> _pickDate(bool isFrom) async {
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
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

  void _resetFilters() {
    setState(() {
      _phone = '';
      _type = 'all';
      _productId = null;
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepaySmsFilteredProvider(_key));
    final productsAsync = ref.watch(lopepayProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.sms.title', "SMS tarixi")),
        actions: [
          IconButton(
            icon: Icon(
                _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                color: _filtersOpen ? AppColors.primary : null),
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      ),
      body: Column(children: [
        // Phone search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() {
              _phone = v;
              _page = 1;
            }),
            style: const TextStyle(color: AppColors.textBright),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 22),
              hintText: tr(ref, 'lopePay.shop.filterPhone',
                  "Telefon raqami"),
              isDense: true,
            ),
          ),
        ),
        // Type chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                  label: tr(ref, 'common.all', "Hammasi"),
                  on: _type == 'all',
                  onTap: () => setState(() {
                        _type = 'all';
                        _page = 1;
                      })),
              _Chip(
                  label: _typeLabel(ref, 'INSTALLMENT_PRE_DUE'),
                  on: _type == 'INSTALLMENT_PRE_DUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_PRE_DUE';
                        _page = 1;
                      })),
              _Chip(
                  label: _typeLabel(ref, 'INSTALLMENT_DUE'),
                  on: _type == 'INSTALLMENT_DUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_DUE';
                        _page = 1;
                      })),
              _Chip(
                  label: _typeLabel(ref, 'INSTALLMENT_OVERDUE'),
                  on: _type == 'INSTALLMENT_OVERDUE',
                  onTap: () => setState(() {
                        _type = 'INSTALLMENT_OVERDUE';
                        _page = 1;
                      })),
            ],
          ),
        ),
        // Advanced filter panel
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                productsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (products) => DropdownButtonFormField<String?>(
                    isDense: true,
                    initialValue: _productId,
                    decoration: InputDecoration(
                      labelText: tr(ref, 'lopePay.shop.filterProduct',
                          "Mahsulot"),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(tr(ref, 'common.all', "Hammasi"))),
                      ...products.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() {
                      _productId = v;
                      _page = 1;
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _DatePill(
                          label: _from == null
                              ? tr(ref, 'lopePay.shop.filterFrom', "Dan")
                              : _ymd.format(_from!),
                          onTap: () => _pickDate(true))),
                  const SizedBox(width: 8),
                  const Text("—",
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _DatePill(
                          label: _to == null
                              ? tr(ref, 'lopePay.shop.filterTo', "Gacha")
                              : _ymd.format(_to!),
                          onTap: () => _pickDate(false))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(tr(ref, 'common.reset', "Tozalash")),
                      onPressed: _resetFilters,
                    ),
                  ),
                ]),
              ]),
            ),
          ),

        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted))),
            data: (res) {
              final list = res.data;
              final pages = (res.total / _pageSize).ceil();
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                        tr(ref, 'mobile.barber.sms.empty', "SMS yo'q"),
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepaySmsFilteredProvider);
                  ref.invalidate(lopepaySmsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      // Backend returns InstallmentSmsLog rows with the
                      // installment nested (shop-history.service.ts:74).
                      // No `status` field — all logged rows are SMS that
                      // went out successfully (failures land in
                      // SmsFailedAttempt instead).
                      final type = (s['type'] ?? '').toString();
                      final inst = s['installment'] is Map
                          ? (s['installment'] as Map).cast<String, dynamic>()
                          : <String, dynamic>{};
                      final phone = (inst['customerPhone'] ??
                              s['phone'] ??
                              '')
                          .toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
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
                                    child: Text(phone,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                      tr(ref,
                                          'mobile.barber.sms.statusOk',
                                          'delivered'),
                                      style: const TextStyle(
                                          color: AppColors.success,
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
                                    color: AppColors.primary
                                        .withValues(alpha: 0.10),
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
                              if ((s['sentAt'] ?? s['createdAt']) != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                    _df.format(DateTime.parse(
                                            (s['sentAt'] ??
                                                    s['createdAt'])
                                                .toString())
                                        .toLocal()),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                              ],
                            ],
                          ),
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
                            child:
                                Text(tr(ref, 'common.prev', "Oldingi")),
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
                            child:
                                Text(tr(ref, 'common.next', "Keyingi")),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ]),
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

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textBright, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
