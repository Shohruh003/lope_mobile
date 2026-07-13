import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/barber_panel_repository.dart';

class BarberBookingsScreen extends ConsumerStatefulWidget {
  const BarberBookingsScreen({super.key});

  @override
  ConsumerState<BarberBookingsScreen> createState() =>
      _BarberBookingsScreenState();
}

class _BarberBookingsScreenState extends ConsumerState<BarberBookingsScreen> {
  late DateTime _selectedDate;
  String _activeTab = 'confirmed';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  String _toDateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _monthsUz = [
    'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
    'iyul', 'avgust', 'sentyabr', 'oktyabr', 'noyabr', 'dekabr',
  ];
  static const _weekdaysUz = [
    'dushanba', 'seshanba', 'chorshanba', 'payshanba',
    'juma', 'shanba', 'yakshanba',
  ];

  /// Human-readable date shown in the header selector. Falls back to
  /// "Bugun" / "Ertaga" / "Kecha" when applicable so a barber glances at
  /// the strip and sees the right label instead of parsing an ISO date.
  String _prettyDate(DateTime d, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.tomorrow', 'Ertaga');
    if (diff == -1) return tr(ref, 'mobile.dates.yesterday', 'Kecha');
    // Longer format: "11 iyul, shanba"
    final weekday = _weekdaysUz[(d.weekday - 1) % 7];
    final month = _monthsUz[d.month - 1];
    return '${d.day} $month, $weekday';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    AppHaptics.light();
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final async = ref.watch(barberDayBookingsProvider(
        (barberId: user.id, date: _toDateStr(_selectedDate))));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(barberDayBookingsProvider(
              (barberId: user.id, date: _toDateStr(_selectedDate)))
              .future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
            Row(children: [
              _IconBtn(
                icon: Icons.chevron_left,
                onTap: () => setState(() => _selectedDate =
                    _selectedDate.subtract(const Duration(days: 1))),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: TapScale(
                  onTap: _pickDate,
                  scale: 0.97,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: context.colors.textMuted),
                      AppSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          _prettyDate(_selectedDate, ref),
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              AppSpacing.hGapSm,
              _IconBtn(
                icon: Icons.chevron_right,
                onTap: () => setState(() => _selectedDate =
                    _selectedDate.add(const Duration(days: 1))),
              ),
              if (!_isToday) ...[
                AppSpacing.hGapSm,
                TapScale(
                  onTap: () => setState(() => _selectedDate = DateTime.now()),
                  scale: 0.95,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: AppRadius.rMd,
                      boxShadow:
                          AppShadows.primaryGlow(AppColors.primary),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tr(ref, 'mobile.barber.bookingsAll.today', 'Bugun'),
                      style: AppText.button.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ]),
            AppSpacing.gapMd,
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: AppRadius.rMd,
                border: Border.all(color: context.colors.border),
              ),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
                style: AppText.body,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: Icon(Icons.search,
                      color: context.colors.textMuted, size: 20),
                  hintText: tr(ref, 'mobile.barber.bookings.searchPlaceholder',
                      'Mijoz nomi yoki telefon'),
                  hintStyle:
                      AppText.body.copyWith(color: context.colors.textMuted),
                ),
              ),
            ),
            AppSpacing.gapMd,
            async.when(
              loading: () => _tabsRow(0, 0, 0),
              error: (_, _) => _tabsRow(0, 0, 0),
              data: (list) {
                final c = list.where((b) => b.status == 'confirmed').length;
                final co = list.where((b) => b.status == 'completed').length;
                final ca = list.where((b) => b.status == 'cancelled').length;
                return _tabsRow(c, co, ca);
              },
            ),
            AppSpacing.gapLg,
            async.when(
              loading: () => const AppListSkeleton(itemCount: 5),
              error: (e, _) => SizedBox(
                height: 280,
                child: AppErrorState(message: humanize(e)),
              ),
              data: (list) {
                final filtered = list.where((b) {
                  if (b.status != _activeTab) return false;
                  if (_search.isEmpty) return true;
                  final name = (b.guestName?.isNotEmpty == true
                          ? b.guestName!
                          : b.userName)
                      .toLowerCase();
                  final phone =
                      (b.guestPhone ?? b.userPhone ?? '').toLowerCase();
                  return name.contains(_search) || phone.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return SizedBox(
                    height: 280,
                    child: AppEmptyState(
                      icon: Icons.event_available_rounded,
                      title: tr(ref, 'myBookings.empty', "Bron yo'q"),
                      message: _search.isNotEmpty
                          ? tr(ref, 'common.noResults',
                              'Hech narsa topilmadi')
                          : tr(
                              ref,
                              'mobile.barber.bookings.emptyHint',
                              "Bu sanada bron yo'q. Mijozlar yozilishi bilan bu yerda ko'rinadi."),
                    ),
                  );
                }

                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(children: [
                      Icon(Icons.people_outline,
                          size: 16, color: context.colors.textMuted),
                      AppSpacing.hGapXs,
                      Text(
                          "${filtered.length} ${tr(ref, 'mobile.barber.stats.bookingsShort', 'ta bron')}",
                          style: AppText.bodySm),
                    ]),
                  ),
                  ...filtered.asMap().entries.map((entry) {
                    final i = entry.key;
                    final b = entry.value;
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _BookingTile(b: b).animate().fadeIn(
                          duration: 200.ms, delay: (i * 25).ms),
                    );
                  }),
                ]);
              },
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _tabsRow(int confirmed, int completed, int cancelled) {
    return Row(children: [
      _StatusTab(
        label: tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan'),
        count: confirmed,
        on: _activeTab == 'confirmed',
        color: const Color(0xFF3B82F6),
        onTap: () => setState(() => _activeTab = 'confirmed'),
      ),
      AppSpacing.hGapSm,
      _StatusTab(
        label: tr(ref, 'myBookings.statusCompleted', 'Yakunlangan'),
        count: completed,
        on: _activeTab == 'completed',
        color: AppColors.success,
        onTap: () => setState(() => _activeTab = 'completed'),
      ),
      AppSpacing.hGapSm,
      _StatusTab(
        label: tr(ref, 'profile.cancelled', 'Bekor'),
        count: cancelled,
        on: _activeTab == 'cancelled',
        color: AppColors.danger,
        onTap: () => setState(() => _activeTab = 'cancelled'),
      ),
    ]);
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: context.colors.border),
        ),
        child:
            Icon(icon, color: context.colors.textMuted, size: 18),
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.on,
    required this.color,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TapScale(
        onTap: onTap,
        scale: 0.97,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.emphasized,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.rMd,
            color: on ? color.withValues(alpha: 0.1) : context.colors.surface,
            border: Border.all(
              color: on ? color : context.colors.border,
              width: on ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text(
              label,
              style: AppText.caption.copyWith(
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? color : context.colors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: AppText.numeric.copyWith(
                color: on ? color : context.colors.textBright,
                fontSize: 18,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BookingTile extends ConsumerWidget {
  const _BookingTile({required this.b});
  final BarberBooking b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = b.guestName?.isNotEmpty == true
        ? b.guestName!
        : (b.userName.isNotEmpty
            ? b.userName
            : tr(ref, 'mobile.barber.bookingsAll.client', 'Mijoz'));
    final phone = b.guestPhone ?? b.userPhone ?? '';

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppSpacing.cardPadding,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ClientAvatar(
                name: name,
                avatar: b.userAvatar,
                size: 44,
                ring: true,
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.titleSm),
                    if (phone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(phone, style: AppText.caption),
                      ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: context.colors.textMuted),
                      AppSpacing.hGapXs,
                      Text(b.time, style: AppText.caption),
                      if (b.totalDuration > 0) ...[
                        AppSpacing.hGapXs,
                        Text(
                          "(${b.totalDuration} ${tr(ref, 'booking.duration', 'daq')})",
                          style: AppText.caption,
                        ),
                      ],
                      if (b.isManual) ...[
                        AppSpacing.hGapXs,
                        AppBadge(
                          label: tr(ref,
                              'mobile.shop.bookings.manualBadge',
                              "Qo'lda"),
                          variant: AppBadgeVariant.warning,
                        ),
                      ],
                    ]),
                    if (b.notes != null && b.notes!.isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceElevated,
                          borderRadius: AppRadius.rSm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                size: 12,
                                color: context.colors.textMuted),
                            AppSpacing.hGapXs,
                            Expanded(
                              child: Text(
                                b.notes!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  color: context.colors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (b.totalPrice > 0)
                Padding(
                  padding: const EdgeInsets.only(
                      left: AppSpacing.xs, right: AppSpacing.xs),
                  child: Text(
                    "${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                    style: AppText.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (phone.isNotEmpty)
                TapScale(
                  onTap: () async {
                    AppHaptics.light();
                    final clean =
                        phone.replaceAll(RegExp(r'[^\d+]'), '');
                    final uri = Uri(scheme: 'tel', path: clean);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  scale: 0.9,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_outlined,
                        color: AppColors.primary, size: 18),
                  ),
                ),
            ]),
            if (b.status == 'confirmed') ...[
              AppSpacing.gapMd,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'myBookings.complete', 'Yakunlash'),
                    leadingIcon: Icons.check_circle_outline,
                    variant: AppButtonVariant.success,
                    size: AppButtonSize.sm,
                    fullWidth: true,
                    onPressed: () => _complete(context, ref),
                  ),
                ),
                AppSpacing.hGapSm,
                Expanded(
                  child: AppButton(
                    label:
                        tr(ref, 'myBookings.cancel', 'Bekor qilish'),
                    leadingIcon: Icons.close,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.sm,
                    fullWidth: true,
                    onPressed: () => _cancel(context, ref),
                  ),
                ),
                AppSpacing.hGapSm,
                PopupMenuButton<String>(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.more_vert,
                        size: 18, color: context.colors.textMuted),
                  ),
                  padding: EdgeInsets.zero,
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
                        const Icon(Icons.event_repeat, size: 16),
                        AppSpacing.hGapSm,
                        Text(tr(ref, 'mobile.shop.barber.reschedule',
                            "Boshqa vaqtga ko'chirish")),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'extend',
                      child: Row(children: [
                        const Icon(Icons.timer_outlined, size: 16),
                        AppSpacing.hGapSm,
                        Text(tr(ref, 'mobile.shop.barber.extend',
                            'Vaqtni uzaytirish')),
                      ]),
                    ),
                  ],
                ),
              ]),
            ],
          ]),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    int? overrideTotal;
    final priceCtrl = TextEditingController(
        text: b.totalPrice > 0 ? b.totalPrice.toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'myBookings.completeConfirmTitle',
                    'Bronni yakunlash?'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(ref, 'myBookings.completeConfirmMsg',
                    'Bron yakunlangan deb belgilanadi.'),
                style: AppText.bodySm,
              ),
              AppSpacing.gapMd,
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: AppText.body,
                decoration: InputDecoration(
                  labelText: tr(ref, 'myBookings.totalPriceLabel',
                      'Olingan summa (ixtiyoriy)'),
                  hintText: '0',
                  suffixText: tr(ref, 'common.currency', "so'm"),
                ),
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx, false),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.confirm', 'Tasdiqlash'),
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      overrideTotal =
                          int.tryParse(priceCtrl.text.trim());
                      Navigator.pop(dCtx, true);
                    },
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    try {
      if (ok != true) return;
      await ref
          .read(bookingRepositoryProvider)
          .complete(b.id, totalPrice: overrideTotal);
      ref.invalidate(barberAllBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      priceCtrl.dispose();
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'myBookings.cancelConfirmTitle',
                    'Bronni bekor qilasizmi?'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(ref, 'myBookings.cancelConfirmMsg',
                    "Bekor qilingach, qaytarib bo'lmaydi."),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.close', 'Yopish'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx, false),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label:
                        tr(ref, 'myBookings.cancel', 'Bekor qilish'),
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.pop(dCtx, true),
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(barberAllBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'myBookings.cancelled',
                'Bron bekor qilindi'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    final initial = DateTime.tryParse(b.date) ?? DateTime.now();
    final pickedDate = await AppDatePicker.show(
      context,
      ref: ref,
      initial: initial,
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
        await AppTimePicker.show(context, ref: ref, initial: initTime);
    if (pickedTime == null) return;
    final newDate =
        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    final newTime =
        "${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}";
    try {
      await ref
          .read(bookingRepositoryProvider)
          .reschedule(b.id, date: newDate, time: newTime);
      ref.invalidate(barberAllBookingsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    int minutes = 30;
    final ok = await showDialog<int>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.shop.barber.extendTitle',
                    'Vaqtni uzaytirish (daqiqa)'),
                style: AppText.titleMd,
              ),
              AppSpacing.gapMd,
              StatefulBuilder(builder: (sCtx, setSt) {
                return DropdownButtonFormField<int>(
                  initialValue: minutes,
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('+15')),
                    DropdownMenuItem(value: 30, child: Text('+30')),
                    DropdownMenuItem(value: 45, child: Text('+45')),
                    DropdownMenuItem(value: 60, child: Text('+60')),
                    DropdownMenuItem(value: 90, child: Text('+90')),
                  ],
                  onChanged: (v) => setSt(() => minutes = v ?? 30),
                );
              }),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.confirm', 'Tasdiqlash'),
                    variant: AppButtonVariant.primary,
                    onPressed: () => Navigator.pop(dCtx, minutes),
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == null) return;
    try {
      await ref
          .read(barberPanelRepositoryProvider)
          .extendDuration(b.id, ok);
      ref.invalidate(barberAllBookingsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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
