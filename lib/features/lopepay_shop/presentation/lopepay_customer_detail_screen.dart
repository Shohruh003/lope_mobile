import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/lopepay_repository.dart';

/// Full installment-customer detail with payment history. Owner can record
/// a payment via the green FAB.
class LopepayCustomerDetailScreen extends ConsumerWidget {
  const LopepayCustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_lopepayCustomerProvider(customerId));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz")),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/lopepay/customers/$customerId/edit'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        onPressed: () => _recordPayment(context, ref),
        icon: const Icon(Icons.payments),
        label: Text(tr(ref, 'mobile.lopepay.customer.recordPayment', "To'lov qabul qilish")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (data) {
          final name = (data['name'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final debt = ((data['totalDebt'] ?? 0) as num).toInt();
          final payments = (data['payments'] as List? ?? []).cast<Map<String, dynamic>>();
          final installments = (data['installments'] as List? ?? []).cast<Map<String, dynamic>>();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_lopepayCustomerProvider(customerId).future),
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? phone : name,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(address, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    Text(tr(ref, 'mobile.lopepay.customer.debt', "Qarz"),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: Text(tr(ref, 'mobile.lopepay.customer.call', "Qo'ng'iroq")),
                    onPressed: phone.isEmpty ? null : () async {
                      final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
                      final uri = Uri(scheme: 'tel', path: clean);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.sms),
                    label: const Text("SMS"),  // brand name
                    onPressed: phone.isEmpty ? null : () async {
                      final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
                      final uri = Uri(scheme: 'sms', path: clean);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 22),
              Text(tr(ref, 'mobile.lopepay.customer.installments', "Rassrochkalar"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (installments.isEmpty)
                Text(tr(ref, 'mobile.lopepay.customer.noActiveInstallments', "Faol rassrochka yo'q"),
                    style: const TextStyle(color: AppColors.textMuted))
              else
                ...installments.map((i) {
                  final daysLate = ((i['daysLate'] ?? 0) as num).toInt();
                  final monthsPaid = ((i['monthsPaid'] ?? 0) as num).toInt();
                  final monthsTotal = ((i['monthsTotal'] ?? 0) as num).toInt();
                  final isPaidOff = i['isPaidOff'] == true;
                  final totalPrice = ((i['totalPrice'] ?? 0) as num).toInt();
                  final monthlyPayment =
                      ((i['monthlyPayment'] ?? 0) as num).toInt();
                  final debt = ((i['debt'] ??
                          (isPaidOff ? 0 : monthlyPayment)) as num)
                      .toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () =>
                            _openInstallmentActions(context, ref, i),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status banner — mirrors web's StatusBanner
                              _installmentStatusBanner(ref,
                                  isPaidOff: isPaidOff,
                                  daysLate: daysLate,
                                  nextDueDate:
                                      i['nextDueDate']?.toString()),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            (i['productName'] ??
                                                    tr(ref,
                                                        'mobile.lopepay.products.newProduct',
                                                        'Mahsulot'))
                                                .toString(),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                            "$monthsPaid / $monthsTotal ${tr(ref, 'lopePay.shop.monthsPaid', "oy")}",
                                            style: const TextStyle(
                                                color: AppColors.textMuted,
                                                fontSize: 12)),
                                      ]),
                                ),
                                Text(
                                    isPaidOff
                                        ? "0 ${tr(ref, 'common.currency', "so'm")}"
                                        : "${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: isPaidOff
                                            ? AppColors.success
                                            : (daysLate > 0
                                                ? AppColors.danger
                                                : AppColors.primary))),
                              ]),
                              const SizedBox(height: 8),
                              // 2x2 mini-stats grid — totalPrice / monthly /
                              // monthsPaid / debt
                              Row(children: [
                                Expanded(
                                  child: _MiniStat(
                                      label: tr(ref,
                                          'lopePay.shop.totalPrice',
                                          "Jami"),
                                      value:
                                          "${_fmt(totalPrice)} ${tr(ref, 'common.currency', "so'm")}"),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _MiniStat(
                                      label: tr(ref,
                                          'lopePay.shop.monthlyPayment',
                                          "Oylik"),
                                      value:
                                          "${_fmt(monthlyPayment)} ${tr(ref, 'common.currency', "so'm")}"),
                                ),
                              ]),
                            ]),
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 22),
              Text(tr(ref, 'mobile.lopepay.customer.paymentsHistory', "To'lovlar tarixi"),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                Text(tr(ref, 'mobile.lopepay.customer.noPayments', "Hali to'lov yo'q"),
                    style: const TextStyle(color: AppColors.textMuted))
              else
                ...payments.map((p) {
                  final at = DateTime.tryParse(p['paidAt']?.toString() ?? '');
                  return _RowCard(
                    title: "${_fmt(((p['amount'] ?? 0) as num).toInt())} ${tr(ref, 'common.currency', "so'm")}",
                    subtitle: at == null ? '' : _df.format(at.toLocal()),
                    badge: '+',
                    badgeColor: AppColors.success,
                  );
                }),
            ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 18,
          bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(ref, 'mobile.lopepay.customer.recordPayment', "To'lov qabul qilish"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                hintText: tr(ref, 'mobile.customer.transactions.topUpAmount', "Summa (so'm)")),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(true),
              child: Text(tr(ref, 'common.confirm', "Qabul qilish")),
            ),
          ),
        ]),
      ),
    );
    if (ok != true) return;
    final amt = int.tryParse(amount.text.trim()) ?? 0;
    if (amt <= 0) return;
    try {
      await ref.read(lopepayRepositoryProvider).recordPayment(customerId, amt);
      ref.invalidate(_lopepayCustomerProvider(customerId));
      ref.invalidate(lopepayDashboardProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(ref, 'mobile.lopepay.customer.received', "Qabul qilindi"))));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
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


  /// Per-installment action sheet: mark next month paid, undo last
  /// payment (when at least one is logged), delete entire plan.
  Future<void> _openInstallmentActions(
      BuildContext context, WidgetRef ref, Map<String, dynamic> inst) async {
    final instId = (inst['id'] ?? '').toString();
    if (instId.isEmpty) return;
    final monthsPaid = ((inst['monthsPaid'] ?? 0) as num).toInt();
    final isPaidOff = inst['isPaidOff'] == true;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          if (!isPaidOff)
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
              title: Text(tr(ref, 'mobile.lopepay.installment.markPaid',
                  "Oyni to'langan deb belgilash")),
              onTap: () => Navigator.of(sheetCtx).pop('mark'),
            ),
          if (monthsPaid > 0)
            ListTile(
              leading: const Icon(Icons.undo, color: AppColors.warning),
              title: Text(tr(ref, 'mobile.lopepay.installment.undoLast',
                  "Oxirgi to'lovni bekor qilish")),
              onTap: () => Navigator.of(sheetCtx).pop('undo'),
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: Text(tr(ref, 'mobile.lopepay.installment.delete',
                "Rassrochkani o'chirish")),
            onTap: () => Navigator.of(sheetCtx).pop('delete'),
          ),
          ListTile(
            leading: const Icon(Icons.close, color: AppColors.textMuted),
            title: Text(tr(ref, 'common.close', "Yopish")),
            onTap: () => Navigator.of(sheetCtx).pop(null),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return;
    final repo = ref.read(lopepayRepositoryProvider);
    try {
      if (picked == 'mark') {
        // Mirror web MarkPaidDialog — prefill the monthly payment so the
        // owner just confirms unless they took a different cash amount
        // (early partial / late penalty surcharge etc).
        if (!context.mounted) return;
        final monthlyPayment =
            ((inst['monthlyPayment'] ?? 0) as num).toInt();
        final nextMonth = ((inst['nextMonthNumber'] ?? 0) as num).toInt();
        final monthsTotal = ((inst['monthsTotal'] ?? 0) as num).toInt();
        final amountCtrl = TextEditingController(
            text: monthlyPayment > 0 ? monthlyPayment.toString() : '');
        final markOk = await showDialog<int?>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(nextMonth > 0
                ? tr(ref, 'mobile.lopepay.installment.markPaidTitle',
                    "Oyni to'langan deb belgilash ({{n}}/{{total}})",
                    {'n': '$nextMonth', 'total': '$monthsTotal'})
                : tr(ref, 'mobile.lopepay.installment.markPaid',
                    "Oyni to'langan deb belgilash")),
            content: TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr(ref,
                    'mobile.customer.transactions.topUpAmount',
                    "Summa (so'm)"),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: Text(tr(ref, 'common.cancel', "Bekor"))),
              TextButton(
                  onPressed: () => Navigator.pop(
                      dCtx, int.tryParse(amountCtrl.text.trim())),
                  child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
            ],
          ),
        );
        if (markOk == null) return;
        await repo.markInstallmentPaid(instId, amount: markOk);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(ref, 'common.saved', "Saqlandi"))));
        }
      } else if (picked == 'undo') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(tr(ref, 'mobile.lopepay.installment.undoConfirmTitle',
                "Oxirgi to'lov bekor qilinsinmi?")),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(tr(ref, 'common.cancel', "Bekor"))),
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
            ],
          ),
        );
        if (ok != true) return;
        await repo.undoLastInstallmentPayment(instId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(ref, 'common.saved', "Saqlandi"))));
        }
      } else if (picked == 'delete') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: AppColors.background,
            title: Text(tr(ref, 'mobile.lopepay.installment.deleteConfirmTitle',
                "Rassrochka o'chirilsinmi?")),
            content: Text(tr(ref, 'mobile.lopepay.installment.deleteConfirmMsg',
                "Rassrochka va uning barcha to'lovlari o'chiriladi.")),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(tr(ref, 'common.cancel', "Bekor"))),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: Text(tr(ref, 'common.delete', "O'chirish"))),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deleteInstallment(instId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr(ref, 'common.deleted', "O'chirildi"))));
        }
      }
      ref.invalidate(_lopepayCustomerProvider(customerId));
      ref.invalidate(lopepayDashboardProvider);
      ref.invalidate(lopepayCustomersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    }
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({required this.title, required this.subtitle, required this.badge, required this.badgeColor});
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(badge,
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Compact stat used inside the per-installment 2×2 mini grid.
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
    );
  }
}

/// Status banner shown above each installment card — matches web's
/// StatusBanner colour scheme (success / due-today / overdue / next-due).
Widget _installmentStatusBanner(WidgetRef ref,
    {required bool isPaidOff,
    required int daysLate,
    String? nextDueDate}) {
  if (isPaidOff) {
    return _bannerRow(
        icon: Icons.check_circle,
        color: AppColors.success,
        label: tr(ref, 'lopePay.shop.bannerPaidOff',
            "To'liq to'langan"));
  }
  if (daysLate > 0) {
    return _bannerRow(
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        label: tr(ref, 'lopePay.shop.bannerOverdue',
            "{{days}} kun kechikkan", {'days': '$daysLate'}));
  }
  if (daysLate == 0 && nextDueDate != null) {
    return _bannerRow(
        icon: Icons.access_time,
        color: AppColors.warning,
        label: tr(ref, 'lopePay.shop.bannerDueToday', "Bugun to'lov kuni"));
  }
  if (nextDueDate != null && nextDueDate.isNotEmpty) {
    final d = DateTime.tryParse(nextDueDate);
    if (d != null) {
      final df = DateFormat('dd.MM.yyyy', 'ru_RU');
      return _bannerRow(
          icon: Icons.event_outlined,
          color: AppColors.textMuted,
          label: tr(ref, 'lopePay.shop.bannerNextDue',
              "Keyingi to'lov: {{date}}",
              {'date': df.format(d.toLocal())}));
    }
  }
  return const SizedBox.shrink();
}

Widget _bannerRow(
    {required IconData icon,
    required Color color,
    required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

final _lopepayCustomerProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/lopepay/customers/$id');
  return Map<String, dynamic>.from(res.data as Map);
});
