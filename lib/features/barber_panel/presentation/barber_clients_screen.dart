import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_clients_repository.dart';

class BarberClientsScreen extends ConsumerWidget {
  const BarberClientsScreen({super.key});

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final async = ref.watch(barberClientsProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text("Mijozlarim")),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: AppColors.textMuted),
                    SizedBox(height: 14),
                    Text("Hali mijozlar yo'q",
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(barberClientsProvider(user.id).future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = list[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (c.name.isNotEmpty ? c.name[0] : (c.phone.isNotEmpty ? c.phone[c.phone.length - 1] : '?'))
                            .toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name.isEmpty ? c.phone : c.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          if (c.phone.isNotEmpty)
                            Text(c.phone, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("${c.bookingsCount} bron",
                                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 10)),
                            ),
                            if (c.lastVisit != null) ...[
                              const SizedBox(width: 6),
                              Text("• ${_df.format(c.lastVisit!.toLocal())}",
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                            ],
                            if (c.totalSpent > 0) ...[
                              const SizedBox(width: 6),
                              Text("• ${_fmt(c.totalSpent)} so'm",
                                  style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 10)),
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
          );
        },
      ),
    );
  }

  Future<void> _call(String phone) async {
    // Strip everything except digits and '+' so the dialer can't be tricked
    // into other schemes via a malformed phone field.
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
