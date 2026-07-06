import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

/// Mirrors web `BarbershopSmsHistory.tsx`:
///   - Filter button → collapsible panel: barber dropdown, type, from/to dates
///   - Per-row: phone, status badge, type badge, message, timestamp
///   - Prev / Next pagination footer
class ShopSmsScreen extends ConsumerStatefulWidget {
  const ShopSmsScreen({super.key});
  @override
  ConsumerState<ShopSmsScreen> createState() => _ShopSmsScreenState();
}

class _ShopSmsScreenState extends ConsumerState<ShopSmsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static const _pageSize = 30;

  String? _barberId;
  String _type = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  ShopSmsKey get _key => (
        barberId: _barberId,
        type: _type == 'all' ? null : _type,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
        page: _page,
      );

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
      _barberId = null;
      _type = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'confirmation':
        return tr(ref, 'shop.smsTypes.confirmation', "Tasdiqlash");
      case 'reminder':
        return tr(ref, 'shop.smsTypes.reminder', "Eslatma");
      case 'retention':
        return tr(ref, 'shop.smsTypes.retention', "Qaytarish");
      default:
        return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopSmsFilteredProvider(_key));
    final barbersAsync = ref.watch(shopBarbersProvider);

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
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                barbersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (barbers) => DropdownButtonFormField<String?>(
                    isDense: true,
                    initialValue: _barberId,
                    decoration: InputDecoration(
                      labelText: tr(ref, 'shop.filter.barber', "Master"),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: null,
                          child: Text(
                              tr(ref, 'shop.filter.allBarbers', "Barchasi"))),
                      ...barbers.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) => setState(() {
                      _barberId = v;
                      _page = 1;
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isDense: true,
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'shop.filter.type', "Turi"),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text(tr(ref, 'common.all', "Hammasi"))),
                    DropdownMenuItem(
                        value: 'confirmation',
                        child: Text(_typeLabel('confirmation'))),
                    DropdownMenuItem(
                        value: 'reminder',
                        child: Text(_typeLabel('reminder'))),
                    DropdownMenuItem(
                        value: 'retention',
                        child: Text(_typeLabel('retention'))),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v ?? 'all';
                    _page = 1;
                  }),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _DatePill(
                          label: _from == null
                              ? tr(ref, 'shop.filter.from', "Dan")
                              : _ymd.format(_from!),
                          onTap: () => _pickDate(true))),
                  const SizedBox(width: 8),
                  const Text("—",
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _DatePill(
                          label: _to == null
                              ? tr(ref, 'shop.filter.to', "Gacha")
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
            loading: () => const AppListSkeleton(),
            error: (e, _) => Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}",
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
                  ref.invalidate(shopSmsFilteredProvider);
                  ref.invalidate(shopSmsLogProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...list.asMap().entries.map((entry) {
                      final i = entry.key;
                      final s = entry.value;
                      final ok = s.status == 'delivered' ||
                          s.status == 'sent' ||
                          s.status == 'success';
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
                                    child: Text(s.phone,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14))),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (ok
                                            ? AppColors.success
                                            : AppColors.danger)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
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
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(s.message,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      height: 1.4)),
                              const SizedBox(height: 8),
                              Text(_df.format(s.createdAt.toLocal()),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12)),
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
