import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';
import 'bulk_send_progress_modal.dart';

/// Shop-owner view of all clients. Mirrors the web BarbershopClients
/// page: search bar, days-since-visit bucket filter, bulk-select
/// checkboxes, and a "Send retention SMS" footer that POSTs to
/// /barbershop/send-retention-sms for the chosen phones.
class ShopClientsScreen extends ConsumerStatefulWidget {
  const ShopClientsScreen({super.key});

  @override
  ConsumerState<ShopClientsScreen> createState() => _ShopClientsScreenState();
}

class _ShopClientsScreenState extends ConsumerState<ShopClientsScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  String _query = '';
  String _bucket = 'all'; // 'all' | '0-7' | '8-20' | '21-60' | '60+'
  final Set<String> _selected = {};
  bool _sending = false;

  bool _inBucket(ShopClient c, DateTime now) {
    if (_bucket == 'all') return true;
    if (c.lastVisit == null) return _bucket == '60+';
    final days = now.difference(c.lastVisit!).inDays;
    switch (_bucket) {
      case '0-7':
        return days <= 7;
      case '8-20':
        return days >= 8 && days <= 20;
      case '21-60':
        return days >= 21 && days <= 60;
      case '60+':
        return days > 60;
      default:
        return true;
    }
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(tr(ref, 'mobile.shop.clients.bulkSendTitle',
            "Tanlanganlarga SMS yuborilsinmi?")),
        content: Text(tr(ref, 'mobile.shop.clients.bulkSendMsg',
            "{{n}} ta mijozga retention SMS jo'natiladi.",
            {'n': '${_selected.length}'})),
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
    setState(() => _sending = true);
    try {
      final res = await ref
          .read(shopRepositoryProvider)
          .sendRetentionSms(_selected.toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      // Open the progress modal — it polls /blast-jobs/:id until done
      // and shows sent / skipped / out-of-balance + a failed-rows list.
      if (res.jobId.isNotEmpty) {
        await BulkSendProgressModal.show(context, jobId: res.jobId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'mobile.shop.clients.bulkSendQueued',
                "{{n}} ta SMS navbatga qo'shildi",
                {'n': '${res.total}'}))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggleSelectAll(List<ShopClient> visible) {
    final allSelected = visible.every((c) => _selected.contains(c.phone));
    setState(() {
      if (allSelected) {
        for (final c in visible) {
          _selected.remove(c.phone);
        }
      } else {
        for (final c in visible) {
          if (c.phone.isNotEmpty) _selected.add(c.phone);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopClientsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'shop.nav.clients', "Mijozlar"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (rawList) {
          final now = DateTime.now();
          final filtered = rawList.where((c) {
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final hit =
                  c.name.toLowerCase().contains(q) || c.phone.contains(_query);
              if (!hit) return false;
            }
            return _inBucket(c, now);
          }).toList();

          return Stack(children: [
            RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.refresh(shopClientsProvider.future),
              child: Column(children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
                // Bucket filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _BucketChip(
                          label: tr(ref, 'common.all', "Hammasi"),
                          on: _bucket == 'all',
                          onTap: () => setState(() => _bucket = 'all')),
                      _BucketChip(
                          label: '0-7',
                          on: _bucket == '0-7',
                          onTap: () => setState(() => _bucket = '0-7')),
                      _BucketChip(
                          label: '8-20',
                          on: _bucket == '8-20',
                          onTap: () => setState(() => _bucket = '8-20')),
                      _BucketChip(
                          label: '21-60',
                          on: _bucket == '21-60',
                          onTap: () => setState(() => _bucket = '21-60')),
                      _BucketChip(
                          label: '60+',
                          on: _bucket == '60+',
                          onTap: () => setState(() => _bucket = '60+')),
                    ],
                  ),
                ),
                // Select-all row (only if at least one row visible)
                if (filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(children: [
                      InkWell(
                        onTap: () => _toggleSelectAll(filtered),
                        child: Row(children: [
                          Icon(
                              filtered.every((c) => _selected.contains(c.phone))
                                  ? Icons.check_box
                                  : (filtered.any(
                                          (c) => _selected.contains(c.phone))
                                      ? Icons.indeterminate_check_box
                                      : Icons.check_box_outline_blank),
                              size: 18,
                              color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                              tr(ref, 'mobile.shop.clients.selectAll',
                                  "Hammasini tanlash"),
                              style: const TextStyle(
                                  color: AppColors.textBright, fontSize: 12)),
                        ]),
                      ),
                      const Spacer(),
                      Text("${filtered.length}",
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 56, color: AppColors.textMuted),
                                const SizedBox(height: 14),
                                Text(
                                    rawList.isEmpty
                                        ? tr(ref, 'mobile.shop.clients.empty',
                                            "Mijozlar ro'yxati bo'sh")
                                        : tr(ref, 'common.noResults',
                                            "Hech narsa topilmadi"),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 15)),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return _ClientRow(
                              c: c,
                              df: _df,
                              selected: _selected.contains(c.phone),
                              onToggle: () => setState(() {
                                if (_selected.contains(c.phone)) {
                                  _selected.remove(c.phone);
                                } else if (c.phone.isNotEmpty) {
                                  _selected.add(c.phone);
                                }
                              }),
                            ).animate().fadeIn(
                                duration: 250.ms, delay: (i * 20).ms);
                          },
                        ),
                ),
              ]),
            ),
            if (_selected.isNotEmpty)
              Positioned(
                left: 16, right: 16, bottom: 16,
                child: ElevatedButton.icon(
                  icon: _sending
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: Text(
                      tr(ref, 'mobile.shop.clients.sendSmsBtn',
                          "{{n}} ta mijozga SMS",
                          {'n': '${_selected.length}'}),
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _sending ? null : _send,
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _BucketChip extends StatelessWidget {
  const _BucketChip({required this.label, required this.on, required this.onTap});
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
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                  color: on ? AppColors.primary : AppColors.textMuted)),
        ),
      ),
    );
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.c,
    required this.df,
    required this.selected,
    required this.onToggle,
  });
  final ShopClient c;
  final DateFormat df;
  final bool selected;
  final VoidCallback onToggle;

  Future<void> _call() async {
    final clean = c.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () =>
          context.push('/shop/clients/${Uri.encodeComponent(c.phone)}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                  selected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 20),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(builder: (context) {
                  return Text(c.name.isEmpty ? c.phone : c.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14));
                }),
                if (c.phone.isNotEmpty)
                  Text(c.phone,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
                Consumer(builder: (context, ref, _) {
                  if (c.lastVisit == null) return const SizedBox.shrink();
                  return Text(
                      "${tr(ref, 'barberMyClients.lastVisit', 'Oxirgi tashrif')}: ${df.format(c.lastVisit!.toLocal())}",
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12));
                }),
              ],
            ),
          ),
          if (c.bookingsCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("${c.bookingsCount}",
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.phone_outlined,
                color: AppColors.primary, size: 20),
            onPressed: c.phone.isEmpty ? null : _call,
          ),
        ]),
      ),
    );
  }
}
