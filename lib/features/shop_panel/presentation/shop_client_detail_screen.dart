import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Detail view for one shop client. Mirrors web BarbershopClientDetail:
///   - Avatar + name + phone + totalVisits badge
///   - Edit pencil → dialog to update name/phone
///   - Call / SMS action buttons
///   - Visits history with status badge (confirmed/completed/cancelled)
///   - SMS history with type badge (CONFIRMATION/REMINDER/RETENTION)
class ShopClientDetailScreen extends ConsumerStatefulWidget {
  const ShopClientDetailScreen({super.key, required this.clientKey});
  final String clientKey;
  @override
  ConsumerState<ShopClientDetailScreen> createState() =>
      _ShopClientDetailScreenState();
}

class _ShopClientDetailScreenState
    extends ConsumerState<ShopClientDetailScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  static final _dfTime = DateFormat('dd.MM.yyyy HH:mm', 'ru_RU');

  late String _key = widget.clientKey;

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return tr(ref, 'status.completed', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'status.cancelled', 'Bekor qilingan');
      case 'confirmed':
        return tr(ref, 'status.confirmed', 'Tasdiqlangan');
      default:
        return status;
    }
  }

  ({String label, Color color}) _smsTypeBadge(String type) {
    switch (type) {
      case 'CONFIRMATION':
        return (
          label: tr(ref, 'shop.smsTypes.confirmation', 'Tasdiqlash'),
          color: const Color(0xFF3B82F6),
        );
      case 'REMINDER':
        return (
          label: tr(ref, 'shop.smsTypes.reminder', 'Eslatma'),
          color: const Color(0xFFF97316),
        );
      case 'RETENTION':
        return (
          label: tr(ref, 'shop.smsTypes.retention', 'Qaytarish'),
          color: const Color(0xFF8B5CF6),
        );
      default:
        return (label: type, color: AppColors.textMuted);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_clientDetailProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz")),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (data) {
          final name = (data['name'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final avatar = (data['avatar'] ?? '').toString();
          final totalVisits = (data['totalVisits'] is num)
              ? (data['totalVisits'] as num).toInt()
              : ((data['visits'] as List?)?.length ??
                  (data['bookings'] as List?)?.length ??
                  0);
          final visits =
              ((data['visits'] ?? data['bookings'] ?? const []) as List)
                  .cast<Map<String, dynamic>>();
          final smsLogs =
              ((data['smsLogs'] ?? const []) as List).cast<Map<String, dynamic>>();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_clientDetailProvider(_key).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // Avatar + name + phone + edit
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipOval(
                    child: avatar.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: assetUrl(avatar),
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                                (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? phone : name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textBright,
                                letterSpacing: -0.3)),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(phone,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                              tr(ref, 'shop.client.visits',
                                  "{{n}} ta tashrif",
                                  {'n': '$totalVisits'}),
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () =>
                        _openEdit(context, name: name, phone: phone),
                  ),
                ]),
                const SizedBox(height: 18),

                // Call / SMS actions
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone),
                      label: Text(tr(ref, 'mobile.lopepay.customer.call',
                          "Qo'ng'iroq")),
                      onPressed: phone.isEmpty
                          ? null
                          : () async {
                              final clean =
                                  phone.replaceAll(RegExp(r'[^\d+]'), '');
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
                              final clean =
                                  phone.replaceAll(RegExp(r'[^\d+]'), '');
                              final uri = Uri(scheme: 'sms', path: clean);
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // Visits history
                Text(
                    tr(ref, 'mobile.shop.client.visitsHistory',
                        "Tashriflar tarixi"),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: AppColors.textBright,
                        letterSpacing: -0.3)),
                const SizedBox(height: 10),
                if (visits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        tr(ref, 'mobile.shop.client.noVisits',
                            "Tashriflar yo'q"),
                        style: const TextStyle(color: AppColors.textMuted)),
                  )
                else
                  ...visits.map((v) {
                    final status = (v['status'] ?? '').toString();
                    final c = _statusColor(status);
                    final total =
                        ((v['totalPrice'] ?? 0) as num).toInt();
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  (v['barberName'] ??
                                          tr(ref,
                                              'mobile.shop.masters.singular',
                                              'Master'))
                                      .toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.event_outlined,
                                    size: 11, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(_fmtDate(v['date']?.toString() ?? ''),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                                if ((v['time'] ?? '').toString().isNotEmpty) ...[
                                  const Text("  •  ",
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                  const Icon(Icons.access_time,
                                      size: 11,
                                      color: AppColors.textMuted),
                                  const SizedBox(width: 3),
                                  Text((v['time']).toString(),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                ],
                                if (total > 0) ...[
                                  const Text("  •  ",
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                  Text(
                                      "${_fmt(total)} ${tr(ref, 'common.currency', "so'm")}",
                                      style: const TextStyle(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_statusLabel(status),
                              style: TextStyle(
                                  color: c,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    );
                  }),

                if (smsLogs.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(children: [
                    const Icon(Icons.message_outlined,
                        size: 20, color: AppColors.textBright),
                    const SizedBox(width: 8),
                    Text(
                        tr(ref, 'mobile.shop.client.smsHistory',
                            "SMS tarixi"),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: AppColors.textBright,
                            letterSpacing: -0.3)),
                  ]),
                  const SizedBox(height: 10),
                  ...smsLogs.map((s) {
                    final type = (s['type'] ?? '').toString();
                    final badge = _smsTypeBadge(type);
                    final sentAt = s['sentAt']?.toString() ?? '';
                    final barberName = (s['barberName'] ?? '').toString();
                    final message = (s['message'] ?? '').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badge.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(badge.label,
                                    style: TextStyle(
                                        color: badge.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (barberName.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(barberName,
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11)),
                              ],
                              const Spacer(),
                              Text(_fmtDateTime(sentAt),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10)),
                            ]),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(message,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.4)),
                            ],
                          ]),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEdit(BuildContext context,
      {required String name, required String phone}) async {
    final nameCtrl = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(text: phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'shop.client.editTitle', "Mijozni tahrirlash")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: tr(ref, 'shop.client.name', "Ism")),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: tr(ref, 'shop.client.phone', "Telefon"),
                  hintText: '+998...'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(true),
              child: Text(tr(ref, 'common.save', "Saqlash"))),
        ],
      ),
    );
    try {
      if (ok != true) return;
      final newName = nameCtrl.text.trim();
      final newPhone = phoneCtrl.text.trim();
      if (newName.isEmpty && newPhone.isEmpty) return;
      final body = <String, dynamic>{};
      if (newName.isNotEmpty && newName != name) body['name'] = newName;
      if (newPhone.isNotEmpty && newPhone != phone) body['phone'] = newPhone;
      if (body.isEmpty) return;
      await ref
          .read(dioProvider)
          .patch('/barbershop/clients/$_key', data: body);
      // If phone changed the lookup key changes too — switch keys so
      // refetch hits the right endpoint.
      if (newPhone.isNotEmpty && newPhone != phone) {
        setState(() => _key = newPhone);
      } else {
        ref.invalidate(_clientDetailProvider(_key));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _df.format(d.toLocal());
  }

  String _fmtDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : _dfTime.format(d.toLocal());
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

final _clientDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershop/clients/$key');
  return Map<String, dynamic>.from(res.data as Map);
});
