import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Installment-centric list — mirrors web ShopCustomers exactly. One row
/// per installment plan (a customer with two plans appears twice).
/// Customer-aggregated view is still available on the LopePay home
/// shell's Customers tab.
class LopepayInstallmentsScreen extends ConsumerStatefulWidget {
  const LopepayInstallmentsScreen({super.key});

  @override
  ConsumerState<LopepayInstallmentsScreen> createState() =>
      _LopepayInstallmentsScreenState();
}

class _LopepayInstallmentsScreenState
    extends ConsumerState<LopepayInstallmentsScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  String _query = '';
  String _status = 'all'; // 'all' | 'overdue' | 'due_today' | 'upcoming' | 'paid_off'

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_installmentsListProvider((
      search: _query.isEmpty ? null : _query,
      status: _status == 'all' ? null : _status,
    )));
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                    style: const TextStyle(color: AppColors.textMuted))),
            data: (res) {
              final list = res.data;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                        tr(ref, 'mobile.lopepay.installments.empty',
                            "Rassrochka topilmadi"),
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(_installmentsListProvider);
                  await ref.read(_installmentsListProvider((
                    search: _query.isEmpty ? null : _query,
                    status: _status == 'all' ? null : _status,
                  )).future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final inst = list[i];
                    final id = (inst['id'] ?? '').toString();
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
                      onTap: id.isEmpty
                          ? null
                          : () => context.push('/lopepay/customers/$id'),
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
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14)),
                                    ),
                                    if (status.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                            _statusLabel(ref, status, daysLate),
                                            style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ]),
                                  if (phone.isNotEmpty)
                                    Row(children: [
                                      const Icon(Icons.phone_outlined,
                                          size: 10, color: AppColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(phone,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11)),
                                    ]),
                                  if (productName.isNotEmpty)
                                    Text(
                                        "$productName · $monthsPaid/$monthsTotal ${tr(ref, 'lopePay.shop.monthsPaid', 'oy')}",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 11)),
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
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
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
                                            fontSize: 10));
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

typedef _InstallmentsKey = ({String? search, String? status});

final _installmentsListProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total}),
    _InstallmentsKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).listInstallments(
        search: k.search,
        status: k.status,
        limit: 100,
      );
});
