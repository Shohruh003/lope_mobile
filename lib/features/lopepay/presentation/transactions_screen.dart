import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/balance_repository.dart';
import 'top_up_modal.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static final _df = DateFormat('dd.MM.yyyy HH:mm');
  static final _ymd = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('dd.MM.yyyy');

  // Filter state — mutating any of these resets the accumulated list
  // and refetches page 1 via _resetAndReload().
  String _direction = 'all';
  String _method = 'all';
  DateTime? _from;
  DateTime? _to;
  bool _filtersOpen = false;

  // Infinite-scroll bookkeeping. Was: single-page provider with
  // Oldingi/Keyingi buttons at the bottom of the ListView. User asked
  // for the native-app infinite-scroll pattern ('men eng pastga
  // tushganimda keyingi sahifadagi malumotlar chiqaversin') so we
  // accumulate items in local state and prefetch the next page as the
  // scroll approaches the bottom.
  final ScrollController _scrollController = ScrollController();
  final List<PaymentEntry> _items = [];
  int _totalIncome = 0;
  int _totalExpense = 0;
  int _totalPages = 1;
  int _currentPage = 0; // 0 = nothing loaded yet
  bool _initialLoading = true;
  bool _loadingMore = false;
  Object? _error;

  String? _directionParam() {
    if (_direction == 'in') return 'income';
    if (_direction == 'out') return 'expense';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Fire ~400px before the end so the next page finishes loading
    // before the user hits the very bottom — no visible spinner
    // stall on fast connections.
    if (pos.pixels < pos.maxScrollExtent - 400) return;
    if (_loadingMore || _initialLoading) return;
    if (_currentPage >= _totalPages) return;
    _loadPage(_currentPage + 1);
  }

  Future<void> _loadPage(int page) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    if (page == 1) {
      setState(() {
        _initialLoading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final res =
          await ref.read(balanceRepositoryProvider).historyEnvelope(
                userId: user.id,
                direction: _directionParam() ?? 'all',
                method: _method,
                from: _from == null ? null : _ymd.format(_from!),
                to: _to == null ? null : _ymd.format(_to!),
                page: page,
              );
      if (!mounted) return;
      setState(() {
        if (page == 1) {
          _items
            ..clear()
            ..addAll(res.data);
        } else {
          _items.addAll(res.data);
        }
        _totalIncome = res.totalIncome;
        _totalExpense = res.totalExpense;
        _totalPages = res.totalPages;
        _currentPage = page;
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _error = e;
      });
    }
  }

  void _resetAndReload() {
    setState(() {
      _items.clear();
      _currentPage = 0;
      _totalPages = 1;
      _totalIncome = 0;
      _totalExpense = 0;
      _error = null;
    });
    _loadPage(1);
  }

  Future<void> _refresh() async {
    final user = ref.read(authControllerProvider).user;
    if (user != null) ref.invalidate(myBalanceProvider(user.id));
    await _loadPage(1);
  }

  Future<void> _pickDate(bool isFrom) async {
    AppHaptics.light();
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    if (isFrom) {
      _from = picked;
    } else {
      _to = picked;
    }
    _resetAndReload();
  }

  void _resetFilters() {
    AppHaptics.light();
    _direction = 'all';
    _method = 'all';
    _from = null;
    _to = null;
    _resetAndReload();
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'click':
        return tr(ref, 'mobile.customer.transactions.methodClick',
            "Click to'lov");
      case 'payme':
        return tr(ref, 'mobile.customer.transactions.methodPayme',
            "Payme to'lov");
      case 'telegram':
        return tr(ref, 'mobile.customer.transactions.methodTelegram',
            'Telegram');
      case 'internal':
        return tr(ref, 'mobile.customer.transactions.methodInternal',
            'Ichki');
      default:
        return tr(ref, 'common.all', 'Hammasi');
    }
  }

  String _methodRowLabel(WidgetRef ref, String m) {
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
        return tr(
            ref, 'mobile.customer.transactions.methodAi', 'AI Stil');
      case 'referral':
        return tr(ref, 'mobile.customer.transactions.methodReferral',
            'Referal bonus');
      default:
        return tr(ref, 'mobile.customer.transactions.methodDefault',
            'Tranzaktsiya');
    }
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final balance = ref.watch(myBalanceProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.customer.transactions.title', 'Hisobim'),
          style: AppText.titleMd,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: TapScale(
              onTap: () {
                AppHaptics.light();
                setState(() => _filtersOpen = !_filtersOpen);
              },
              scale: 0.9,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _filtersOpen
                      ? AppColors.primary
                      : context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(
                  _filtersOpen ? Icons.filter_list_off : Icons.filter_list,
                  color: _filtersOpen
                      ? Colors.white
                      : context.colors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
              AppSpacing.lg, AppSpacing.pageBottom(context)),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            balance.when(
              loading: () =>
                  const SkeletonRect(height: 160, radius: AppRadius.xl),
              error: (e, _) => SizedBox(
                height: 200,
                child: AppErrorState(
                  message: humanize(e),
                  onRetry: () => ref.invalidate(myBalanceProvider(user.id)),
                ),
              ),
              data: (b) =>
                  _BalanceCard(amount: b.amount, aiFree: b.aiFreeRemaining),
            ),
            if (!_initialLoading && _error == null) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.trending_up,
                      color: AppColors.success,
                      label: tr(ref,
                          'mobile.customer.transactions.income', 'Kirim'),
                      value:
                          "${_fmt(_totalIncome)} ${tr(ref, 'common.currency', "so'm")}",
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: _StatTile(
                      icon: Icons.trending_down,
                      color: AppColors.danger,
                      label: tr(
                          ref,
                          'mobile.customer.transactions.expense',
                          'Chiqim'),
                      value:
                          "${_fmt(_totalExpense)} ${tr(ref, 'common.currency', "so'm")}",
                    ),
                  ),
                ]),
              ),
            ],
            AppSpacing.gapXl,
            Text(
              tr(ref, 'mobile.customer.transactions.history',
                  'Tranzaktsiyalar'),
              style: AppText.titleMd,
            ),
            AppSpacing.gapMd,
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip(
                    label: tr(ref, 'common.all', 'Hammasi'),
                    selected: _direction == 'all',
                    onTap: () {
                      _direction = 'all';
                      _resetAndReload();
                    },
                  ),
                  AppSpacing.hGapSm,
                  AppChip(
                    label: tr(ref,
                        'mobile.customer.transactions.income', 'Kirim'),
                    leadingIcon: Icons.trending_up,
                    selected: _direction == 'in',
                    onTap: () {
                      _direction = 'in';
                      _resetAndReload();
                    },
                  ),
                  AppSpacing.hGapSm,
                  AppChip(
                    label: tr(ref,
                        'mobile.customer.transactions.expense', 'Chiqim'),
                    leadingIcon: Icons.trending_down,
                    selected: _direction == 'out',
                    onTap: () {
                      _direction = 'out';
                      _resetAndReload();
                    },
                  ),
                ],
              ),
            ),
            if (_filtersOpen) ...[
              AppSpacing.gapMd,
              AppCard(
                variant: AppCardVariant.outlined,
                padding: AppSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSelectField<String>(
                      label: tr(ref, 'lopePay.shop.filterType',
                          "To'lov turi"),
                      icon: Icons.filter_alt_outlined,
                      value: _method,
                      options: [
                        AppSelectOption(
                            value: 'all',
                            label: _methodLabel('all'),
                            icon: Icons.all_inclusive),
                        AppSelectOption(
                            value: 'click',
                            label: _methodLabel('click'),
                            icon: Icons.credit_card),
                        AppSelectOption(
                            value: 'payme',
                            label: _methodLabel('payme'),
                            icon: Icons.account_balance_wallet),
                        AppSelectOption(
                            value: 'telegram',
                            label: _methodLabel('telegram'),
                            icon: Icons.send),
                        AppSelectOption(
                            value: 'internal',
                            label: _methodLabel('internal'),
                            icon: Icons.sync_alt),
                      ],
                      onChanged: (v) {
                        _method = v;
                        _resetAndReload();
                      },
                    ),
                    AppSpacing.gapMd,
                    Row(children: [
                      Expanded(
                        child: _DatePill(
                          label: _from == null
                              ? tr(ref, 'shop.filter.from', 'Dan')
                              : _pretty.format(_from!),
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      AppSpacing.hGapSm,
                      Text('—',
                          style:
                              TextStyle(color: context.colors.textMuted)),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: _DatePill(
                          label: _to == null
                              ? tr(ref, 'shop.filter.to', 'Gacha')
                              : _pretty.format(_to!),
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ]),
                    AppSpacing.gapMd,
                    AppButton(
                      label: tr(ref, 'common.reset', 'Tozalash'),
                      leadingIcon: Icons.refresh,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: _resetFilters,
                    ),
                  ],
                ),
              ),
            ],
            AppSpacing.gapMd,
            _buildListSection(user),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection(dynamic user) {
    // Initial load — skeleton rows so the customer sees something
    // happening while the first page is in flight.
    if (_initialLoading) {
      return const Column(
        children: [
          SkeletonRect(height: 68, radius: AppRadius.md),
          SizedBox(height: AppSpacing.sm),
          SkeletonRect(height: 68, radius: AppRadius.md),
          SizedBox(height: AppSpacing.sm),
          SkeletonRect(height: 68, radius: AppRadius.md),
        ],
      );
    }
    final err = _error;
    if (err != null) {
      return SizedBox(
        height: 300,
        child: AppErrorState(
          message: humanize(err),
          onRetry: () => _loadPage(1),
        ),
      );
    }
    if (_items.isEmpty) {
      return SizedBox(
        height: 260,
        child: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: tr(ref, 'mobile.customer.transactions.empty',
              "Hali tranzaktsiya yo'q"),
          message: tr(
            ref,
            'mobile.customer.transactions.emptyHint',
            "Hisobingizga to'lov qilinganda yoki xarid qilganingizda bu yerda ko'rinadi.",
          ),
        ),
      );
    }
    return Column(children: [
      ...List.generate(_items.length, (i) {
        final p = _items[i];
        final inflow = p.direction == 'in' || p.amount > 0;
        // Cap the fade-in delay for later rows — otherwise page 3+
        // items delay animations for 60+ frames each.
        final delayMs = (i * 20).clamp(0, 400);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppSpacing.cardPadding,
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (inflow ? AppColors.success : AppColors.danger)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    inflow
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    size: 20,
                    color: inflow
                        ? AppColors.success
                        : AppColors.danger),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        p.description ??
                            _methodRowLabel(ref, p.method),
                        style: AppText.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(_df.format(p.createdAt.toLocal()),
                        style: AppText.caption),
                  ],
                ),
              ),
              Text(
                  "${inflow ? '+' : '−'}${_fmt(p.amount.abs())} ${tr(ref, 'common.currency', "so'm")}",
                  style: AppText.body.copyWith(
                    fontWeight: FontWeight.w800,
                    color: inflow
                        ? AppColors.success
                        : AppColors.danger,
                  )),
            ]),
          ),
        ).animate().fadeIn(duration: 200.ms, delay: delayMs.ms);
      }),
      // Infinite-scroll tail. Was: 'Oldingi | 2 / 9 | Keyingi' row.
      // Now: small centered spinner while the next page loads, or
      // silent no-op once the last page is loaded.
      if (_loadingMore) ...[
        AppSpacing.gapMd,
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: AppRadius.rMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 16),
            AppSpacing.hGapXs,
            Text(
              label,
              style: AppText.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                AppText.titleSm.copyWith(color: context.colors.textBright),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard({required this.amount, required this.aiFree});
  final int amount;
  final int? aiFree;
  @override
  ConsumerState<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<_BalanceCard> {
  Future<void> _openTopUpSheet() async {
    AppHaptics.light();
    await TopUpModal.show(context);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.primaryGlow(AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: AppRadius.rSm,
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 20),
            ),
            AppSpacing.hGapSm,
            Text(
              tr(ref, 'mobile.customer.transactions.balanceCurrent',
                  'Joriy balans'),
              style: AppText.body.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
          AppSpacing.gapMd,
          Text(
            "${_fmt(widget.amount)} ${tr(ref, 'common.currency', "so'm")}",
            style: AppText.display.copyWith(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (widget.aiFree != null) ...[
            AppSpacing.gapSm,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: AppRadius.rPill,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 12),
                AppSpacing.hGapXs,
                Text(
                  tr(
                      ref,
                      'mobile.customer.transactions.freeAiHint',
                      'Bugun {{n}} ta bepul AI Stil qoldi',
                      {'n': '${widget.aiFree}'}),
                  style: AppText.caption.copyWith(color: Colors.white),
                ),
              ]),
            ),
          ],
          AppSpacing.gapLg,
          TapScale(
            onTap: _openTopUpSheet,
            scale: 0.94,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.rPill,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add, color: AppColors.primary, size: 18),
                AppSpacing.hGapSm,
                Text(
                  tr(ref, 'mobile.customer.transactions.topUp',
                      "To'ldirish"),
                  style: AppText.button.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
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
      scale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_outlined,
              size: 14, color: context.colors.textMuted),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm,
            ),
          ),
        ]),
      ),
    );
  }
}
