import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_clients_repository.dart';

/// Full client history with search + visit-bucket filters. Mirrors the web's
/// Days-Since-Visit segmentation (0-7, 8-20, 21-60, 60+).
class BarberClientsScreen extends ConsumerStatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  ConsumerState<BarberClientsScreen> createState() => _BarberClientsScreenState();
}

class _BarberClientsScreenState extends ConsumerState<BarberClientsScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  String _query = '';
  String _bucket = 'all'; // 'all' | '0-7' | '8-20' | '21-60' | '60+'

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(barberClientsProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'barberMyClients.title', "Mijozlarim"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          final now = DateTime.now();
          final filtered = list.where((c) {
            // Search
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final hit = c.name.toLowerCase().contains(q) || c.phone.contains(_query);
              if (!hit) return false;
            }
            // Days-since-visit bucket
            if (_bucket != 'all') {
              if (c.lastVisit == null) return _bucket == '60+';
              final days = now.difference(c.lastVisit!).inDays;
              switch (_bucket) {
                case '0-7': if (days > 7) return false; break;
                case '8-20': if (days < 8 || days > 20) return false; break;
                case '21-60': if (days < 21 || days > 60) return false; break;
                case '60+': if (days <= 60) return false; break;
              }
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textBright),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 22),
                    hintText: tr(ref, 'barberMyClients.searchPlaceholder', "Ism yoki telefon"),
                    isDense: true,
                  ),
                ),
              ),
              // Bucket chips
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _Chip(label: tr(ref, 'common.all', "Hammasi"), on: _bucket == 'all', onTap: () => setState(() => _bucket = 'all')),
                    _Chip(label: tr(ref, 'barberMyClients.days07', "0-7 kun"), on: _bucket == '0-7', onTap: () => setState(() => _bucket = '0-7')),
                    _Chip(label: tr(ref, 'barberMyClients.days820', "8-20 kun"), on: _bucket == '8-20', onTap: () => setState(() => _bucket = '8-20')),
                    _Chip(label: tr(ref, 'barberMyClients.days2160', "21-60 kun"), on: _bucket == '21-60', onTap: () => setState(() => _bucket = '21-60')),
                    _Chip(label: tr(ref, 'barberMyClients.days60plus', "60+ kun"), on: _bucket == '60+', onTap: () => setState(() => _bucket = '60+')),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(tr(ref, 'common.noResults', "Filterga mos mijoz topilmadi"),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.refresh(barberClientsProvider(user.id).future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (c.name.isNotEmpty ? c.name[0] : (c.phone.isNotEmpty ? c.phone[c.phone.length - 1] : '?')).toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name.isEmpty ? c.phone : c.name,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text("${c.bookingsCount} ${tr(ref, 'barberMyClients.bookingsShort', 'bron')}",
                                          style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 10)),
                                    ),
                                    if (c.lastVisit != null) ...[
                                      const SizedBox(width: 6),
                                      Text("• ${_df.format(c.lastVisit!.toLocal())}",
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    ],
                                    if (c.totalSpent > 0) ...[
                                      const SizedBox(width: 6),
                                      Text("• ${_fmt(c.totalSpent)} ${tr(ref, 'common.currency', "so'm")}",
                                          style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: 11)),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                              onPressed: c.phone.isEmpty ? null : () => _call(c.phone),
                            ),
                          ]),
                        ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _call(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.25),
      ),
    );
  }
}
