import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';

class ShopClientDetailScreen extends ConsumerStatefulWidget {
  const ShopClientDetailScreen({super.key, required this.clientKey});
  final String clientKey;
  @override
  ConsumerState<ShopClientDetailScreen> createState() =>
      _ShopClientDetailScreenState();
}

class _ShopClientDetailScreenState
    extends ConsumerState<ShopClientDetailScreen> {
  static final _df = DateFormat('dd.MM.yyyy');
  static final _dfTime = DateFormat('dd.MM.yyyy HH:mm');

  late String _key = widget.clientKey;

  AppBadgeVariant _statusVariant(String status) {
    switch (status) {
      case 'completed':
        return AppBadgeVariant.success;
      case 'cancelled':
        return AppBadgeVariant.danger;
      default:
        return AppBadgeVariant.info;
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

  ({String label, AppBadgeVariant variant}) _smsTypeBadge(String type) {
    switch (type) {
      case 'CONFIRMATION':
        return (
          label: tr(ref, 'shop.smsTypes.confirmation', 'Tasdiqlash'),
          variant: AppBadgeVariant.info,
        );
      case 'REMINDER':
        return (
          label: tr(ref, 'shop.smsTypes.reminder', 'Eslatma'),
          variant: AppBadgeVariant.warning,
        );
      case 'RETENTION':
        return (
          label: tr(ref, 'shop.smsTypes.retention', 'Reklama'),
          variant: AppBadgeVariant.primary,
        );
      default:
        return (label: type, variant: AppBadgeVariant.neutral);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_clientDetailProvider(_key));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz"),
            style: AppText.titleMd),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
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
              padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.pageBottom(context)),
              children: [
                _HeroCard(
                  name: name,
                  phone: phone,
                  avatar: avatar,
                  totalVisits: totalVisits,
                  onEdit: () => _openEdit(context, name: name, phone: phone),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'mobile.lopepay.customer.call',
                          "Qo'ng'iroq"),
                      leadingIcon: Icons.phone,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
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
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: "SMS",
                      leadingIcon: Icons.sms,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
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
                const SizedBox(height: AppSpacing.xxl),

                _SectionHeader(
                  icon: Icons.history,
                  title: tr(ref, 'mobile.shop.client.visitsHistory',
                      "Tashriflar tarixi"),
                ),
                const SizedBox(height: AppSpacing.md),
                if (visits.isEmpty)
                  AppCard(
                    variant: AppCardVariant.flat,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Text(
                            tr(ref, 'mobile.shop.client.noVisits',
                                "Tashriflar yo'q"),
                            style: AppText.bodySm),
                      ),
                    ),
                  )
                else
                  ...visits.asMap().entries.map((entry) {
                    final i = entry.key;
                    final v = entry.value;
                    final status = (v['status'] ?? '').toString();
                    final total = ((v['totalPrice'] ?? 0) as num).toInt();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: AppRadius.rMd,
                            ),
                            child: const Icon(Icons.event_note,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: AppSpacing.md),
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
                                    style: AppText.titleSm.copyWith(fontSize: 14)),
                                const SizedBox(height: 3),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(Icons.event_outlined,
                                        size: 11,
                                        color: context.colors.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                        _fmtDate(
                                            v['date']?.toString() ?? ''),
                                        style: AppText.caption
                                            .copyWith(fontSize: 11)),
                                    if ((v['time'] ?? '').toString().isNotEmpty) ...[
                                      Text("  вЂў  ",
                                          style: AppText.caption
                                              .copyWith(fontSize: 11)),
                                      Icon(Icons.access_time,
                                          size: 11,
                                          color: context.colors.textMuted),
                                      const SizedBox(width: 3),
                                      Text((v['time']).toString(),
                                          style: AppText.caption
                                              .copyWith(fontSize: 11)),
                                    ],
                                    if (total > 0) ...[
                                      Text("  вЂў  ",
                                          style: AppText.caption
                                              .copyWith(fontSize: 11)),
                                      Text(
                                          "${_fmt(total)} ${tr(ref, 'common.currency', "so'm")}",
                                          style: AppText.caption.copyWith(
                                              color: AppColors.warning,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppBadge(
                            label: _statusLabel(status),
                            variant: _statusVariant(status),
                          ),
                        ]),
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: (i * 20).ms);
                  }),

                if (smsLogs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _SectionHeader(
                    icon: Icons.message_outlined,
                    title: tr(ref, 'mobile.shop.client.smsHistory',
                        "SMS tarixi"),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...smsLogs.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final type = (s['type'] ?? '').toString();
                    final badge = _smsTypeBadge(type);
                    final sentAt = s['sentAt']?.toString() ?? '';
                    final barberName = (s['barberName'] ?? '').toString();
                    final message = (s['message'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                AppBadge(
                                    label: badge.label,
                                    variant: badge.variant),
                                if (barberName.isNotEmpty) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(barberName,
                                      style: AppText.caption
                                          .copyWith(fontSize: 11)),
                                ],
                                const Spacer(),
                                Text(_fmtDateTime(sentAt),
                                    style: AppText.caption
                                        .copyWith(fontSize: 10)),
                              ]),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(message, style: AppText.bodySm),
                              ],
                            ]),
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: (i * 20).ms);
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
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(tr(ref, 'shop.client.editTitle', "Mijozni tahrirlash"),
            style: AppText.titleMd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: tr(ref, 'shop.client.name', "Ism")),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppPhoneField(
              controller: phoneCtrl,
              hintText: '+998 XX-XXX-XX-XX',
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
      // Canonical +998XXXXXXXXX for the backend (empty when the field
      // is blank / partially filled).
      final newPhone = AppPhoneField.rawPhone(phoneCtrl.text);
      if (newName.isEmpty && newPhone.isEmpty) return;
      final body = <String, dynamic>{};
      if (newName.isNotEmpty && newName != name) body['name'] = newName;
      if (newPhone.isNotEmpty && newPhone != phone) body['phone'] = newPhone;
      if (body.isEmpty) return;
      await ref
          .read(dioProvider)
          .patch('/barbershop/clients/$_key', data: body);
      if (newPhone.isNotEmpty && newPhone != phone) {
        setState(() => _key = newPhone);
      } else {
        ref.invalidate(_clientDetailProvider(_key));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.name,
    required this.phone,
    required this.avatar,
    required this.totalVisits,
    required this.onEdit,
  });
  final String name;
  final String phone;
  final String avatar;
  final int totalVisits;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.16),
          AppColors.primary.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: assetUrl(avatar),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: context.colors.surface,
                    alignment: Alignment.center,
                    child: Text(
                        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                        style: AppText.titleLg
                            .copyWith(color: AppColors.primary)),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? phone : name,
                  style: AppText.titleMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(phone, style: AppText.bodySm),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppBadge(
                label: tr(ref, 'shop.client.visits',
                    "{{n}} ta tashrif", {'n': '$totalVisits'}),
                variant: AppBadgeVariant.primary,
                icon: Icons.event_available,
              ),
            ],
          ),
        ),
        TapScale(
          onTap: onEdit,
          haptic: HapticStrength.light,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.6),
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(Icons.edit_outlined,
                color: context.colors.textSecondary, size: 18),
          ),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(title, style: AppText.titleMd.copyWith(fontSize: 16)),
    ]);
  }
}

final _clientDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, key) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershop/clients/$key');
  return Map<String, dynamic>.from(res.data as Map);
});
