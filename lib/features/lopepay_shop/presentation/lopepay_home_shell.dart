import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/colors.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/lopepay_repository.dart';

/// Bottom-nav shell for the LOPE PAY role (`shop`). Three tabs:
///   - Dashboard (due today, overdue, total receivable)
///   - Customers (list of installment debtors)
///   - Profile (shared with other roles)
class LopepayHomeShell extends ConsumerStatefulWidget {
  const LopepayHomeShell({super.key});
  @override
  ConsumerState<LopepayHomeShell> createState() => _LopepayHomeShellState();
}

class _LopepayHomeShellState extends ConsumerState<LopepayHomeShell> {
  int _index = 0;
  static const _tabs = [
    _LopepayDashboard(),
    _LopepayCustomersTab(),
    ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              _tab(0, Icons.dashboard_outlined, Icons.dashboard, "Boshqaruv"),
              _tab(1, Icons.people_outline, Icons.people, "Mijozlar"),
              _tab(2, Icons.person_outline, Icons.person, "Profil"),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i, IconData off, IconData on, String label) {
    final active = _index == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _index = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? on : off, color: active ? AppColors.primary : AppColors.textMuted, size: 24)
                  .animate(target: active ? 1 : 0)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 200.ms),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textMuted,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _LopepayDashboard extends ConsumerWidget {
  const _LopepayDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lopepayDashboardProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(lopepayDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text("Lope Pay",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.textBright)),
              const SizedBox(height: 4),
              const Text("Qarz va rassrochka boshqaruvi",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 20),
              async.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
                data: (d) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _MetricTile(label: "Bugun tushishi kerak", value: "${_fmt(d.dueToday)} so'm", color: AppColors.warning, icon: Icons.event_available),
                    _MetricTile(label: "Muddati o'tgan", value: "${_fmt(d.overdue)} so'm", color: AppColors.danger, icon: Icons.warning_amber_rounded),
                    _MetricTile(label: "Jami olinishi kerak", value: "${_fmt(d.totalReceivable)} so'm", color: AppColors.primary, icon: Icons.account_balance_wallet_outlined),
                    _MetricTile(label: "Faol mijozlar", value: "${d.activeCustomers}", color: AppColors.success, icon: Icons.people_outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LopepayCustomersTab extends ConsumerWidget {
  const _LopepayCustomersTab();

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lopepayCustomersProvider);
    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Xato: $e")),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text("Mijozlar yo'q", style: TextStyle(color: AppColors.textMuted)),
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.refresh(lopepayCustomersProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: list.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final overdue = c.nextDue != null && c.nextDue!.isBefore(DateTime.now());
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: overdue ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: (overdue ? AppColors.danger : AppColors.primary).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text((c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
                            style: TextStyle(color: overdue ? AppColors.danger : AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800)),
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
                              Text("${_fmt(c.totalDebt)} so'm",
                                  style: TextStyle(color: overdue ? AppColors.danger : AppColors.warning, fontWeight: FontWeight.w800, fontSize: 13)),
                              if (c.nextDue != null) ...[
                                const SizedBox(width: 8),
                                Text("• ${_df.format(c.nextDue!)}", style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ]),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                        onPressed: c.phone.isEmpty ? null : () async {
                          final clean = c.phone.replaceAll(RegExp(r'[^\d+]'), '');
                          final uri = Uri(scheme: 'tel', path: clean);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        },
                      ),
                    ]),
                  ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                },
              ),
            );
          },
        ),
      ),
    );
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
