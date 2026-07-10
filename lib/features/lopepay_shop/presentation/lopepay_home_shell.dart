import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/notification_bell.dart';
import '../../profile/presentation/profile_screen.dart';
import '../data/lopepay_repository.dart';

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
            height: 68,
            child: Row(children: [
              _tab(0, Icons.dashboard_outlined, Icons.dashboard,
                  tr(ref, 'mobile.lopepay.tabs.dashboard', "Boshqaruv")),
              _tab(1, Icons.people_outline, Icons.people,
                  tr(ref, 'mobile.lopepay.tabs.customers', "Mijozlar")),
              _tab(2, Icons.person_outline, Icons.person,
                  tr(ref, 'mobile.lopepay.tabs.profile', "Profil")),
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
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadius.rSm,
              boxShadow: AppShadows.primaryGlow(AppColors.primary),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text("Lope Pay",
              style: AppText.titleMd.copyWith(color: AppColors.primary)),
          const Spacer(),
          const NotificationBell(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.menu_rounded,
                color: AppColors.textPrimary, size: 24),
            onPressed: () {
              AppHaptics.selection();
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
      child: TapScale(
        onTap: () {
          AppHaptics.selection();
          setState(() => _index = i);
        },
        haptic: HapticStrength.none,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 4),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: AppRadius.rPill,
                ),
                child: Icon(active ? on : off,
                    color:
                        active ? AppColors.primary : AppColors.textMuted,
                    size: 22),
              ),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption.copyWith(
                    fontSize: 10,
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? AppColors.primary
                        : AppColors.textMuted,
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
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
            children: [
              shopMeAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (s) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name.isEmpty ? "Lope Pay" : s.name,
                        style: AppText.titleLg),
                    if (s.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(s.address, style: AppText.bodySm),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              async.when(
                loading: () => const Column(
                  children: [
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 96, borderRadius: 14)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 96, borderRadius: 14)),
                    ]),
                    SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: AppSkeleton(height: 96, borderRadius: 14)),
                      SizedBox(width: 8),
                      Expanded(child: AppSkeleton(height: 96, borderRadius: 14)),
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
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.4,
                  children: [
                    _MetricTile(
                      label: tr(ref, 'mobile.lopepay.home.balance', "Balans"),
                      value: shopMeAsync.maybeWhen(
                        data: (s) =>
                            "${_fmt(s.ownerBalance)} ${tr(ref, 'common.currency', "so'm")}",
                        orElse: () => "—",
                      ),
                      color: AppColors.primary,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    _MetricTile(
                      label: tr(ref, 'mobile.lopepay.home.dueToday',
                          "Bugun tushishi kerak"),
                      value:
                          "${_fmt(d.dueToday)} ${tr(ref, 'common.currency', "so'm")}",
                      color: AppColors.warning,
                      icon: Icons.event_available,
                    ),
                    _MetricTile(
                      label: tr(ref, 'mobile.lopepay.home.overdue',
                          "Muddati o'tgan"),
                      value:
                          "${_fmt(d.overdue)} ${tr(ref, 'common.currency', "so'm")}",
                      color: AppColors.danger,
                      icon: Icons.warning_amber_rounded,
                    ),
                    _MetricTile(
                      label: tr(ref, 'mobile.lopepay.home.allCustomers', "Hammasi"),
                      value: shopMeAsync.maybeWhen(
                        data: (s) => "${s.totalInstallments}",
                        orElse: () => "${d.activeCustomers}",
                      ),
                      color: AppColors.success,
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              _SectionHeader(
                icon: Icons.event_available,
                label: tr(ref, 'mobile.lopepay.home.dueTodayTitle',
                    "Bugun to'lov kuni"),
                iconColor: AppColors.warning,
                viewAllLabel: tr(ref, 'common.all', "Hammasi"),
                onViewAll: () =>
                    context.push('/lopepay/installments?status=due_today'),
              ),
              const SizedBox(height: AppSpacing.sm),
              dueTodayAsync.when(
                loading: () => const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSkeleton(height: 56, borderRadius: 10),
                    SizedBox(height: 6),
                    AppSkeleton(height: 56, borderRadius: 10),
                  ],
                ),
                error: (e, _) => Text(humanize(e), style: AppText.caption),
                data: (list) {
                  if (list.isEmpty) {
                    return AppCard(
                      variant: AppCardVariant.flat,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg),
                      child: Center(
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.celebration,
                                  size: 16, color: AppColors.success),
                              const SizedBox(width: 6),
                              Text(
                                  tr(ref,
                                      'mobile.lopepay.home.noDueToday',
                                      "Bugun to'lov kerak emas"),
                                  style: AppText.bodySm),
                            ]),
                      ),
                    );
                  }
                  return Column(
                    children: list
                        .take(5)
                        .map((inst) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: _InstallmentRow(
                                  item: inst, isOverdue: false),
                            ))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              overdueAsync.maybeWhen(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(
                          icon: Icons.warning_amber,
                          label: tr(ref, 'mobile.lopepay.home.overdue',
                              "Muddati o'tgan"),
                          iconColor: AppColors.danger,
                          viewAllLabel: tr(ref, 'common.all', "Hammasi"),
                          onViewAll: () => context
                              .push('/lopepay/installments?status=overdue'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...list.take(5).map((inst) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _InstallmentRow(
                                  item: inst, isOverdue: true),
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
  const _MetricTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: color.withValues(alpha: 0.05),
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.28),
                  color.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: AppText.titleMd
                      .copyWith(fontSize: 17, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppText.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon,
      required this.label,
      required this.iconColor,
      required this.viewAllLabel,
      this.onViewAll});
  final IconData icon;
  final String label;
  final Color iconColor;
  final String viewAllLabel;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(label, style: AppText.titleSm)),
      if (onViewAll != null)
        TapScale(
          onTap: onViewAll,
          haptic: HapticStrength.light,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.rSm,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(viewAllLabel,
                  style: AppText.button
                      .copyWith(color: iconColor, fontSize: 12)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: iconColor),
            ]),
          ),
        ),
    ]);
  }
}

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
    final name = (item['customerName'] ?? '').toString();
    final phone = (item['customerPhone'] ?? '').toString();
    final monthly = ((item['monthlyPayment'] ??
            item['monthlyAmount'] ??
            item['amount'] ??
            0) as num)
        .toInt();
    final color = isOverdue ? AppColors.danger : AppColors.warning;

    return AppCard(
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: isOverdue ? color.withValues(alpha: 0.4) : null,
      onTap: phone.isEmpty
          ? null
          : () => context
              .push('/lopepay/customers/${Uri.encodeComponent(phone)}'),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.28),
                color.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            (name.isNotEmpty ? name[0] : '?').toUpperCase(),
            style: AppText.titleSm.copyWith(color: color),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  name.isEmpty
                      ? tr(ref, 'mobile.barber.bookingsAll.client',
                          "Mijoz")
                      : name,
                  style: AppText.titleSm.copyWith(fontSize: 14)),
              if (phone.isNotEmpty)
                Text(phone, style: AppText.caption),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
                "${_fmt(monthly)} ${tr(ref, 'common.currency', "so'm")}",
                style: AppText.titleSm.copyWith(color: color, fontSize: 14)),
            if (isOverdue) ...[
              const SizedBox(height: 2),
              AppBadge(
                label: tr(ref, 'mobile.lopepay.home.overdueShort',
                    "o'tib ketgan"),
                variant: AppBadgeVariant.danger,
              ),
            ],
          ],
        ),
      ]),
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
  String _filter = 'all';

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
        onPressed: () {
          AppHaptics.medium();
          context.push('/lopepay/customers/new');
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
            tr(ref, 'mobile.lopepay.customerForm.addBtn',
                "Rassrochka qo'shish"),
            style: AppText.button.copyWith(color: Colors.white)),
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
              onRefresh: () async =>
                  ref.refresh(lopepayCustomersProvider.future),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xs),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.body,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textMuted, size: 20),
                        hintText: tr(ref,
                            'mobile.lopepay.customers.searchHint',
                            "Ism yoki telefon"),
                        hintStyle: AppText.body
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    children: [
                      AppChip(
                        label: tr(ref, 'common.all', "Hammasi"),
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: tr(ref,
                            'mobile.lopepay.customer.statusOverdue',
                            "Muddati o'tgan"),
                        selected: _filter == 'overdue',
                        onTap: () => setState(() => _filter = 'overdue'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: tr(ref, 'mobile.lopepay.home.dueToday',
                            "Bugun tushishi kerak"),
                        selected: _filter == 'dueToday',
                        onTap: () => setState(() => _filter = 'dueToday'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppChip(
                        label: tr(ref,
                            'mobile.lopepay.customer.statusPaid',
                            "To'langan"),
                        selected: _filter == 'paidOff',
                        onTap: () => setState(() => _filter = 'paidOff'),
                      ),
                    ],
                  ),
                ),
                if (list.isEmpty)
                  Expanded(
                    child: AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: rawList.isEmpty
                          ? tr(ref, 'mobile.lopepay.home.noCustomers',
                              "Mijozlar yo'q")
                          : tr(ref, 'common.noResults',
                              "Filterga mos natija yo'q"),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          96),
                      itemCount: list.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final overdue = c.nextDue != null &&
                            c.nextDue!.isBefore(DateTime.now());
                        final color =
                            overdue ? AppColors.danger : AppColors.primary;
                        return AppCard(
                          variant: AppCardVariant.flat,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          borderColor: overdue
                              ? AppColors.danger.withValues(alpha: 0.4)
                              : null,
                          onTap: () => context.push(
                              '/lopepay/customers/${Uri.encodeComponent(c.id)}'),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.6),
                                    color.withValues(alpha: 0.25),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                    (c.name.isNotEmpty
                                            ? c.name[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: AppText.titleMd
                                        .copyWith(color: color)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name.isEmpty ? c.phone : c.name,
                                      style: AppText.titleSm
                                          .copyWith(fontSize: 14)),
                                  if (c.phone.isNotEmpty)
                                    Text(c.phone,
                                        style: AppText.caption),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text(
                                        "${_fmt(c.totalDebt)} ${tr(ref, 'common.currency', "so'm")}",
                                        style: AppText.button.copyWith(
                                            color: overdue
                                                ? AppColors.danger
                                                : AppColors.warning,
                                            fontSize: 14)),
                                    if (c.nextDue != null) ...[
                                      const SizedBox(
                                          width: AppSpacing.sm),
                                      Text("• ${_df.format(c.nextDue!)}",
                                          style: AppText.caption
                                              .copyWith(fontSize: 11)),
                                    ],
                                  ]),
                                ],
                              ),
                            ),
                            TapScale(
                              onTap: c.phone.isEmpty
                                  ? null
                                  : () async {
                                      final clean = c.phone
                                          .replaceAll(RegExp(r'[^\d+]'), '');
                                      final uri = Uri(
                                          scheme: 'tel', path: clean);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                              haptic: HapticStrength.light,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_outlined,
                                    color: AppColors.primary, size: 18),
                              ),
                            ),
                          ]),
                        ).animate().fadeIn(
                            duration: 250.ms, delay: (i * 25).ms);
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
