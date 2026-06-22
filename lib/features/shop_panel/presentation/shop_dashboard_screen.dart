import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/shadcn.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // Salon header
              me.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (m) => ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const ShadIconBubble(icon: Icons.storefront_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(ref, 'mobile.shop.dashboard.salonLabel', "Salonim"),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text((m['name'] ?? '').toString(),
                              style: const TextStyle(color: AppColors.textBright, fontSize: 17, fontWeight: FontWeight.w700)),
                          if ((m['address'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text((m['address']).toString(),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 18),

              ShadSectionLabel(tr(ref, 'mobile.shop.dashboard.weekTitle', "BU HAFTA")),
              const SizedBox(height: 8),
              stats.when(
                loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text("${tr(ref, 'common.error', 'Xatolik')}: $e", style: const TextStyle(color: AppColors.textMuted)),
                data: (s) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _StatTile(icon: Icons.event_available, label: tr(ref, 'mobile.shop.dashboard.statBookings', "Bronlar"), value: "${s.bookings}", color: AppColors.primary),
                    _StatTile(icon: Icons.people_outline, label: tr(ref, 'mobile.shop.dashboard.statClients', "Mijozlar"), value: "${s.clients}", color: AppColors.success),
                    _StatTile(icon: Icons.attach_money, label: tr(ref, 'mobile.shop.dashboard.statRevenue', "Daromad"), value: _fmt(s.revenue), color: AppColors.warning),
                    _StatTile(icon: Icons.sms_outlined, label: tr(ref, 'mobile.shop.dashboard.statSms', "SMS"), value: "${s.messages}", color: AppColors.danger),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              ShadSectionLabel(tr(ref, 'mobile.shop.dashboard.navManagement', "BOSHQARUV")),
              const SizedBox(height: 8),
              ShadTileGroup(children: [
                ShadTile(icon: Icons.people_alt_outlined, label: tr(ref, 'mobile.shop.dashboard.navMasters', "Mastera (Barberlar)"), onTap: () => context.push('/shop/barbers')),
                ShadTile(icon: Icons.event_note_outlined, label: tr(ref, 'mobile.shop.dashboard.navBookings', "Salon bronlari"), onTap: () => context.push('/shop/bookings')),
                ShadTile(icon: Icons.people_outline, label: "Mijozlar", onTap: () => context.push('/shop/clients')),
                ShadTile(icon: Icons.account_balance_wallet_outlined, label: tr(ref, 'mobile.shop.dashboard.navTransactions', "Hisob va to'lovlar"), onTap: () => context.push('/shop/transactions')),
                ShadTile(icon: Icons.sms_outlined, label: tr(ref, 'mobile.shop.dashboard.navSms', "SMS tarixi"), onTap: () => context.push('/shop/sms')),
                ShadTile(icon: Icons.storefront_outlined, label: "Salon profili", onTap: () => context.push('/shop/profile')),
              ]),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5, color: AppColors.textBright)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
