import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';

/// Installment-centric list — mirrors web ShopCustomers exactly. One row
/// per installment plan (a customer with two plans appears twice).
/// Customer-aggregated view is still available on the LopePay home
/// shell's Customers tab.
class LopepayInstallmentsScreen extends ConsumerStatefulWidget {
  const LopepayInstallmentsScreen({super.key, this.initialStatus});
  final String? initialStatus;

  @override
  ConsumerState<LopepayInstallmentsScreen> createState() =>
      _LopepayInstallmentsScreenState();
}

class _LopepayInstallmentsScreenState
    extends ConsumerState<LopepayInstallmentsScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  String _query = '';
  late String _status =
      widget.initialStatus ?? 'all'; // 'all' | 'overdue' | 'due_today' | 'upcoming' | 'paid_off'
  String _phone = '';
  String? _productId; // null = any
  DateTime? _from;
  DateTime? _to;
  bool _filtersOpen = false;

  String _statusLabel(WidgetRef ref, String s, int daysLate) {
    switch (s) {
      case 'paid_off':
        return tr(ref, 'mobile.lopepay.customer.statusPaid', "To'langan");
      case 'overdue':
        return tr(ref, 'mobile.lopepay.installments.daysLate',
            "{{n}} kun kechikkan", {'n': '$daysLate'});
      case 'due_today':
        return tr(ref, 'mobile.lopepay.home.dueToday', "Bugun");
      case 'due_tomorrow':
        return tr(ref, 'mobile.lopepay.installments.dueTomorrow', "Ertaga");
      case 'upcoming':
        return tr(ref, 'mobile.lopepay.installments.upcoming', "Kelajakda");
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid_off':
        return AppColors.success;
      case 'overdue':
        return AppColors.danger;
      case 'due_today':
        return AppColors.warning;
      case 'due_tomorrow':
      case 'upcoming':
        return AppColors.primary;
      default:
        return AppColors.textMuted;
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

  _InstallmentsKey get _key => (
        search: _query.isEmpty ? null : _query,
        status: _status == 'all' ? null : _status,
        phone: _phone.isEmpty ? null : _phone,
        productId: _productId,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
      );

  Future<void> _pickDate(bool isFrom) async {
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _status = 'all';
      _phone = '';
      _productId = null;
      _from = null;
      _to = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepayInstallmentsListProvider(_key));
    final productsAsync = ref.watch(lopepayProductsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.lopepay.installments.title',
            "Rassrochkalar")),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/lopepay/customers/new'),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.lopepay.customerForm.addBtn',
            "Rassrochka qo'shish")),
      ),
      body: Column(children: [
        // Search bar + filter toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
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
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _filtersOpen = !_filtersOpen),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _filtersOpen
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _filtersOpen
                          ? AppColors.primary
                          : AppColors.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.filter_list,
                  color: _filtersOpen
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ]),
        ),

        // ===== Advanced filter panel (collapsible) =====
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
                TextField(
                  onChanged: (v) => setState(() => _phone = v),
                  controller: TextEditingController(text: _phone)
                    ..selection = TextSelection.collapsed(offset: _phone.length),
                  style: const TextStyle(color: AppColors.textBright),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: tr(ref, 'lopePay.shop.filterPhone',
                        'Telefon raqami'),
                    hintText: '+998...',
                  ),
                ),
                const SizedBox(height: 10),
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
                    onChanged: (v) => setState(() => _productId = v),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _DatePill(
                      label: _from == null
                          ? tr(ref, 'lopePay.shop.filterFrom', "Dan")
                          : _ymd.format(_from!),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("—",
                      style: TextStyle(color: AppColors.textMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DatePill(
                      label: _to == null
                          ? tr(ref, 'lopePay.shop.filterTo', "Gacha")
                          : _ymd.format(_to!),
                      onTap: () => _pickDate(false),
                    ),
                  ),
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
        // Status filter chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _Chip(
                  label: tr(ref, 'common.all', "Hammasi"),
                  on: _status == 'all',
                  onTap: () => setState(() => _status = 'all')),
              _Chip(
                  label: tr(ref, 'mobile.lopepay.customer.statusOverdue',
                      "Muddati o'tgan"),
                  on: _status == 'overdue',
                  onTap: () => setState(() => _status = 'overdue')),
              _Chip(
                  label: tr(ref, 'mobile.lopepay.home.dueToday', "Bugun"),
                  on: _status == 'due_today',
                  onTap: () => setState(() => _status = 'due_today')),
              _Chip(
                  label: tr(ref, 'mobile.lopepay.installments.upcoming',
                      "Kelajakda"),
                  on: _status == 'upcoming',
                  onTap: () => setState(() => _status = 'upcoming')),
              _Chip(
                  label: tr(ref, 'mobile.lopepay.customer.statusPaid',
                      "To'langan"),
                  on: _status == 'paid_off',
                  onTap: () => setState(() => _status = 'paid_off')),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const AppListSkeleton(),
            error: (e, _) => AppErrorState(
              message: humanize(e),
              onRetry: () => ref.invalidate(lopepayInstallmentsListProvider),
            ),
            data: (res) {
              final list = res.data;
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.credit_card_off_outlined,
                  title: tr(ref, 'mobile.lopepay.installments.empty',
                      "Rassrochka topilmadi"),
                  message: tr(
                    ref,
                    'mobile.lopepay.installments.emptyHint',
                    "Yangi mijoz uchun rassrochka rasmiylashtirsangiz shu yerda ko'rinadi.",
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepayInstallmentsListProvider);
                  await ref.read(lopepayInstallmentsListProvider(_key).future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final inst = list[i];
                    final name = (inst['customerName'] ?? '').toString();
                    final phone = (inst['customerPhone'] ?? '').toString();
                    final productName = (inst['productName'] ?? '').toString();
                    final monthsPaid = ((inst['monthsPaid'] ?? 0) as num).toInt();
                    final monthsTotal = ((inst['monthsTotal'] ?? 0) as num).toInt();
                    final debt = ((inst['debt'] ?? inst['monthlyPayment'] ?? 0)
                            as num)
                        .toInt();
                    final isPaidOff = inst['isPaidOff'] == true;
                    final status = (inst['status'] ?? '').toString();
                    final daysLate =
                        ((inst['daysLate'] ?? 0) as num).toInt();
                    final nextDue = inst['nextDueDate']?.toString();
                    final color = _statusColor(status);

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      // The detail provider keys on customerPhone (we
                      // aggregate installments by phone), not the
                      // installment id. Routing on the installment id
                      // would never match any installment in the detail
                      // aggregation → blank screen.
                      onTap: phone.isEmpty
                          ? null
                          : () => context.push(
                              '/lopepay/customers/${Uri.encodeComponent(phone)}'),
                      child: Opacity(
                        opacity: isPaidOff ? 0.6 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                      child: Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14)),
                                    ),
                                    if (status.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                            _statusLabel(ref, status, daysLate),
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ]),
                                  if (phone.isNotEmpty)
                                    Row(children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 12, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(phone,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12)),
                                    ]),
                                  if (productName.isNotEmpty)
                                    Text(
                                        "$productName · $monthsPaid/$monthsTotal ${tr(ref, 'lopePay.shop.monthsPaid', 'oy')}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    "${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                if (nextDue != null && !isPaidOff) ...[
                                  const SizedBox(height: 2),
                                  Builder(builder: (_) {
                                    final d = DateTime.tryParse(nextDue);
                                    if (d == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(_df.format(d.toLocal()),
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11));
                                  }),
                                ],
                              ],
                            ),
                          ]),
                        ),
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: (i * 20).ms);
                  },
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
            border: Border.all(color: on ? AppColors.primary : AppColors.border),
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
                style: const TextStyle(
                    color: AppColors.textBright, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

typedef _InstallmentsKey = ({
  String? search,
  String? status,
  String? phone,
  String? productId,
  String? from,
  String? to,
});

final lopepayInstallmentsListProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total}),
    _InstallmentsKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).listInstallments(
        search: k.search,
        status: k.status,
        phone: k.phone,
        productId: k.productId,
        from: k.from,
        to: k.to,
        limit: 100,
      );
});
