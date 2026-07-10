import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../barber_panel/data/barber_panel_repository.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/shop_repository.dart';

class ShopBookingsScreen extends ConsumerStatefulWidget {
  const ShopBookingsScreen({super.key});
  @override
  ConsumerState<ShopBookingsScreen> createState() => _ShopBookingsScreenState();
}

class _ShopBookingsScreenState extends ConsumerState<ShopBookingsScreen> {
  DateTime? _date = DateTime.now();
  String _barberId = 'all';
  String _status = 'all';
  int _page = 1;

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _page = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mastersAsync = ref.watch(shopBarbersProvider);
    final bookingsAsync = ref.watch(shopBookingsFilteredProvider((
      date: _date == null ? null : _dateStr(_date!),
      barberId: _barberId == 'all' ? null : _barberId,
      status: _status == 'all' ? null : _status,
      page: _page,
    )));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(shopBarbersProvider);
            ref.invalidate(shopBookingsFilteredProvider);
            await ref.read(shopBookingsFilteredProvider((
              date: _date == null ? null : _dateStr(_date!),
              barberId: _barberId == 'all' ? null : _barberId,
              status: _status == 'all' ? null : _status,
              page: _page,
            )).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(tr(ref, 'mobile.shop.bookings.title', "Salon bronlari"),
                  style: AppText.titleMd),
              const SizedBox(height: AppSpacing.lg),

              TapScale(
                onTap: _pickDate,
                haptic: HapticStrength.light,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: AppRadius.rSm,
                      ),
                      child: const Icon(Icons.calendar_today_outlined,
                          size: 15, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(ref, 'booking.date', 'Sana'),
                              style: AppText.overline
                                  .copyWith(color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                              _date == null
                                  ? tr(ref, 'mobile.shop.bookings.allDates',
                                      "Barcha sanalar")
                                  : _dateStr(_date!),
                              style: AppText.titleSm.copyWith(fontSize: 14)),
                        ],
                      ),
                    ),
                    if (_date != null)
                      TapScale(
                        onTap: () => setState(() {
                          _date = null;
                          _page = 1;
                        }),
                        haptic: HapticStrength.light,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.1),
                            borderRadius: AppRadius.rSm,
                          ),
                          child: const Icon(Icons.close,
                              size: 14, color: AppColors.danger),
                        ),
                      ),
                    const SizedBox(width: AppSpacing.xs),
                    TapScale(
                      onTap: () => setState(() {
                        _date = DateTime.now();
                        _page = 1;
                      }),
                      haptic: HapticStrength.light,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.rSm,
                        ),
                        child: const Icon(Icons.today_outlined,
                            size: 14, color: AppColors.primary),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              mastersAsync.maybeWhen(
                data: (masters) => _filterDropdown<String>(
                  label: tr(ref, 'mobile.shop.bookings.masterLabel', "Master"),
                  icon: Icons.person_outline,
                  value: _barberId,
                  items: [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text(tr(ref, 'common.all', "Barchasi"))),
                    ...masters.map((b) =>
                        DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: (v) => setState(() {
                    _barberId = v ?? 'all';
                    _page = 1;
                  }),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),

              _filterDropdown<String>(
                label: tr(ref, 'mobile.shop.bookings.statusLabel', "Status"),
                icon: Icons.flag_outlined,
                value: _status,
                items: [
                  DropdownMenuItem(
                      value: 'all',
                      child: Text(tr(ref, 'common.all', "Barchasi"))),
                  DropdownMenuItem(
                      value: 'confirmed',
                      child: Text(tr(ref, 'myBookings.statusConfirmed',
                          "Tasdiqlangan"))),
                  DropdownMenuItem(
                      value: 'completed',
                      child: Text(tr(ref, 'myBookings.statusCompleted',
                          "Yakunlangan"))),
                  DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(tr(ref, 'myBookings.statusCancelled',
                          "Bekor qilingan"))),
                ],
                onChanged: (v) => setState(() {
                  _status = v ?? 'all';
                  _page = 1;
                }),
              ),
              const SizedBox(height: AppSpacing.md),

              bookingsAsync.maybeWhen(
                data: (res) => Row(children: [
                  const Icon(Icons.event_note,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                      "${res.total} ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')}",
                      style: AppText.caption),
                ]),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm),

              bookingsAsync.when(
                loading: () => const AppListSkeleton(itemCount: 5),
                error: (e, _) => SizedBox(
                  height: 280,
                  child: AppErrorState(message: humanize(e)),
                ),
                data: (res) {
                  final list = res.data;
                  final totalPages = res.totalPages;
                  if (list.isEmpty) {
                    return SizedBox(
                      height: 280,
                      child: AppEmptyState(
                        icon: Icons.event_available_rounded,
                        title: tr(ref, 'mobile.shop.bookings.emptyForDay',
                            "Bu sanada bronlar yo'q"),
                        message: tr(
                          ref,
                          'mobile.shop.bookings.emptyForDayHint',
                          "Mijozlar yozilishi bilan barcha barberlarning bronlari shu yerda ko'rinadi.",
                        ),
                      ),
                    );
                  }
                  final sorted = [...list]
                    ..sort((a, b) => a.time.compareTo(b.time));
                  return Column(
                    children: [
                      ...sorted.asMap().entries.map((e) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _BookingCard(b: e.value)
                                .animate()
                                .fadeIn(
                                    duration: 200.ms,
                                    delay: (e.key * 20).ms),
                          )),
                      if (totalPages > 1 && _date == null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _Pager(
                          page: _page,
                          totalPages: totalPages,
                          prevLabel: tr(ref, 'common.prev', "Oldingi"),
                          nextLabel: tr(ref, 'common.next', "Keyingi"),
                          onPrev: _page <= 1
                              ? null
                              : () => setState(() => _page--),
                          onNext: _page >= totalPages
                              ? null
                              : () => setState(() => _page++),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withValues(alpha: 0.1),
            borderRadius: AppRadius.rSm,
          ),
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text("$label:",
            style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: onChanged,
              style: AppText.body.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.textBright),
              dropdownColor: AppColors.surface,
              icon: const Icon(Icons.expand_more,
                  size: 18, color: AppColors.textMuted),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.prevLabel,
    required this.nextLabel,
    required this.onPrev,
    required this.onNext,
  });
  final int page;
  final int totalPages;
  final String prevLabel;
  final String nextLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      AppButton(
        label: prevLabel,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.sm,
        onPressed: onPrev,
        leadingIcon: Icons.chevron_left,
      ),
      const SizedBox(width: AppSpacing.md),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.rPill,
        ),
        child: Text("$page / $totalPages",
            style: AppText.button.copyWith(color: AppColors.primary)),
      ),
      const SizedBox(width: AppSpacing.md),
      AppButton(
        label: nextLabel,
        variant: AppButtonVariant.secondary,
        size: AppButtonSize.sm,
        onPressed: onNext,
        trailingIcon: Icons.chevron_right,
      ),
    ]);
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.b});
  final ShopBooking b;

  AppBadgeVariant get _statusVariant {
    switch (b.status) {
      case 'completed':
        return AppBadgeVariant.success;
      case 'cancelled':
        return AppBadgeVariant.danger;
      default:
        return AppBadgeVariant.info;
    }
  }

  String _statusText(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return tr(ref, 'myBookings.statusCompleted', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'profile.cancelled', 'Bekor');
      default:
        return tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      variant: AppCardVariant.flat,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: b.barberId.isEmpty
          ? null
          : () => GoRouter.of(context).push('/shop/barbers/${b.barberId}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: AppRadius.rSm,
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Text(b.time,
              style: AppText.button
                  .copyWith(color: AppColors.primary, fontSize: 13)),
        ),
        const SizedBox(width: AppSpacing.md),
        ClipOval(
          child: (b.barberAvatar?.isNotEmpty ?? false)
              ? CachedNetworkImage(
                  imageUrl: assetUrl(b.barberAvatar),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _avatarFallback(b.barberName),
                )
              : _avatarFallback(b.barberName),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.userName,
                  style: AppText.titleSm.copyWith(fontSize: 14)),
              const SizedBox(height: 3),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.person_outline,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(b.barberName,
                      style: AppText.caption.copyWith(fontSize: 11)),
                  if (b.userPhone != null && b.userPhone!.isNotEmpty) ...[
                    Text("  •  ",
                        style: AppText.caption.copyWith(fontSize: 11)),
                    Text(b.userPhone!,
                        style: AppText.caption.copyWith(fontSize: 11)),
                  ],
                  if (b.totalDuration > 0) ...[
                    Text("  •  ",
                        style: AppText.caption.copyWith(fontSize: 11)),
                    const Icon(Icons.access_time,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Text("${b.totalDuration}m",
                        style: AppText.caption.copyWith(fontSize: 11)),
                  ],
                  if (b.isManual) ...[
                    const SizedBox(width: 6),
                    AppBadge(
                      label: tr(ref, 'mobile.shop.bookings.manualBadge',
                          "Qo'lda"),
                      variant: AppBadgeVariant.warning,
                    ),
                  ],
                ],
              ),
              if (b.notes != null && b.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(
                            fontStyle: FontStyle.italic, fontSize: 12)),
                  ),
                ]),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                AppBadge(
                    label: _statusText(ref),
                    variant: _statusVariant,
                    dot: true),
                const Spacer(),
                if (b.totalPrice > 0)
                  Text(
                      "${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.titleSm.copyWith(
                          color: AppColors.primary, fontSize: 14)),
              ]),
              if (b.status == 'confirmed') ...[
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  AppButton(
                    label: tr(ref, 'myBookings.complete', "Yakunlash"),
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.sm,
                    leadingIcon: Icons.check_circle_outline,
                    onPressed: () => _complete(context, ref),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: tr(ref, 'myBookings.cancel', "Bekor qilish"),
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    leadingIcon: Icons.close,
                    onPressed: () => _cancel(context, ref),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md)),
                    onSelected: (value) async {
                      if (value == 'reschedule') {
                        await _reschedule(context, ref);
                      } else if (value == 'extend') {
                        await _extend(context, ref);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reschedule',
                        child: Row(children: [
                          const Icon(Icons.event_repeat,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(tr(ref, 'mobile.shop.barber.reschedule',
                              "Boshqa vaqtga ko'chirish")),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'extend',
                        child: Row(children: [
                          const Icon(Icons.timer_outlined,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(tr(ref, 'mobile.shop.barber.extend',
                              "Vaqtni uzaytirish")),
                        ]),
                      ),
                    ],
                  ),
                ]),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _avatarFallback(String name) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.25),
              AppColors.primary.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppText.titleSm
              .copyWith(color: AppColors.primary, fontSize: 14),
        ),
      );

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    int? overrideTotal;
    final priceCtrl = TextEditingController(
        text: b.totalPrice > 0 ? b.totalPrice.toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'myBookings.completeConfirmTitle', "Bronni yakunlash?"),
            style: AppText.titleMd),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              tr(ref, 'myBookings.completeConfirmMsg',
                  "Bron yakunlangan deb belgilanadi."),
              style: AppText.body),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tr(ref, 'myBookings.totalPriceLabel',
                  "Olingan summa (ixtiyoriy)"),
              hintText: '0',
              suffixText: tr(ref, 'common.currency', "so'm"),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () {
                overrideTotal = int.tryParse(priceCtrl.text.trim());
                Navigator.pop(dCtx, true);
              },
              child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
        ],
      ),
    );
    try {
      if (ok != true) return;
      await ref
          .read(bookingRepositoryProvider)
          .complete(b.id, totalPrice: overrideTotal);
      ref.invalidate(shopBookingsFilteredProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', "Saqlandi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      priceCtrl.dispose();
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'myBookings.cancelConfirmTitle', "Bronni bekor qilasizmi?"),
            style: AppText.titleMd),
        content: Text(
            tr(ref, 'myBookings.cancelConfirmMsg',
                "Bekor qilingach, qaytarib bo'lmaydi."),
            style: AppText.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.close', "Yopish"))),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(dCtx, true),
              child: Text(tr(ref, 'myBookings.cancel', "Bekor qilish"))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(shopBookingsFilteredProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'myBookings.cancelled',
                "Bron bekor qilindi"))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final initial = DateTime.tryParse(b.date) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;
    final parts = b.time.split(':');
    final initTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final pickedTime =
        await showTimePicker(context: context, initialTime: initTime);
    if (pickedTime == null) return;
    final newDate =
        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    final newTime =
        "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
    try {
      await ref
          .read(bookingRepositoryProvider)
          .reschedule(b.id, date: newDate, time: newTime);
      ref.invalidate(shopBookingsFilteredProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', "Saqlandi"))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    int minutes = 30;
    final ok = await showDialog<int>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'mobile.shop.barber.extendTitle',
                "Vaqtni uzaytirish (daqiqa)"),
            style: AppText.titleMd),
        content: StatefulBuilder(builder: (sCtx, setSt) {
          return DropdownButtonFormField<int>(
            initialValue: minutes,
            items: const [
              DropdownMenuItem(value: 15, child: Text("+15")),
              DropdownMenuItem(value: 30, child: Text("+30")),
              DropdownMenuItem(value: 45, child: Text("+45")),
              DropdownMenuItem(value: 60, child: Text("+60")),
              DropdownMenuItem(value: 90, child: Text("+90")),
            ],
            onChanged: (v) => setSt(() => minutes = v ?? 30),
          );
        }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
              onPressed: () => Navigator.pop(dCtx, minutes),
              child: Text(tr(ref, 'common.confirm', "Tasdiqlash"))),
        ],
      ),
    );
    if (ok == null) return;
    try {
      await ref
          .read(barberPanelRepositoryProvider)
          .extendDuration(b.id, ok);
      ref.invalidate(shopBookingsFilteredProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', "Saqlandi"))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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
}

final shopBookingsFilteredProvider = FutureProvider.family<
    ({List<ShopBooking> data, int total, int totalPages, bool hasMore}),
    ({String? date, String? barberId, String? status, int page})>(
    (ref, key) async {
  return ref.watch(shopRepositoryProvider).bookingsPaged(
        date: key.date,
        barberId: key.barberId,
        status: key.status,
        page: key.page,
      );
});
