import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';

class LopepayInstallmentsScreen extends ConsumerStatefulWidget {
  const LopepayInstallmentsScreen({super.key, this.initialStatus});
  final String? initialStatus;

  @override
  ConsumerState<LopepayInstallmentsScreen> createState() =>
      _LopepayInstallmentsScreenState();
}

class _LopepayInstallmentsScreenState
    extends ConsumerState<LopepayInstallmentsScreen> {
  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');
  static final _ymd = DateFormat('yyyy-MM-dd');
  String _query = '';
  late String _status = widget.initialStatus ?? 'all';
  String _phone = '';
  String? _productId;
  DateTime? _from;
  DateTime? _to;
  bool _filtersOpen = false;

  String _statusLabel(WidgetRef ref, String s, int daysLate) {
    switch (s) {
      case 'paid_off':
        return tr(ref, 'mobile.lopepay.customer.statusPaid', "To'langan");
      case 'overdue':
        return tr(ref, 'mobile.lopepay.installments.daysLate',
            "{{n}} kun kechikkan", {'n': '$daysLate'});
      case 'due_today':
        return tr(ref, 'mobile.lopepay.home.dueToday', "Bugun");
      case 'due_tomorrow':
        return tr(ref, 'mobile.lopepay.installments.dueTomorrow', "Ertaga");
      case 'upcoming':
        return tr(ref, 'mobile.lopepay.installments.upcoming', "Kelajakda");
      default:
        return s;
    }
  }

  AppBadgeVariant _statusVariant(String s) {
    switch (s) {
      case 'paid_off':
        return AppBadgeVariant.success;
      case 'overdue':
        return AppBadgeVariant.danger;
      case 'due_today':
        return AppBadgeVariant.warning;
      case 'due_tomorrow':
      case 'upcoming':
        return AppBadgeVariant.info;
      default:
        return AppBadgeVariant.neutral;
    }
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

  _InstallmentsKey get _key => (
        search: _query.isEmpty ? null : _query,
        status: _status == 'all' ? null : _status,
        phone: _phone.isEmpty ? null : _phone,
        productId: _productId,
        from: _from == null ? null : _ymd.format(_from!),
        to: _to == null ? null : _ymd.format(_to!),
      );

  Future<void> _pickDate(bool isFrom) async {
    final init = (isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
  }

  void _resetFilters() {
    AppHaptics.selection();
    setState(() {
      _query = '';
      _status = 'all';
      _phone = '';
      _productId = null;
      _from = null;
      _to = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(lopepayInstallmentsListProvider(_key));
    final productsAsync = ref.watch(lopepayProductsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
            tr(ref, 'mobile.lopepay.installments.title', "Rassrochkalar"),
            style: AppText.titleMd),
      ),
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
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Row(children: [
            Expanded(
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
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textMuted, size: 20),
                    hintText: tr(ref, 'mobile.lopepay.customers.searchHint',
                        "Ism yoki telefon"),
                    hintStyle:
                        AppText.body.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TapScale(
              onTap: () {
                AppHaptics.selection();
                setState(() => _filtersOpen = !_filtersOpen);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _filtersOpen
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: AppRadius.rMd,
                  border: Border.all(
                      color: _filtersOpen
                          ? AppColors.primary
                          : AppColors.border),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.filter_list,
                  color: _filtersOpen
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ]),
        ),

        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                AppSpacing.lg, AppSpacing.xs),
            child: AppCard(
              variant: AppCardVariant.flat,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _phone = v),
                      controller: TextEditingController(text: _phone)
                        ..selection = TextSelection.collapsed(
                            offset: _phone.length),
                      style: AppText.body,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: tr(ref, 'lopePay.shop.filterPhone',
                            'Telefon raqami'),
                        hintText: '+998...',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    productsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (products) =>
                          DropdownButtonFormField<String?>(
                        isDense: true,
                        initialValue: _productId,
                        decoration: InputDecoration(
                          labelText: tr(ref, 'lopePay.shop.filterProduct',
                              "Mahsulot"),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: null,
                              child:
                                  Text(tr(ref, 'common.all', "Hammasi"))),
                          ...products.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name,
                                  overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) => setState(() => _productId = v),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: _DatePill(
                          label: _from == null
                              ? tr(ref, 'lopePay.shop.filterFrom', "Dan")
                              : _ymd.format(_from!),
                          onTap: () => _pickDate(true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Text("—",
                          style: TextStyle(color: AppColors.textMuted)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DatePill(
                          label: _to == null
                              ? tr(ref, 'lopePay.shop.filterTo', "Gacha")
                              : _ymd.format(_to!),
                          onTap: () => _pickDate(false),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: tr(ref, 'common.reset', "Tozalash"),
                      leadingIcon: Icons.refresh,
                      variant: AppButtonVariant.secondary,
                      size: AppButtonSize.sm,
                      fullWidth: true,
                      onPressed: _resetFilters,
                    ),
                  ]),
            ),
          ),

        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              AppChip(
                  label: tr(ref, 'common.all', "Hammasi"),
                  selected: _status == 'all',
                  onTap: () => setState(() => _status = 'all')),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: tr(ref, 'mobile.lopepay.customer.statusOverdue',
                      "Muddati o'tgan"),
                  selected: _status == 'overdue',
                  onTap: () => setState(() => _status = 'overdue')),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: tr(ref, 'mobile.lopepay.home.dueToday', "Bugun"),
                  selected: _status == 'due_today',
                  onTap: () => setState(() => _status = 'due_today')),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: tr(ref, 'mobile.lopepay.installments.upcoming',
                      "Kelajakda"),
                  selected: _status == 'upcoming',
                  onTap: () => setState(() => _status = 'upcoming')),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                  label: tr(ref, 'mobile.lopepay.customer.statusPaid',
                      "To'langan"),
                  selected: _status == 'paid_off',
                  onTap: () => setState(() => _status = 'paid_off')),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const AppListSkeleton(),
            error: (e, _) => AppErrorState(
              message: humanize(e),
              onRetry: () =>
                  ref.invalidate(lopepayInstallmentsListProvider),
            ),
            data: (res) {
              final list = res.data;
              if (list.isEmpty) {
                return AppEmptyState(
                  icon: Icons.credit_card_off_outlined,
                  title: tr(ref, 'mobile.lopepay.installments.empty',
                      "Rassrochka topilmadi"),
                  message: tr(
                    ref,
                    'mobile.lopepay.installments.emptyHint',
                    "Yangi mijoz uchun rassrochka rasmiylashtirsangiz shu yerda ko'rinadi.",
                  ),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(lopepayInstallmentsListProvider);
                  await ref
                      .read(lopepayInstallmentsListProvider(_key).future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final inst = list[i];
                    final name = (inst['customerName'] ?? '').toString();
                    final phone = (inst['customerPhone'] ?? '').toString();
                    final productName =
                        (inst['productName'] ?? '').toString();
                    final monthsPaid =
                        ((inst['monthsPaid'] ?? 0) as num).toInt();
                    final monthsTotal =
                        ((inst['monthsTotal'] ?? 0) as num).toInt();
                    final debt = ((inst['debt'] ??
                            inst['monthlyPayment'] ??
                            0) as num)
                        .toInt();
                    final isPaidOff = inst['isPaidOff'] == true;
                    final status = (inst['status'] ?? '').toString();
                    final daysLate =
                        ((inst['daysLate'] ?? 0) as num).toInt();
                    final nextDue = inst['nextDueDate']?.toString();

                    return Opacity(
                      opacity: isPaidOff ? 0.65 : 1.0,
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: phone.isEmpty
                            ? null
                            : () => context.push(
                                '/lopepay/customers/${Uri.encodeComponent(phone)}'),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.titleSm
                                            .copyWith(fontSize: 14)),
                                  ),
                                  if (status.isNotEmpty) ...[
                                    const SizedBox(width: AppSpacing.xs),
                                    AppBadge(
                                      label: _statusLabel(
                                          ref, status, daysLate),
                                      variant: _statusVariant(status),
                                    ),
                                  ],
                                ]),
                                if (phone.isNotEmpty)
                                  Row(children: [
                                    const Icon(Icons.phone_outlined,
                                        size: 11,
                                        color: AppColors.textMuted),
                                    const SizedBox(width: 3),
                                    Text(phone,
                                        style: AppText.caption
                                            .copyWith(fontSize: 11)),
                                  ]),
                                if (productName.isNotEmpty)
                                  Text(
                                      "$productName · $monthsPaid/$monthsTotal ${tr(ref, 'lopePay.shop.monthsPaid', 'oy')}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption
                                          .copyWith(fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  "${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                                  style: AppText.titleSm
                                      .copyWith(fontSize: 14)),
                              if (nextDue != null && !isPaidOff) ...[
                                const SizedBox(height: 2),
                                Builder(builder: (_) {
                                  final d = DateTime.tryParse(nextDue);
                                  if (d == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(_df.format(d.toLocal()),
                                      style: AppText.caption
                                          .copyWith(fontSize: 11));
                                }),
                              ],
                            ],
                          ),
                        ]),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms, delay: (i * 20).ms);
                  },
                ),
              );
            },
          ),
        ),
      ]),
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
          color: AppColors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined,
              size: 14, color: AppColors.textMuted),
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

typedef _InstallmentsKey = ({
  String? search,
  String? status,
  String? phone,
  String? productId,
  String? from,
  String? to,
});

final lopepayInstallmentsListProvider = FutureProvider.family<
    ({List<Map<String, dynamic>> data, int total}),
    _InstallmentsKey>((ref, k) async {
  return ref.watch(lopepayRepositoryProvider).listInstallments(
        search: k.search,
        status: k.status,
        phone: k.phone,
        productId: k.productId,
        from: k.from,
        to: k.to,
        limit: 100,
      );
});
