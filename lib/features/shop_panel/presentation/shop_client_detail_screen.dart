import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../shared/theme/colors.dart';

/// Detail view for one shop client. Loads /barbershop/clients/:key (the
/// "key" is usually the phone number in the web app).
class ShopClientDetailScreen extends ConsumerWidget {
  const ShopClientDetailScreen({super.key, required this.clientKey});
  final String clientKey;

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_clientDetailProvider(clientKey));
    return Scaffold(
      appBar: AppBar(title: const Text("Mijoz")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e")),
        data: (data) {
          final name = (data['name'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final history = (data['bookings'] as List? ?? []).cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 84, height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontSize: 34, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 14),
              Center(child: Text(name.isEmpty ? phone : name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textBright))),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Center(child: Text(phone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone),
                    label: const Text("Qo'ng'iroq"),
                    onPressed: phone.isEmpty
                        ? null
                        : () async {
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
                    onPressed: phone.isEmpty
                        ? null
                        : () async {
                            final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
                            final uri = Uri(scheme: 'sms', path: clean);
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                  ),
                ),
              ]),

              const SizedBox(height: 26),
              const Text("Tashriflar tarixi",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("Tashriflar yo'q",
                      style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ...history.map((h) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((h['barberName'] ?? 'Master').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(_fmtDate(h['date']?.toString() ?? ''),
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(((h['totalPrice'] ?? 0) as num).toInt() == 0
                                ? ''
                                : "${_fmt(((h['totalPrice']) as num).toInt())} so'm",
                            style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
                    )),
            ],
          );
        },
      ),
    );
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _df.format(d.toLocal());
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

final _clientDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershop/clients/$key');
  return Map<String, dynamic>.from(res.data as Map);
});
