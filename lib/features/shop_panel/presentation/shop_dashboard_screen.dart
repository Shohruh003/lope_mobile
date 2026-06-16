import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/shop_repository.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(shopMeProvider);
    final stats = ref.watch(shopStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(shopMeProvider);
            ref.invalidate(shopStatsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              me.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (m) => Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(ref, 'mobile.shop.dashboard.salonLabel', "Salonim"),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text((m['name'] ?? '').toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      if ((m['address'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text((m['address']).toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(tr(ref, 'mobile.shop.dashboard.weekTitle', "Bu hafta"),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
              const SizedBox(height: 10),
              stats.when(
                loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted)),
                data: (s) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.4,
                  children: [
                    _StatTile(icon: Icons.event_available, label: tr(ref, 'mobile.shop.dashboard.statBookings', "Bronlar"), value: "${s.bookings}", color: AppColors.primary),
                    _StatTile(icon: Icons.people_outline, label: tr(ref, 'mobile.shop.dashboard.statClients', "Mijozlar"), value: "${s.clients}", color: AppColors.success),
                    _StatTile(icon: Icons.attach_money, label: tr(ref, 'mobile.shop.dashboard.statRevenue', "Daromad"), value: _fmt(s.revenue), color: AppColors.warning),
                    _StatTile(icon: Icons.sms_outlined, label: tr(ref, 'mobile.shop.dashboard.statSms', "SMS"), value: "${s.messages}", color: AppColors.danger),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              Text(tr(ref, 'mobile.shop.dashboard.navManagement', "Boshqaruv"),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              _NavTile(icon: Icons.people_alt_outlined, label: tr(ref, 'mobile.shop.dashboard.navMasters', "Mastera (Barberlar)"), onTap: () => context.push('/shop/barbers')),
              _NavTile(icon: Icons.event_note_outlined, label: tr(ref, 'mobile.shop.dashboard.navBookings', "Salon bronlari"), onTap: () => context.push('/shop/bookings')),
              _NavTile(icon: Icons.people_outline, label: "Mijozlar", onTap: () => context.push('/shop/clients')),
              _NavTile(icon: Icons.account_balance_wallet_outlined, label: tr(ref, 'mobile.shop.dashboard.navTransactions', "Hisob va to'lovlar"), onTap: () => context.push('/shop/transactions')),
              _NavTile(icon: Icons.sms_outlined, label: tr(ref, 'mobile.shop.dashboard.navSms', "SMS tarixi"), onTap: () => context.push('/shop/sms')),
              _NavTile(icon: Icons.storefront_outlined, label: "Salon profili", onTap: () => context.push('/shop/profile')),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;
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
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
          ),
        ),
      ),
    );
  }
}
