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
                ...installments.map((i) => InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openInstallmentActions(context, ref, i),
                      child: _RowCard(
                        title: (i['productName'] ?? tr(ref, 'mobile.lopepay.products.newProduct', 'Mahsulot')).toString(),
                        subtitle: tr(ref, 'mobile.lopepay.customer.remaining',
                            "Qoldi: {{amount}} {{currency}}",
                            {
                              'amount': _fmt(((i['remaining'] ?? 0) as num).toInt()),
                              'currency': tr(ref, 'common.currency', "so'm"),
                            }),
                        badge: _installmentStatusLabel(ref, (i['status'] ?? '').toString()),
                        badgeColor: i['status'] == 'overdue' ? AppColors.danger : AppColors.success,
                      ),
                    )),

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

  String _installmentStatusLabel(WidgetRef ref, String status) {
    switch (status) {
      case 'overdue':
        return tr(ref, 'mobile.lopepay.customer.statusOverdue', 'Muddati o\'tgan');
      case 'paid':
        return tr(ref, 'mobile.lopepay.customer.statusPaid', 'To\'langan');
      case 'active':
        return tr(ref, 'mobile.lopepay.customer.statusActive', 'Faol');
      default:
        return status;
    }
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
        await repo.markInstallmentPaid(instId);
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

final _lopepayCustomerProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/lopepay/customers/$id');
  return Map<String, dynamic>.from(res.data as Map);
});
