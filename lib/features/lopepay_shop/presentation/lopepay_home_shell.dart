import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/lopepay_repository.dart';

/// Bottom-nav shell for the LOPE PAY role (`shop`). Three tabs:
///   - Dashboard (due today, overdue, total receivable)
///   - Customers (list of installment debtors)
///   - Profile (shared with other roles)
class LopepayHomeShell extends ConsumerStatefulWidget {
  const LopepayHomeShell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<LopepayHomeShell> createState() => _LopepayHomeShellState();
}

class _LopepayHomeShellState extends ConsumerState<LopepayHomeShell> {
  late int _index = widget.initialTab.clamp(0, 2);
  static const _tabs = [
    _LopepayDashboard(),
    _LopepayCustomersTab(),
    ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Column(children: [
        Builder(builder: (ctx) => _header(ctx)),
        Expanded(child: IndexedStack(index: _index, children: _tabs)),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
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

  Widget _header(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(children: [
          Row(children: const [
            Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 24),
            SizedBox(width: 6),
            Text("Lope Pay",
                style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ]),
          const Spacer(),
          const NotificationBell(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 24),
            onPressed: () {
              HapticFeedback.selectionClick();
              Scaffold.of(context).openDrawer();
            },
          ),
        ]),
      ),
    );
  }

  Widget _tab(int i, IconData off, IconData on, String label) {
    final active = _index == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () { HapticFeedback.selectionClick(); setState(() => _index = i); },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? on : off,
                  color: active ? AppColors.primary : AppColors.textMuted,
                  size: active ? 24 : 20),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
    final shopMeAsync = ref.watch(lopepayShopMeProvider);
    final dueTodayAsync = ref.watch(lopepayDueTodayProvider);
    final overdueAsync = ref.watch(lopepayOverdueProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(lopepayDashboardProvider);
            ref.invalidate(lopepayShopMeProvider);
            ref.invalidate(lopepayDueTodayProvider);
            ref.invalidate(lopepayOverdueProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ===== Header: shop name + address (mirrors web's h1) =====
              shopMeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name.isEmpty ? "Lope Pay" : s.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textBright, letterSpacing: -0.3)),
                    if (s.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(s.address,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ===== 4 stat tiles (mirrors web: Balance / DueToday / Overdue / AllCustomers) =====
              async.when(
                loading: () => const Column(
                  children: [
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                    ]),
                    SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 92, borderRadius: 12)),
                    ]),
                  ],
                ),
                error: (e, _) => SizedBox(
                  height: 240,
                  child: AppErrorState(
                    message: humanize(e),
                    onRetry: () => ref.invalidate(lopepayDashboardProvider),
                  ),
                ),
                data: (d) => GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.45,
                  children: [
                    _MetricTile(
                        label: tr(ref, 'mobile.lopepay.home.balance', "Balans"),
                        value: shopMeAsync.maybeWhen(
                          data: (s) => "${_fmt(s.ownerBalance)} ${tr(ref, 'common.currency', "so'm")}",
                          orElse: () => "—",
                        ),
                        color: AppColors.primary, icon: Icons.account_balance_wallet_outlined),
                    _MetricTile(
                        label: tr(ref, 'mobile.lopepay.home.dueToday', "Bugun tushishi kerak"),
                        value: "${_fmt(d.dueToday)} ${tr(ref, 'common.currency', "so'm")}",
                        color: AppColors.warning, icon: Icons.event_available),
                    _MetricTile(
                        label: tr(ref, 'mobile.lopepay.home.overdue', "Muddati o'tgan"),
                        value: "${_fmt(d.overdue)} ${tr(ref, 'common.currency', "so'm")}",
                        color: AppColors.danger, icon: Icons.warning_amber_rounded),
                    _MetricTile(
                        label: tr(ref, 'mobile.lopepay.home.allCustomers', "Hammasi"),
                        value: shopMeAsync.maybeWhen(
                          data: (s) => "${s.totalInstallments}",
                          orElse: () => "${d.activeCustomers}",
                        ),
                        color: AppColors.success, icon: Icons.people_outline),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ===== Due today list =====
              _SectionHeader(
                  icon: Icons.event_available,
                  label: tr(ref, 'mobile.lopepay.home.dueTodayTitle', "Bugun to'lov kuni"),
                  iconColor: AppColors.warning,
                  onViewAll: () =>
                      context.push('/lopepay/installments?status=due_today')),
              const SizedBox(height: 8),
              dueTodayAsync.when(
                loading: () => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSkeleton(height: 52, borderRadius: 10),
                    SizedBox(height: 6),
                    AppSkeleton(height: 52, borderRadius: 10),
                  ],
                ),
                error: (e, _) => Text(humanize(e),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(tr(ref, 'mobile.lopepay.home.noDueToday',
                            "Bugun to'lov kerak emas"),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ),
                    );
                  }
                  return Column(
                    children: list.take(5).map((inst) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _InstallmentRow(item: inst, isOverdue: false),
                    )).toList(),
                  );
                },
              ),

              const SizedBox(height: 18),

              // ===== Overdue list =====
              overdueAsync.maybeWhen(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _SectionHeader(
                        icon: Icons.warning_amber,
                        label: tr(ref, 'mobile.lopepay.home.overdue', "Muddati o'tgan"),
                        iconColor: AppColors.danger,
                        onViewAll: () => context
                            .push('/lopepay/installments?status=overdue')),
                    const SizedBox(height: 8),
                    ...list.take(5).map((inst) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _InstallmentRow(item: inst, isOverdue: true),
                    )),
                  ]);
                },
                orElse: () => const SizedBox.shrink(),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: -0.3, color: AppColors.textBright)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section header inside the dashboard — used for "Bugun to'lov kuni" and
/// "Muddati o'tgan" groups. Matches the web's `h2` rows with the colored
/// leading icon.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon,
      required this.label,
      required this.iconColor,
      this.onViewAll});
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: iconColor, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: iconColor == AppColors.danger
                    ? AppColors.danger
                    : AppColors.textBright)),
      ),
      if (onViewAll != null)
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onViewAll,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Hammasi",
                  style: TextStyle(
                      color: iconColor == AppColors.danger
                          ? AppColors.danger
                          : AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right,
                  size: 16,
                  color: iconColor == AppColors.danger
                      ? AppColors.danger
                      : AppColors.primary),
            ]),
          ),
        ),
    ]);
  }
}

/// Installment row card — name + phone + due-date + amount badge.
/// Used in both "Due today" and "Overdue" sections.
class _InstallmentRow extends ConsumerWidget {
  const _InstallmentRow({required this.item, required this.isOverdue});
  final Map<String, dynamic> item;
  final bool isOverdue;

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Backend installments have no nested customer object — flat
    // customerName / customerPhone live on the row itself, and the
    // payable each month is monthlyPayment (see lopepay fix 8aa66e8).
    final name = (item['customerName'] ?? '').toString();
    final phone = (item['customerPhone'] ?? '').toString();
    final monthly = ((item['monthlyPayment'] ??
            item['monthlyAmount'] ??
            item['amount'] ??
            0) as num)
        .toInt();
    final color = isOverdue ? AppColors.danger : AppColors.warning;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      // Detail screen aggregates by phone — backend has no per-customer
      // endpoint and customer.id isn't on the installment response.
      onTap: phone.isEmpty
          ? null
          : () => context.push(
              '/lopepay/customers/${Uri.encodeComponent(phone)}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isOverdue ? color.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              (name.isNotEmpty ? name[0] : '?').toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz") : name,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppColors.textBright)),
                if (phone.isNotEmpty)
                  Text(phone,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${_fmt(monthly)} ${tr(ref, 'common.currency', "so'm")}",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
              if (isOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(tr(ref, 'mobile.lopepay.home.overdueShort', "o'tib ketgan"),
                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ]),
      ),
    );
  }
}

class _LopepayCustomersTab extends ConsumerStatefulWidget {
  const _LopepayCustomersTab();

  @override
  ConsumerState<_LopepayCustomersTab> createState() =>
      _LopepayCustomersTabState();
}

class _LopepayCustomersTabState extends ConsumerState<_LopepayCustomersTab> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  String _query = '';
  String _filter = 'all'; // 'all' | 'overdue' | 'dueToday' | 'paidOff'

  bool _matchesFilter(LopepayCustomer c, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final overdue = c.nextDue != null && c.nextDue!.isBefore(today);
    final dueToday = c.nextDue != null &&
        c.nextDue!.year == today.year &&
        c.nextDue!.month == today.month &&
        c.nextDue!.day == today.day;
    final paidOff = c.totalDebt <= 0;
    switch (_filter) {
      case 'overdue':
        return overdue;
      case 'dueToday':
        return dueToday;
      case 'paidOff':
        return paidOff;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepayCustomersProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/lopepay/customers/new'),
        icon: const Icon(Icons.add),
        label: Text(tr(ref, 'mobile.lopepay.customerForm.addBtn',
            "Rassrochka qo'shish")),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const AppListSkeleton(),
          error: (e, _) => AppErrorState(message: humanize(e)),
          data: (rawList) {
            final now = DateTime.now();
            final list = rawList.where((c) {
              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                final hit = c.name.toLowerCase().contains(q) ||
                    c.phone.contains(_query);
                if (!hit) return false;
              }
              return _matchesFilter(c, now);
            }).toList();

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.refresh(lopepayCustomersProvider.future),
              child: Column(children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                // Filter chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: tr(ref, 'common.all', "Hammasi"),
                        on: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      _FilterChip(
                        label: tr(ref, 'mobile.lopepay.customer.statusOverdue',
                            "Muddati o'tgan"),
                        on: _filter == 'overdue',
                        onTap: () => setState(() => _filter = 'overdue'),
                      ),
                      _FilterChip(
                        label: tr(ref, 'mobile.lopepay.home.dueToday',
                            "Bugun tushishi kerak"),
                        on: _filter == 'dueToday',
                        onTap: () => setState(() => _filter = 'dueToday'),
                      ),
                      _FilterChip(
                        label: tr(ref, 'mobile.lopepay.customer.statusPaid',
                            "To'langan"),
                        on: _filter == 'paidOff',
                        onTap: () => setState(() => _filter = 'paidOff'),
                      ),
                    ],
                  ),
                ),
                if (list.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          rawList.isEmpty
                              ? tr(ref, 'mobile.lopepay.home.noCustomers',
                                  "Mijozlar yo'q")
                              : tr(ref, 'common.noResults',
                                  "Filterga mos natija yo'q"),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final overdue = c.nextDue != null &&
                            c.nextDue!.isBefore(DateTime.now());
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push(
                        '/lopepay/customers/${Uri.encodeComponent(c.id)}'),
                    child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: overdue ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: (overdue ? AppColors.danger : AppColors.primary).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text((c.name.isNotEmpty ? c.name[0] : '?').toUpperCase(),
                            style: TextStyle(color: overdue ? AppColors.danger : AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600)),
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
                              Text("${_fmt(c.totalDebt)} ${tr(ref, 'common.currency', "so'm")}",
                                  style: TextStyle(color: overdue ? AppColors.danger : AppColors.warning, fontWeight: FontWeight.w600, fontSize: 14)),
                              if (c.nextDue != null) ...[
                                const SizedBox(width: 8),
                                Text("• ${_df.format(c.nextDue!)}", style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                  ),
                  ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                      },
                    ),
                  ),
              ]),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});
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
            color: on ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? AppColors.primary : AppColors.border),
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
