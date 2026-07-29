import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../lopepay/presentation/top_up_modal.dart';
import '../data/shop_repository.dart';

class ShopTransactionsScreen extends ConsumerStatefulWidget {
  const ShopTransactionsScreen({super.key});
  @override
  ConsumerState<ShopTransactionsScreen> createState() =>
      _ShopTransactionsScreenState();
}

class _ShopTransactionsScreenState
    extends ConsumerState<ShopTransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('dd.MM.yyyy');
  static const _pageSize = 20;

  String _chip = 'all';
  String? _barberId;
  String _smsType = 'all';
  DateTime? _from;
  DateTime? _to;
  int _page = 1;
  bool _filtersOpen = false;

  ({String? type, String? direction}) _chipToParams() {
    switch (_chip) {
      case 'in':
        return (type: null, direction: 'income');
      case 'out':
        return (type: null, direction: 'expense');
      case 'topup':
        return (type: 'topup', direction: null);
      case 'sms':
        return (type: 'sms_deduction', direction: null);
      case 'ai':
        return (type: 'ai_deduction', direction: null);
      case 'bonus':
        return (type: 'referral_bonus', direction: null);
      default:
        return (type: null, direction: null);
    }
  }

  ShopTxnKey get _key {
    final p = _chipToParams();
    return (
      type: p.type,
      direction: p.direction,
      barberId: _barberId,
      smsType: _smsType == 'all' ? null : _smsType,
      from: _from == null ? null : _ymd.format(_from!),
      to: _to == null ? null : _ymd.format(_to!),
      page: _page,
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
      _page = 1;
    });
  }

  void _resetAdvancedFilters() {
    AppHaptics.selection();
    setState(() {
      _barberId = null;
      _smsType = 'all';
      _from = null;
      _to = null;
      _page = 1;
    });
  }

  String _fmt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final ri = s.length - i;
      buf.write(s[i]);
      if (ri > 1 && ri % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }

  String _methodLabel(WidgetRef ref, String m) {
    switch (m) {
      case 'click':
        return tr(ref, 'mobile.customer.transactions.methodClick',
            "Click to'lov");
      case 'payme':
        return tr(ref, 'mobile.customer.transactions.methodPayme',
            "Payme to'lov");
      case 'telegram':
        return tr(ref, 'mobile.customer.transactions.methodTelegram',
            'Telegram bonus');
      case 'sms':
        return tr(
            ref, 'mobile.customer.transactions.methodSms', 'SMS xizmat');
      case 'ai':
        return tr(ref, 'mobile.customer.transactions.methodAi', 'AI Stil');
      case 'referral':
        return tr(ref, 'mobile.customer.transactions.methodReferral',
            'Referal bonus');
      default:
        return tr(ref, 'mobile.customer.transactions.methodDefault',
            'Tranzaktsiya');
    }
  }

  /// Backend writes `admin_topup` (superadmin gift with no note) or
  /// `admin_topup:<reason>` (with a free-text note like "Bayram" or
  /// "Bonus"). Rendering it raw shows tech gibberish to the shop owner
  /// — humanize it into "Sovg'a" / "Sovg'a: Bayram" instead.
  String _humanizeDescription(WidgetRef ref, String desc) {
    if (desc == 'admin_topup') {
      return tr(ref, 'mobile.shop.transactions.adminGift', "Sovg'a");
    }
    if (desc.startsWith('admin_topup:')) {
      final reason = desc.substring('admin_topup:'.length).trim();
      final head =
          tr(ref, 'mobile.shop.transactions.adminGift', "Sovg'a");
      return reason.isEmpty ? head : '$head: $reason';
    }
    return desc;
  }

  String _smsTypeLabel(String t) {
    switch (t) {
      case 'CONFIRMATION':
        return tr(ref, 'shop.smsTypes.confirmation', 'Tasdiqlash');
      case 'REMINDER':
        return tr(ref, 'shop.smsTypes.reminder', 'Eslatma');
      case 'RETENTION':
        return tr(ref, 'shop.smsTypes.retention', 'Reklama');
      default:
        return tr(ref, 'common.all', 'Hammasi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopTxnFilteredProvider(_key));
    final balanceAsync = ref.watch(shopBalanceProvider);
    final barbersAsync = ref.watch(shopBarbersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            tr(ref, 'mobile.customer.transactions.history', "Tranzaktsiyalar"),
            style: AppText.titleMd),
        actions: [
          IconButton(
            icon: Icon(
                _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                color: _filtersOpen ? AppColors.primary : null),
            onPressed: () {
              AppHaptics.selection();
              setState(() => _filtersOpen = !_filtersOpen);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(shopTxnFilteredProvider);
          ref.invalidate(shopTransactionsProvider);
          ref.invalidate(shopBalanceProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _BalanceHero(
              balanceAsync: balanceAsync,
              formatter: _fmt,
              label: tr(ref, 'mobile.lopepay.home.balance', "Balans"),
              currency: tr(ref, 'common.currency', "so'm"),
              topUpLabel: tr(ref, 'topUp.title', "Balansni to'ldirish"),
              onTopUp: () => TopUpModal.show(context),
            ),
            const SizedBox(height: AppSpacing.lg),

            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip(
                      label: tr(ref, 'common.all', "Hammasi"),
                      selected: _chip == 'all',
                      onTap: () => setState(() {
                            _chip = 'all';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} +",
                      selected: _chip == 'in',
                      onTap: () => setState(() {
                            _chip = 'in';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: "${tr(ref, 'mobile.lopepay.home.balance', "Balans")} −",
                      selected: _chip == 'out',
                      onTap: () => setState(() {
                            _chip = 'out';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: tr(ref, 'mobile.customer.transactions.topUp',
                          "To'ldirish"),
                      selected: _chip == 'topup',
                      onTap: () => setState(() {
                            _chip = 'topup';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: 'SMS',
                      selected: _chip == 'sms',
                      onTap: () => setState(() {
                            _chip = 'sms';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: 'AI',
                      selected: _chip == 'ai',
                      onTap: () => setState(() {
                            _chip = 'ai';
                            _page = 1;
                          })),
                  const SizedBox(width: AppSpacing.sm),
                  AppChip(
                      label: tr(ref,
                          'mobile.customer.transactions.methodReferral',
                          "Bonus"),
                      selected: _chip == 'bonus',
                      onTap: () => setState(() {
                            _chip = 'bonus';
                            _page = 1;
                          })),
                ],
              ),
            ),

            if (_filtersOpen) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      barbersAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (barbers) => AppSelectField<String?>(
                          label: tr(ref, 'shop.filter.barber', "Master"),
                          icon: Icons.person_outline,
                          value: _barberId,
                          options: [
                            AppSelectOption(
                              value: null,
                              label: tr(ref, 'shop.filter.allBarbers',
                                  "Barcha sartaroshlar"),
                            ),
                            ...barbers.map((b) => AppSelectOption(
                                  value: b.id,
                                  label: b.name,
                                )),
                          ],
                          onChanged: (v) => setState(() {
                            _barberId = v;
                            _page = 1;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppSelectField<String>(
                        label: tr(ref, 'shop.smsTypes.label', "SMS turi"),
                        icon: Icons.sms_outlined,
                        value: _smsType,
                        options: [
                          AppSelectOption(
                              value: 'all', label: _smsTypeLabel('all')),
                          AppSelectOption(
                              value: 'CONFIRMATION',
                              label: _smsTypeLabel('CONFIRMATION')),
                          AppSelectOption(
                              value: 'REMINDER',
                              label: _smsTypeLabel('REMINDER')),
                          AppSelectOption(
                              value: 'RETENTION',
                              label: _smsTypeLabel('RETENTION')),
                        ],
                        onChanged: (v) => setState(() {
                          _smsType = v;
                          _page = 1;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(
                            child: _DatePill(
                                label: _from == null
                                    ? tr(ref, 'shop.filter.from', "Dan")
                                    : _pretty.format(_from!),
                                onTap: () => _pickDate(true))),
                        const SizedBox(width: AppSpacing.sm),
                        Text("—",
                            style:
                                TextStyle(color: context.colors.textMuted)),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: _DatePill(
                                label: _to == null
                                    ? tr(ref, 'shop.filter.to', "Gacha")
                                    : _pretty.format(_to!),
                                onTap: () => _pickDate(false))),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: tr(ref, 'common.reset', "Tozalash"),
                        leadingIcon: Icons.refresh,
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.sm,
                        fullWidth: true,
                        onPressed: _resetAdvancedFilters,
                      ),
                    ]),
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            async.when(
              loading: () => const AppListSkeleton(itemCount: 5),
              error: (e, _) => SizedBox(
                height: 260,
                child: AppErrorState(message: humanize(e)),
              ),
              data: (res) {
                final list = res.data;
                final pages = (res.total / _pageSize).ceil();
                if (list.isEmpty) {
                  return SizedBox(
                    height: 260,
                    child: AppEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: tr(ref, 'mobile.customer.transactions.empty',
                          "Tranzaktsiya yo'q"),
                      message: tr(
                        ref,
                        'mobile.customer.transactions.emptyHint',
                        "Hisobingizga to'lov qilinganda yoki xarid qilganingizda bu yerda ko'rinadi.",
                      ),
                    ),
                  );
                }
                return Column(children: [
                  ...list.asMap().entries.map((e) {
                    final t = e.value;
                    final inflow = t.direction == 'in' || t.amount > 0;
                    final color = inflow ? AppColors.success : AppColors.danger;
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
                              gradient: LinearGradient(
                                colors: [
                                  color.withValues(alpha: 0.22),
                                  color.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                inflow
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                                color: color),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    t.description != null
                                        ? _humanizeDescription(
                                            ref, t.description!)
                                        : _methodLabel(ref, t.method),
                                    style: AppText.titleSm
                                        .copyWith(fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_df.format(t.createdAt.toLocal()),
                                    style: AppText.caption),
                              ],
                            ),
                          ),
                          Text(
                              "${inflow ? '+' : '−'}${_fmt(t.amount)} ${tr(ref, 'common.currency', "so'm")}",
                              style: AppText.titleSm.copyWith(
                                  fontSize: 14, color: color)),
                        ]),
                      ).animate().fadeIn(
                          duration: 250.ms, delay: (e.key * 25).ms),
                    );
                  }),
                  if (pages > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppButton(
                          label: tr(ref, 'common.prev', "Oldingi"),
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.sm,
                          leadingIcon: Icons.chevron_left,
                          onPressed: _page <= 1
                              ? null
                              : () => setState(() => _page--),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.rPill,
                          ),
                          child: Text("$_page / $pages",
                              style: AppText.button
                                  .copyWith(color: AppColors.primary)),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AppButton(
                          label: tr(ref, 'common.next', "Keyingi"),
                          variant: AppButtonVariant.secondary,
                          size: AppButtonSize.sm,
                          trailingIcon: Icons.chevron_right,
                          onPressed: _page >= pages
                              ? null
                              : () => setState(() => _page++),
                        ),
                      ],
                    ),
                  ],
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.balanceAsync,
    required this.formatter,
    required this.label,
    required this.currency,
    required this.topUpLabel,
    required this.onTopUp,
  });
  final AsyncValue<int> balanceAsync;
  final String Function(int) formatter;
  final String label;
  final String currency;
  final String topUpLabel;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rLg,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppText.overline
                          .copyWith(color: Colors.white70)),
                  const SizedBox(height: 2),
                  balanceAsync.when(
                    loading: () => Text("…",
                        style: AppText.titleLg
                            .copyWith(color: Colors.white)),
                    error: (_, _) => Text("—",
                        style: AppText.titleLg
                            .copyWith(color: Colors.white)),
                    data: (b) => Text("${formatter(b)} $currency",
                        style: AppText.titleLg
                            .copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ]),
          AppSpacing.gapMd,
          TapScale(
            onTap: onTopUp,
            scale: 0.96,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.rMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(topUpLabel,
                      style: AppText.button
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined,
              size: 14, color: context.colors.textMuted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}
