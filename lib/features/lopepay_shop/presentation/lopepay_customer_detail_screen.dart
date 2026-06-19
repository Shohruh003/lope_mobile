import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
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
        title: const Text("Mijoz"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit via path go (kept simple — using go_router root via Navigator parent).
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        onPressed: () => _recordPayment(context, ref),
        icon: const Icon(Icons.payments),
        label: const Text("To'lov qabul qilish"),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e")),
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
                    const Text("Qarz", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("${_fmt(debt)} so'm",
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text("Qo'ng'iroq"),
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
                    label: const Text("SMS"),
                    onPressed: phone.isEmpty ? null : () async {
                      final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
                      final uri = Uri(scheme: 'sms', path: clean);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                  ),
                ),
              ]),

              const SizedBox(height: 22),
              const Text("Rassrochkalar", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (installments.isEmpty)
                const Text("Faol rassrochka yo'q", style: TextStyle(color: AppColors.textMuted))
              else
                ...installments.map((i) => _RowCard(
                      title: (i['productName'] ?? 'Mahsulot').toString(),
                      subtitle: "Qoldi: ${_fmt(((i['remaining'] ?? 0) as num).toInt())} so'm",
                      badge: (i['status'] ?? '').toString(),
                      badgeColor: i['status'] == 'overdue' ? AppColors.danger : AppColors.success,
                    )),

              const SizedBox(height: 22),
              const Text("To'lovlar tarixi", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (payments.isEmpty)
                const Text("Hali to'lov yo'q", style: TextStyle(color: AppColors.textMuted))
              else
                ...payments.map((p) {
                  final at = DateTime.tryParse(p['paidAt']?.toString() ?? '');
                  return _RowCard(
                    title: "${_fmt(((p['amount'] ?? 0) as num).toInt())} so'm",
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
          const Text("To'lov qabul qilish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Summa (so'm)"),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(true),
              child: const Text("Qabul qilish"),
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
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Qabul qilindi")));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
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
