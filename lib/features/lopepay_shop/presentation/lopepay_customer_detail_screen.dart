import 'package:dio/dio.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/lopepay_repository.dart';
import 'lopepay_installments_screen.dart' show lopepayInstallmentsListProvider;

class LopepayCustomerDetailScreen extends ConsumerWidget {
  const LopepayCustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  static final _df = DateFormat('dd.MM.yyyy', 'ru_RU');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lopepayCustomerByPhoneProvider(customerId));
    final installments = async.maybeWhen(
      data: (d) =>
          (d['installments'] as List? ?? const []).cast<Map<String, dynamic>>(),
      orElse: () => const <Map<String, dynamic>>[],
    );
    final nextUnpaid = installments.firstWhere(
      (inst) => inst['isPaidOff'] != true,
      orElse: () => const <String, dynamic>{},
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.barber.bookingsAll.client', "Mijoz"),
            style: AppText.titleMd),
      ),
      floatingActionButton: nextUnpaid.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.success,
              onPressed: () {
                AppHaptics.medium();
                _openInstallmentActions(context, ref, nextUnpaid);
              },
              icon: const Icon(Icons.payments, color: Colors.white),
              label: Text(
                  tr(ref, 'mobile.lopepay.customer.recordPayment',
                      "To'lov qabul qilish"),
                  style: AppText.button.copyWith(color: Colors.white)),
            ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (data) {
          final name = (data['name'] ?? '').toString();
          final phone = (data['phone'] ?? '').toString();
          final address = (data['address'] ?? '').toString();
          final debt = ((data['totalDebt'] ?? 0) as num).toInt();
          final payments =
              (data['payments'] as List? ?? []).cast<Map<String, dynamic>>();
          final installments = (data['installments'] as List? ?? [])
              .cast<Map<String, dynamic>>();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref
                .refresh(lopepayCustomerByPhoneProvider(customerId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.rXl,
                    boxShadow: AppShadows.primaryGlow(AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? phone : name,
                        style: AppText.titleLg.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: AppText.bodySm.copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: AppText.caption.copyWith(color: Colors.white70),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                          tr(ref, 'mobile.lopepay.customer.debt', "Qarz"),
                          style: AppText.overline
                              .copyWith(color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text(
                          "${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                          style: AppText.display
                              .copyWith(color: Colors.white, fontSize: 30)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'mobile.lopepay.customer.call',
                          "Qo'ng'iroq"),
                      leadingIcon: Icons.phone,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: phone.isEmpty
                          ? null
                          : () async {
                              final clean =
                                  phone.replaceAll(RegExp(r'[^\d+]'), '');
                              final uri = Uri(scheme: 'tel', path: clean);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.sms', 'SMS'),
                      leadingIcon: Icons.sms,
                      variant: AppButtonVariant.secondary,
                      fullWidth: true,
                      onPressed: phone.isEmpty
                          ? null
                          : () async {
                              final clean =
                                  phone.replaceAll(RegExp(r'[^\d+]'), '');
                              final uri = Uri(scheme: 'sms', path: clean);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xl),

                _SectionHeader(
                  icon: Icons.credit_card,
                  title: tr(ref, 'mobile.lopepay.customer.installments',
                      "Rassrochkalar"),
                ),
                const SizedBox(height: AppSpacing.md),
                if (installments.isEmpty)
                  Text(
                      tr(ref, 'mobile.lopepay.customer.noActiveInstallments',
                          "Faol rassrochka yo'q"),
                      style: AppText.bodySm)
                else
                  ...installments.map((i) {
                    final daysLate = ((i['daysLate'] ?? 0) as num).toInt();
                    final monthsPaid =
                        ((i['monthsPaid'] ?? 0) as num).toInt();
                    final monthsTotal =
                        ((i['monthsTotal'] ?? 0) as num).toInt();
                    final isPaidOff = i['isPaidOff'] == true;
                    final totalPrice =
                        ((i['totalPrice'] ?? 0) as num).toInt();
                    final monthlyPayment =
                        ((i['monthlyPayment'] ?? 0) as num).toInt();
                    final debt = ((i['debt'] ??
                            (isPaidOff ? 0 : monthlyPayment)) as num)
                        .toInt();
                    final color = isPaidOff
                        ? AppColors.success
                        : (daysLate > 0
                            ? AppColors.danger
                            : AppColors.primary);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        onTap: () =>
                            _openInstallmentActions(context, ref, i),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _installmentStatusBanner(ref,
                                  isPaidOff: isPaidOff,
                                  daysLate: daysLate,
                                  nextDueDate: i['nextDueDate']?.toString()),
                              const SizedBox(height: AppSpacing.sm),
                              Row(children: [
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            (i['productName'] ??
                                                    tr(ref,
                                                        'mobile.lopepay.products.newProduct',
                                                        'Mahsulot'))
                                                .toString(),
                                            style: AppText.titleSm
                                                .copyWith(fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(
                                            "$monthsPaid / $monthsTotal ${tr(ref, 'lopePay.shop.monthsPaid', "oy")}",
                                            style: AppText.caption),
                                      ]),
                                ),
                                Text(
                                    isPaidOff
                                        ? "0 ${tr(ref, 'common.currency', "so'm")}"
                                        : "${_fmt(debt)} ${tr(ref, 'common.currency', "so'm")}",
                                    style: AppText.titleSm
                                        .copyWith(color: color, fontSize: 14)),
                              ]),
                              const SizedBox(height: AppSpacing.sm),
                              if (monthsTotal > 0) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: monthsPaid / monthsTotal,
                                    minHeight: 6,
                                    backgroundColor:
                                        color.withValues(alpha: 0.12),
                                    valueColor:
                                        AlwaysStoppedAnimation(color),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              Row(children: [
                                Expanded(
                                  child: _MiniStat(
                                      label: tr(ref,
                                          'lopePay.shop.totalPrice',
                                          "Jami"),
                                      value:
                                          "${_fmt(totalPrice)} ${tr(ref, 'common.currency', "so'm")}"),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _MiniStat(
                                      label: tr(ref,
                                          'lopePay.shop.monthlyPayment',
                                          "Oylik"),
                                      value:
                                          "${_fmt(monthlyPayment)} ${tr(ref, 'common.currency', "so'm")}"),
                                ),
                              ]),
                            ]),
                      ),
                    );
                  }),

                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  icon: Icons.history,
                  title: tr(ref, 'mobile.lopepay.customer.paymentsHistory',
                      "To'lovlar tarixi"),
                ),
                const SizedBox(height: AppSpacing.md),
                if (payments.isEmpty)
                  Text(
                      tr(ref, 'mobile.lopepay.customer.noPayments',
                          "Hali to'lov yo'q"),
                      style: AppText.bodySm)
                else
                  ...payments.map((p) {
                    final at =
                        DateTime.tryParse(p['paidAt']?.toString() ?? '');
                    final amount = ((p['amount'] ?? 0) as num).toInt();
                    final monthNumber =
                        ((p['monthNumber'] ?? 0) as num).toInt();
                    final monthsTotal =
                        ((p['_monthsTotal'] ?? 0) as num).toInt();
                    final productName =
                        (p['_productName'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        variant: AppCardVariant.flat,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.success.withValues(alpha: 0.22),
                                  AppColors.success.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 18, color: AppColors.success),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Row 1: month numbering "Oy N/M" +
                                // amount aligned right so the history
                                // reads like a proper receipt.
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      monthNumber > 0 && monthsTotal > 0
                                          ? tr(ref,
                                              'mobile.lopepay.customer.paymentMonth',
                                              'Oy {{n}} / {{m}}',
                                              {
                                                'n': '$monthNumber',
                                                'm': '$monthsTotal'
                                              })
                                          : tr(
                                              ref,
                                              'mobile.lopepay.customer.paymentGeneric',
                                              "To'lov"),
                                      style: AppText.titleSm
                                          .copyWith(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                      "+ ${_fmt(amount)} ${tr(ref, 'common.currency', "so'm")}",
                                      style: AppText.titleSm.copyWith(
                                          fontSize: 14,
                                          color: AppColors.success)),
                                ]),
                                const SizedBox(height: 2),
                                // Row 2: product name + date.
                                Row(children: [
                                  if (productName.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        productName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.caption,
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  if (at != null)
                                    Text(_df.format(at.toLocal()),
                                        style: AppText.caption),
                                ]),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
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

  Future<void> _openInstallmentActions(
      BuildContext context, WidgetRef ref, Map<String, dynamic> inst) async {
    final instId = (inst['id'] ?? '').toString();
    if (instId.isEmpty) return;
    AppHaptics.selection();
    final monthsPaid = ((inst['monthsPaid'] ?? 0) as num).toInt();
    final isPaidOff = inst['isPaidOff'] == true;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      builder: (sheetCtx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: AppSpacing.md),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: AppSpacing.md),
          if (!isPaidOff)
            _SheetAction(
              icon: Icons.check_circle_outline,
              tint: AppColors.success,
              title: tr(ref, 'mobile.lopepay.installment.markPaid',
                  "Oyni to'langan deb belgilash"),
              onTap: () => Navigator.of(sheetCtx).pop('mark'),
            ),
          if (monthsPaid > 0)
            _SheetAction(
              icon: Icons.undo,
              tint: AppColors.warning,
              title: tr(ref, 'mobile.lopepay.installment.undoLast',
                  "Oxirgi to'lovni bekor qilish"),
              onTap: () => Navigator.of(sheetCtx).pop('undo'),
            ),
          _SheetAction(
            icon: Icons.edit_outlined,
            tint: context.colors.textSecondary,
            title: tr(ref, 'common.edit', "Tahrirlash"),
            onTap: () => Navigator.of(sheetCtx).pop('edit'),
          ),
          _SheetAction(
            icon: Icons.delete_outline,
            tint: AppColors.danger,
            title: tr(ref, 'mobile.lopepay.installment.delete',
                "Rassrochkani o'chirish"),
            onTap: () => Navigator.of(sheetCtx).pop('delete'),
          ),
          _SheetAction(
            icon: Icons.close,
            tint: context.colors.textMuted,
            title: tr(ref, 'common.close', "Yopish"),
            onTap: () => Navigator.of(sheetCtx).pop(null),
          ),
          const SizedBox(height: AppSpacing.sm),
        ]),
      ),
    );
    if (picked == null) return;
    if (picked == 'edit') {
      if (!context.mounted) return;
      context.push('/lopepay/customers/$instId/edit');
      return;
    }
    final repo = ref.read(lopepayRepositoryProvider);
    try {
      if (picked == 'mark') {
        if (!context.mounted) return;
        final monthlyPayment =
            ((inst['monthlyPayment'] ?? 0) as num).toInt();
        final nextMonth =
            ((inst['nextMonthNumber'] ?? 0) as num).toInt();
        final monthsTotal =
            ((inst['monthsTotal'] ?? 0) as num).toInt();
        final amountCtrl = TextEditingController(
            text: monthlyPayment > 0 ? monthlyPayment.toString() : '');
        final int? markOk;
        try {
          markOk = await showDialog<int?>(
            context: context,
            builder: (dCtx) => AlertDialog(
              backgroundColor: context.colors.background,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: Text(
                  nextMonth > 0
                      ? tr(
                          ref,
                          'mobile.lopepay.installment.markPaidTitle',
                          "Oyni to'langan deb belgilash ({{n}}/{{total}})",
                          {
                              'n': '$nextMonth',
                              'total': '$monthsTotal'
                            })
                      : tr(ref, 'mobile.lopepay.installment.markPaid',
                          "Oyni to'langan deb belgilash"),
                  style: AppText.titleMd),
              content: TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr(ref,
                      'mobile.customer.transactions.topUpAmount',
                      "Summa (so'm)"),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: Text(tr(ref, 'common.cancel', "Bekor"))),
                TextButton(
                    onPressed: () => Navigator.pop(
                        dCtx, int.tryParse(amountCtrl.text.trim())),
                    child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
              ],
            ),
          );
        } finally {
          amountCtrl.dispose();
        }
        if (markOk == null) return;
        await repo.markInstallmentPaid(instId, amount: markOk);
        if (context.mounted) {
          AppHaptics.success();
          AppSnack.success(
              context, tr(ref, 'common.saved', 'Saqlandi'));
        }
      } else if (picked == 'undo') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: context.colors.background,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text(
                tr(ref, 'mobile.lopepay.installment.undoConfirmTitle',
                    "Oxirgi to'lov bekor qilinsinmi?"),
                style: AppText.titleMd),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(tr(ref, 'common.cancel', "Bekor"))),
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child:
                      Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
            ],
          ),
        );
        if (ok != true) return;
        await repo.undoLastInstallmentPayment(instId);
        if (context.mounted) {
          AppSnack.success(
              context, tr(ref, 'common.saved', 'Saqlandi'));
        }
      } else if (picked == 'delete') {
        if (!context.mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (dCtx) => AlertDialog(
            backgroundColor: context.colors.background,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            title: Text(
                tr(ref, 'mobile.lopepay.installment.deleteConfirmTitle',
                    "Rassrochka o'chirilsinmi?"),
                style: AppText.titleMd),
            content: Text(
                tr(ref, 'mobile.lopepay.installment.deleteConfirmMsg',
                    "Rassrochka va uning barcha to'lovlari o'chiriladi."),
                style: AppText.body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: Text(tr(ref, 'common.cancel', "Bekor"))),
              TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: Text(tr(ref, 'common.delete', "O'chirish"))),
            ],
          ),
        );
        if (ok != true) return;
        await repo.deleteInstallment(instId);
        if (context.mounted) {
          AppSnack.success(
              context, tr(ref, 'common.deleted', "O'chirildi"));
        }
      }
      ref.invalidate(lopepayCustomerByPhoneProvider(customerId));
      ref.invalidate(lopepayDashboardProvider);
      ref.invalidate(lopepayCustomersProvider);
      ref.invalidate(lopepayInstallmentsListProvider);
    } catch (e) {
      if (context.mounted) {
        AppHaptics.error();
        AppSnack.error(context, humanize(e));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: AppRadius.rSm,
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: AppSpacing.sm),
      Text(title, style: AppText.titleMd.copyWith(fontSize: 16)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: AppRadius.rSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppText.overline
                    .copyWith(color: context.colors.textMuted, fontSize: 10)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.button.copyWith(fontSize: 13)),
          ]),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction(
      {required this.icon,
      required this.tint,
      required this.title,
      required this.onTap});
  final IconData icon;
  final Color tint;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.selection,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(title,
                style: AppText.titleSm.copyWith(fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

Widget _installmentStatusBanner(WidgetRef ref,
    {required bool isPaidOff,
    required int daysLate,
    String? nextDueDate}) {
  if (isPaidOff) {
    return _bannerRow(
        icon: Icons.check_circle,
        color: AppColors.success,
        label:
            tr(ref, 'lopePay.shop.bannerPaidOff', "To'liq to'langan"));
  }
  if (daysLate > 0) {
    return _bannerRow(
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        label: tr(ref, 'lopePay.shop.bannerOverdue',
            "{{days}} kun kechikkan", {'days': '$daysLate'}));
  }
  if (daysLate == 0 && nextDueDate != null) {
    return _bannerRow(
        icon: Icons.access_time,
        color: AppColors.warning,
        label:
            tr(ref, 'lopePay.shop.bannerDueToday', "Bugun to'lov kuni"));
  }
  if (nextDueDate != null && nextDueDate.isNotEmpty) {
    final d = DateTime.tryParse(nextDueDate);
    if (d != null) {
      final df = DateFormat('dd.MM.yyyy', 'ru_RU');
      return _bannerRow(
          icon: Icons.event_outlined,
          color: AppColors.textMuted,
          label: tr(ref, 'lopePay.shop.bannerNextDue',
              "Keyingi to'lov: {{date}}",
              {'date': df.format(d.toLocal())}));
    }
  }
  return const SizedBox.shrink();
}

Widget _bannerRow(
    {required IconData icon,
    required Color color,
    required String label}) {
  return Container(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: AppRadius.rSm,
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.button.copyWith(color: color, fontSize: 12),
        ),
      ),
    ]),
  );
}

final lopepayCustomerByPhoneProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/installments', queryParameters: {'limit': 500});
  final raw = res.data;
  final list = (raw is List)
      ? raw
      : (raw is Map && raw['data'] is List ? raw['data'] as List : <dynamic>[]);
  String name = '';
  String phone = '';
  String address = '';
  int totalDebt = 0;
  final installments = <Map<String, dynamic>>[];
  final payments = <Map<String, dynamic>>[];
  for (final r in list) {
    if (r is! Map) continue;
    final m = r.cast<String, dynamic>();
    final custPhone = (m['customerPhone'] ?? '').toString();
    if (custPhone != id) continue;
    name = (m['customerName'] ?? name).toString();
    phone = custPhone;
    totalDebt += ((m['debt'] ?? 0) as num).toInt();
    installments.add(m);
    final pays = m['payments'];
    if (pays is List) {
      final monthsTotal = ((m['monthsTotal'] ?? 0) as num).toInt();
      final productName = (m['productName'] ?? '').toString();
      for (final p in pays) {
        if (p is! Map) continue;
        final payment = p.cast<String, dynamic>();
        // Enrich each payment with the parent installment context so
        // the history card can render "Oy N/M · <product>" — same
        // shape the web /shop/installments/:id detail uses.
        payment['_monthsTotal'] = monthsTotal;
        payment['_productName'] = productName;
        payments.add(payment);
      }
    }
  }
  payments.sort((a, b) {
    final ax = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bx = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return bx.compareTo(ax);
  });
  return {
    'id': id,
    'name': name,
    'phone': phone,
    'address': address,
    'totalDebt': totalDebt,
    'installments': installments,
    'payments': payments,
  };
});
