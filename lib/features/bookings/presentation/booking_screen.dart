import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../barbers/data/barber_repository.dart';
import '../../barbers/domain/barber.dart';
import '../data/booking_repository.dart';

/// Ideal-quality booking flow — 3 qadamli oqim, sticky pastdagi CTA bar,
/// mikro-animatsiyalar, TapScale + haptik hamma joyda. State/API mantiqi
/// avvalgidek: services multi-select, kunlik slot yuklash, submitting/
/// gender-restrict tekshiruv, snackbar bilan xato ko'rsatish.
///
///   Qadam 1  — Xizmat(lar) tanlash
///   Qadam 2  — Sana + vaqt
///   Qadam 3  — Xulosa + izoh + tasdiqlash
///
/// Tasdiqlangandan keyin — success ekrani calendar-style card bilan.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  int _step = 1;
  final Set<String> _selectedServiceIds = {};
  DateTime? _selectedDate;
  String? _selectedTime;
  String _notes = '';
  bool _submitting = false;
  bool _confirmed = false;
  final TextEditingController _notesCtrl = TextEditingController();

  static const _weekDays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _months = [
    'yan', 'fev', 'mar', 'apr', 'may', 'iyn',
    'iyl', 'avg', 'sen', 'okt', 'noy', 'dek',
  ];

  late final List<DateTime> _days = List.generate(14, (i) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + i);
  });

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prettyDate(DateTime d) {
    final now = DateTime.now();
    final t = DateTime(now.year, now.month, now.day);
    final di = DateTime(d.year, d.month, d.day);
    final diff = di.difference(t).inDays;
    if (diff == 0) return tr(ref, 'mobile.dates.today', 'Bugun');
    if (diff == 1) return tr(ref, 'mobile.dates.tomorrow', 'Ertaga');
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showLoginRequired());
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final barberAsync = ref.watch(barberDetailProvider(widget.barberId));

    return Scaffold(
      body: SafeArea(
        child: barberAsync.when(
          loading: () => const AppListSkeleton(itemCount: 5),
          error: (e, _) => AppErrorState(
            message: humanize(e),
            onRetry: () =>
                ref.invalidate(barberDetailProvider(widget.barberId)),
          ),
          data: (barber) {
            if (_confirmed) return _ConfirmedView(barber: barber, date: _selectedDate!, time: _selectedTime!, prettyDate: _prettyDate);

            return Column(children: [
              _TopBar(
                title: tr(ref, 'booking.title', 'Bron qilish'),
                onBack: () => context.pop(),
              ),
              _StepIndicator(current: _step, ref: ref),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.base,
                  switchInCurve: AppMotion.emphasized,
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        96, // sticky bar bo'shligi
                      ),
                      children: [
                        if (_step == 1) _stepServices(barber),
                        if (_step == 2) _stepDateTime(barber),
                        if (_step == 3) _stepConfirm(barber),
                      ],
                    ),
                  ),
                ),
              ),
              _StickyActionBar(
                step: _step,
                canProceed: _canProceed(barber),
                submitting: _submitting,
                onBack: _step > 1
                    ? () {
                        AppHaptics.light();
                        setState(() => _step -= 1);
                      }
                    : null,
                onNext: _step < 3
                    ? () {
                        AppHaptics.medium();
                        setState(() => _step += 1);
                      }
                    : () => _submit(barber),
                nextLabel: _step < 3
                    ? tr(ref, 'common.continue', 'Davom etish')
                    : tr(ref, 'common.confirm', 'Tasdiqlash'),
                nextIcon: _step < 3 ? Icons.arrow_forward : Icons.check,
              ),
            ]);
          },
        ),
      ),
    );
  }

  bool _canProceed(Barber barber) {
    if (_step == 1) {
      // If barber has no services, we let them proceed (services empty is OK).
      return barber.services.isEmpty || _selectedServiceIds.isNotEmpty;
    }
    if (_step == 2) return _selectedDate != null && _selectedTime != null;
    return true;
  }

  // ═════════════════════════ STEP 1: Services ═════════════════════════
  Widget _stepServices(Barber barber) {
    final hasNoServices = barber.services.isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.content_cut,
        title: tr(ref, 'booking.selectService', 'Xizmatlarni tanlang'),
        subtitle: hasNoServices
            ? null
            : tr(ref, 'mobile.booking.multiSelectHint',
                'Bir yoki bir necha xizmatni tanlashingiz mumkin'),
      ),
      AppSpacing.gapLg,
      if (hasNoServices)
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppSpacing.cardPadding,
          color: AppColors.primary.withValues(alpha: 0.06),
          borderColor: AppColors.primary.withValues(alpha: 0.3),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: AppColors.primary, size: 20),
            AppSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(ref, 'booking.noServicesTitle',
                        'Xizmatlar belgilanmagan'),
                    style: AppText.titleSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(ref, 'booking.agreedOnSite',
                        'Sartarosh bilan kelishasiz'),
                    style: AppText.bodySm,
                  ),
                ],
              ),
            ),
          ]),
        )
      else
        ...barber.services.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final on = _selectedServiceIds.contains(s.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TapScale(
              onTap: () => setState(() {
                AppHaptics.selection();
                if (on) {
                  _selectedServiceIds.remove(s.id);
                } else {
                  _selectedServiceIds.add(s.id);
                }
              }),
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: on
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.surface,
                  borderRadius: AppRadius.rLg,
                  border: Border.all(
                    color: on ? AppColors.primary : AppColors.border,
                    width: on ? 2 : 1,
                  ),
                  boxShadow:
                      on ? AppShadows.primaryGlow(AppColors.primary) : null,
                ),
                child: Row(children: [
                  Text(s.icon, style: const TextStyle(fontSize: 26)),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: AppText.titleSm),
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.access_time_outlined,
                              size: 11, color: AppColors.textMuted),
                          AppSpacing.hGapXs,
                          Text(
                              "${s.duration} ${tr(ref, 'booking.duration', 'daq')}",
                              style: AppText.caption),
                        ]),
                      ],
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Text(
                    s.priceMax != null && s.priceMax! > s.price
                        ? "${_fmt(s.price)} – ${_fmt(s.priceMax!)}"
                        : _fmt(s.price),
                    style: AppText.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppSpacing.hGapSm,
                  AnimatedContainer(
                    duration: AppMotion.short,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: on ? AppColors.primary : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: on
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                ]),
              ),
            ).animate().fadeIn(
                duration: 200.ms,
                delay: (i * 40).ms,
                curve: AppMotion.emphasized),
          );
        }),
      if (!hasNoServices && _selectedServiceIds.isNotEmpty) ...[
        AppSpacing.gapMd,
        _SelectedSummaryStrip(
          count: _selectedServiceIds.length,
          totalPrice: barber.services
              .where((s) => _selectedServiceIds.contains(s.id))
              .fold<int>(0, (a, s) => a + s.price),
          currency: tr(ref, 'common.currency', "so'm"),
          fmt: _fmt,
        ),
      ],
    ]);
  }

  // ═════════════════════════ STEP 2: Date + Time ═════════════════════════
  Widget _stepDateTime(Barber barber) {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return const SizedBox.shrink();
    final dateKey = _selectedDate == null
        ? null
        : (barberId: barber.id, date: _dateStr(_selectedDate!));
    final slotsAsync =
        dateKey == null ? null : ref.watch(daySlotsProvider(dateKey));
    final bookedAsync =
        dateKey == null ? null : ref.watch(bookedTimesProvider(dateKey));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.calendar_today_outlined,
        title: tr(ref, 'booking.selectDate', 'Sanani tanlang'),
      ),
      AppSpacing.gapMd,

      // Date strip
      SizedBox(
        height: 92,
        child: Consumer(builder: (context, ref, _) {
          final scheduledAsync = ref.watch(scheduledDatesProvider((
            barberId: widget.barberId,
            datesKey: _days.map(_dateStr).join(','),
          )));
          final scheduledSet = scheduledAsync.maybeWhen(
              data: (l) => l.toSet(), orElse: () => <String>{});
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            itemBuilder: (context, i) {
              final d = _days[i];
              final dateKey = _dateStr(d);
              final hasSchedule = scheduledSet.contains(dateKey) ||
                  scheduledAsync.maybeWhen(
                      loading: () => true, orElse: () => false);
              final isSelected = _selectedDate != null &&
                  d.year == _selectedDate!.year &&
                  d.month == _selectedDate!.month &&
                  d.day == _selectedDate!.day;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _DateChip(
                  weekDay: trList(ref, 'mobile.dates.weekDaysShort',
                      _weekDays)[d.weekday - 1],
                  day: d.day,
                  month: _months[d.month - 1],
                  selected: isSelected,
                  enabled: hasSchedule,
                  onTap: hasSchedule
                      ? () => setState(() {
                            AppHaptics.selection();
                            _selectedDate = d;
                            _selectedTime = null;
                          })
                      : null,
                ),
              );
            },
          );
        }),
      ),

      AppSpacing.gapXl,

      if (_selectedDate != null) ...[
        _SectionTitle(
          icon: Icons.access_time,
          title: tr(ref, 'booking.selectTime', 'Vaqtni tanlang'),
        ),
        AppSpacing.gapMd,
        slotsAsync?.when(
              loading: () => _SlotSkeletonGrid(),
              error: (e, _) => AppCard(
                variant: AppCardVariant.outlined,
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.danger, size: 18),
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      humanize(e),
                      style: AppText.bodySm.copyWith(color: AppColors.danger),
                    ),
                  ),
                ]),
              ),
              data: (slots) {
                if (slots.isEmpty) {
                  return SizedBox(
                    height: 160,
                    child: AppEmptyState(
                      icon: Icons.event_busy_outlined,
                      title:
                          tr(ref, 'common.noSlots', "Bu kunda bo'sh vaqt yo'q"),
                      message: tr(ref, 'mobile.booking.tryAnotherDate',
                          'Boshqa sanani tanlab ko\'ring'),
                    ),
                  );
                }
                final booked = bookedAsync?.maybeWhen(
                        data: (v) => v, orElse: () => <String>[]) ??
                    [];
                final now = DateTime.now();
                final isToday = _selectedDate!.year == now.year &&
                    _selectedDate!.month == now.month &&
                    _selectedDate!.day == now.day;
                final nowMin = now.hour * 60 + now.minute;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final t = slots[i];
                    final parts = t.split(':');
                    final slotMin =
                        int.parse(parts[0]) * 60 + int.parse(parts[1]);
                    final isPast = isToday && slotMin <= nowMin;
                    final isBooked = booked.contains(t);
                    final disabled = isPast || isBooked;
                    final isOn = _selectedTime == t;

                    return _TimeChip(
                      label: t,
                      selected: isOn,
                      disabled: disabled,
                      onTap: disabled
                          ? null
                          : () => setState(() {
                                AppHaptics.selection();
                                _selectedTime = t;
                              }),
                    );
                  },
                );
              },
            ) ??
            const SizedBox.shrink(),
      ] else
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppSpacing.cardPadding,
          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
          child: Row(children: [
            const Icon(Icons.info_outline,
                color: AppColors.textMuted, size: 18),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                tr(ref, 'mobile.booking.pickDateFirst',
                    "Vaqtlarni ko'rish uchun sanani tanlang"),
                style: AppText.bodySm,
              ),
            ),
          ]),
        ),
    ]);
  }

  // ═════════════════════════ STEP 3: Confirm ═════════════════════════
  Widget _stepConfirm(Barber barber) {
    final selectedServices = barber.services
        .where((s) => _selectedServiceIds.contains(s.id))
        .toList();
    final totalPrice =
        selectedServices.fold<int>(0, (a, s) => a + s.price);
    final totalDuration =
        selectedServices.fold<int>(0, (a, s) => a + s.duration);
    final hasNoServices = barber.services.isEmpty;
    final currency = tr(ref, 'common.currency', "so'm");

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _SectionTitle(
        icon: Icons.check_circle_outline,
        title: tr(ref, 'booking.confirmBooking', 'Bronni tasdiqlash'),
        subtitle: tr(ref, 'mobile.booking.reviewHint',
            "Ma'lumotlarni tekshirib chiqing"),
      ),
      AppSpacing.gapLg,

      // Summary card
      AppCard(
        variant: AppCardVariant.outlined,
        padding: EdgeInsets.zero,
        radius: AppRadius.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barber header with primary tint
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.xl),
                  topRight: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Row(children: [
                ClipOval(
                  child: barber.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: assetUrl(barber.avatar),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              const SkeletonCircle(size: 48),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient),
                          alignment: Alignment.center,
                          child: Text(
                            barber.name.isNotEmpty ? barber.name[0] : '?',
                            style: AppText.titleMd.copyWith(color: Colors.white),
                          ),
                        ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(barber.name, style: AppText.titleMd),
                      if (barber.location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 11, color: AppColors.textMuted),
                          AppSpacing.hGapXs,
                          Expanded(
                            child: Text(
                              barber.location,
                              style: AppText.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            // Body rows
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(children: [
                if (hasNoServices)
                  _SummaryRow(
                    icon: Icons.info_outline,
                    label: tr(ref, 'booking.service', 'Xizmat'),
                    value: tr(ref, 'booking.agreedOnSite',
                        'Sartarosh bilan kelishasiz'),
                  )
                else
                  ...selectedServices.map((s) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(children: [
                          Text(s.icon, style: const TextStyle(fontSize: 18)),
                          AppSpacing.hGapSm,
                          Expanded(
                            child: Text(s.name, style: AppText.body),
                          ),
                          Text(
                            s.priceMax != null && s.priceMax! > s.price
                                ? "${_fmt(s.price)} – ${_fmt(s.priceMax!)} $currency"
                                : "${_fmt(s.price)} $currency",
                            style: AppText.body.copyWith(
                              color: AppColors.textBright,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      )),
                const Divider(color: AppColors.border, height: 24),
                _SummaryRow(
                  icon: Icons.calendar_today_outlined,
                  label: tr(ref, 'booking.date', 'Sana'),
                  value: _prettyDate(_selectedDate!),
                ),
                AppSpacing.gapSm,
                _SummaryRow(
                  icon: Icons.access_time,
                  label: tr(ref, 'booking.time', 'Vaqt'),
                  value: hasNoServices
                      ? (_selectedTime ?? '')
                      : "${_selectedTime ?? ''} · $totalDuration ${tr(ref, 'booking.duration', 'daq')}",
                ),
                const Divider(color: AppColors.border, height: 24),
                Row(children: [
                  Text(
                    tr(ref, 'booking.price', 'Narx'),
                    style: AppText.titleSm,
                  ),
                  const Spacer(),
                  Text(
                    hasNoServices
                        ? tr(ref, 'booking.agreedOnSite',
                            'Sartarosh bilan kelishasiz')
                        : "${_fmt(totalPrice)} $currency",
                    style: AppText.titleMd.copyWith(
                      color: AppColors.primary,
                      fontSize: hasNoServices ? 14 : 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),

      AppSpacing.gapLg,

      // Notes
      Text(
        tr(ref, 'booking.notes', 'Izoh'),
        style: AppText.overline,
      ),
      AppSpacing.gapSm,
      TextField(
        controller: _notesCtrl,
        onChanged: (v) => _notes = v,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: tr(ref, 'booking.notesPlaceholder',
              "Qo'shimcha ma'lumot (ixtiyoriy)"),
        ),
      ),
    ]);
  }

  // ═════════════════════════ Auth guard ═════════════════════════
  bool _loginPromptShown = false;
  Future<void> _showLoginRequired() async {
    if (_loginPromptShown || !mounted) return;
    _loginPromptShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_person,
                      color: AppColors.primary, size: 22),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Text(
                    tr(ref, 'booking.accountNeeded', 'Akkaunt kerak'),
                    style: AppText.titleMd,
                  ),
                ),
              ]),
              AppSpacing.gapMd,
              Text(
                tr(ref, 'booking.accountNeededHint',
                    "Bron qilish uchun avval ro'yxatdan o'ting yoki tizimga kiring."),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(dCtx).pop();
                      if (mounted) context.pop();
                    },
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'auth.login', 'Kirish'),
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(dCtx).pop();
                      if (mounted) context.go('/login');
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
  }

  // ═════════════════════════ Submit ═════════════════════════
  Future<void> _submit(Barber barber) async {
    AppHaptics.medium();
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    // Gender restriction guard
    final tg = barber.targetGender;
    if (tg == 'MALE_ONLY' || tg == 'FEMALE_ONLY') {
      final needFemale = tg == 'FEMALE_ONLY';
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => Dialog(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needFemale
                      ? tr(ref, 'booking.femaleOnlyTitle',
                          "Faqat ayollar uchun")
                      : tr(ref, 'booking.maleOnlyTitle',
                          "Faqat erkaklar uchun"),
                  style: AppText.titleMd,
                ),
                AppSpacing.gapSm,
                Text(
                  needFemale
                      ? tr(ref, 'booking.femaleOnlyMsg',
                          "Bu sartarosh faqat ayol mijozlarni qabul qiladi. Davom etishni xohlaysizmi?")
                      : tr(ref, 'booking.maleOnlyMsg',
                          "Bu sartarosh faqat erkak mijozlarni qabul qiladi. Davom etishni xohlaysizmi?"),
                  style: AppText.bodySm,
                ),
                AppSpacing.gapLg,
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.cancel', 'Bekor'),
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.of(dCtx).pop(false),
                      fullWidth: true,
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.continue', 'Davom'),
                      variant: AppButtonVariant.primary,
                      onPressed: () => Navigator.of(dCtx).pop(true),
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
    }

    setState(() => _submitting = true);
    try {
      final picked = barber.services
          .where((s) => _selectedServiceIds.contains(s.id))
          .toList();
      final totalPrice = picked.fold<int>(0, (a, s) => a + s.price);
      final totalDuration = picked.fold<int>(0, (a, s) => a + s.duration);
      await ref.read(bookingRepositoryProvider).create(
            userId: user.id,
            barberId: barber.id,
            date: _dateStr(_selectedDate!),
            time: _selectedTime!,
            services: picked
                .map((s) => {
                      'id': s.id,
                      'name': s.name,
                      'nameUz': s.nameUz.isEmpty ? s.name : s.nameUz,
                      'nameRu': s.nameRu,
                      'price': s.price,
                      'duration': s.duration,
                      'icon': s.icon,
                    })
                .toList(),
            totalPrice: totalPrice,
            totalDuration: totalDuration,
            notes: _notes.trim().isEmpty ? null : _notes.trim(),
          );
      if (mounted) {
        AppHaptics.success();
        setState(() => _confirmed = true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      AppHaptics.error();
      final body = e.response?.data;
      final code = body is Map ? (body['code'] ?? '').toString() : '';
      final status = e.response?.statusCode;
      String msg;
      if (code == 'SLOT_TAKEN' || status == 409) {
        msg = tr(ref, 'booking.slotTaken',
            "Bu vaqt allaqachon band qilingan");
      } else if (code == 'GENDER_REQUIRED') {
        msg = tr(ref, 'booking.genderRequired',
            "Avval profilingizda jinsni belgilang");
      } else if (code == 'GENDER_RESTRICTED_MALE') {
        msg = tr(ref, 'booking.genderRestrictionMale',
            "Bu sartarosh faqat erkak mijozlarni qabul qiladi");
      } else if (code == 'GENDER_RESTRICTED_FEMALE') {
        msg = tr(ref, 'booking.genderRestrictionFemale',
            "Bu sartarosh faqat ayol mijozlarni qabul qiladi");
      } else if (status == 403) {
        msg = tr(ref, 'booking.genderRestriction',
            "Sartarosh sizni qabul qila olmaydi");
      } else {
        msg = tr(ref, 'common.error', 'Xatolik');
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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

// ═════════════════════════ Widgets ═════════════════════════

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        TapScale(
          onTap: onBack,
          scale: 0.9,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
        AppSpacing.hGapMd,
        Text(title, style: AppText.titleMd),
      ]),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.ref});
  final int current;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr(ref, 'mobile.booking.stepServices', 'Xizmat'),
      tr(ref, 'mobile.booking.stepTime', 'Vaqt'),
      tr(ref, 'mobile.booking.stepConfirm', 'Tasdiq'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(3, (i) {
          final stepNum = i + 1;
          final isDone = stepNum < current;
          final isCurrent = stepNum == current;
          final isActive = isDone || isCurrent;
          return Expanded(
            child: Row(children: [
              AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isActive ? AppColors.primary : AppColors.border,
                  ),
                  boxShadow: isCurrent
                      ? AppShadows.primaryGlow(AppColors.primary)
                      : null,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check,
                        color: Colors.white, size: 16)
                    : Text(
                        '$stepNum',
                        style: AppText.button.copyWith(
                          color: isCurrent
                              ? Colors.white
                              : AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: Text(
                  labels[i],
                  style: AppText.caption.copyWith(
                    color: isActive
                        ? AppColors.textBright
                        : AppColors.textMuted,
                    fontWeight:
                        isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stepNum < 3)
                Container(
                  width: 16,
                  height: 2,
                  color: isDone ? AppColors.primary : AppColors.border,
                ),
            ]),
          );
        }),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 18, color: AppColors.textBright),
          AppSpacing.hGapSm,
          Expanded(child: Text(title, style: AppText.titleMd)),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(subtitle!, style: AppText.bodySm),
          ),
        ],
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.weekDay,
    required this.day,
    required this.month,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String weekDay;
  final int day;
  final String month;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.emphasized,
          width: 68,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.primaryGradient : null,
            color: selected ? null : AppColors.surface,
            borderRadius: AppRadius.rLg,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 0 : 1,
            ),
            boxShadow:
                selected ? AppShadows.primaryGlow(AppColors.primary) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekDay,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      selected ? Colors.white70 : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$day',
                style: AppText.titleMd.copyWith(
                  fontSize: 20,
                  color: selected ? Colors.white : AppColors.textBright,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                month,
                style: AppText.caption.copyWith(
                  fontSize: 10,
                  color:
                      selected ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      enabled: !disabled,
      scale: 0.92,
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected
              ? null
              : disabled
                  ? AppColors.surfaceElevated.withValues(alpha: 0.5)
                  : AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : disabled
                    ? AppColors.border.withValues(alpha: 0.5)
                    : AppColors.border,
          ),
          boxShadow:
              selected ? AppShadows.primaryGlow(AppColors.primary) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : disabled
                    ? AppColors.textMuted.withValues(alpha: 0.5)
                    : AppColors.textBright,
            decoration: disabled && !selected
                ? TextDecoration.lineThrough
                : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _SlotSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.2,
      ),
      itemCount: 8,
      itemBuilder: (context, _) =>
          const SkeletonRect(height: 40, radius: AppRadius.md),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      AppSpacing.hGapSm,
      Text(label, style: AppText.bodySm),
      const Spacer(),
      Text(
        value,
        style: AppText.body.copyWith(
          color: AppColors.textBright,
          fontWeight: FontWeight.w600,
        ),
      ),
    ]);
  }
}

class _SelectedSummaryStrip extends StatelessWidget {
  const _SelectedSummaryStrip({
    required this.count,
    required this.totalPrice,
    required this.currency,
    required this.fmt,
  });
  final int count;
  final int totalPrice;
  final String currency;
  final String Function(int) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle,
            color: AppColors.primary, size: 18),
        AppSpacing.hGapSm,
        Expanded(
          child: Text(
            '$count ta xizmat tanlandi',
            style: AppText.bodySm.copyWith(color: AppColors.primary),
          ),
        ),
        Text(
          "${fmt(totalPrice)} $currency",
          style: AppText.body.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  const _StickyActionBar({
    required this.step,
    required this.canProceed,
    required this.submitting,
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
    required this.nextIcon,
  });
  final int step;
  final bool canProceed;
  final bool submitting;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final IconData nextIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.elevated,
      ),
      child: Row(children: [
        if (onBack != null) ...[
          Expanded(
            child: AppButton(
              label: 'Orqaga',
              leadingIcon: Icons.arrow_back,
              variant: AppButtonVariant.secondary,
              onPressed: onBack,
              fullWidth: true,
            ),
          ),
          AppSpacing.hGapMd,
        ],
        Expanded(
          flex: onBack == null ? 1 : 1,
          child: AppButton(
            label: nextLabel,
            trailingIcon: submitting ? null : nextIcon,
            variant: AppButtonVariant.primary,
            size: AppButtonSize.lg,
            loading: submitting,
            fullWidth: true,
            onPressed: canProceed && !submitting ? onNext : null,
          ),
        ),
      ]),
    );
  }
}

// ═════════════════════════ Success view ═════════════════════════

class _ConfirmedView extends ConsumerWidget {
  const _ConfirmedView({
    required this.barber,
    required this.date,
    required this.time,
    required this.prettyDate,
  });
  final Barber barber;
  final DateTime date;
  final String time;
  final String Function(DateTime) prettyDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(children: [
        AppSpacing.gapXl,
        // Success animation
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.check,
                color: Colors.white, size: 42),
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.4, 0.4),
              duration: 500.ms,
              curve: Curves.easeOutBack,
            )
            .then()
            .shake(hz: 2, curve: Curves.easeInOut, duration: 300.ms),
        AppSpacing.gapLg,
        Text(
          tr(ref, 'booking.bookingConfirmed', 'Bron tasdiqlandi'),
          style: AppText.titleLg,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          tr(ref, 'booking.barberAwaits', '{{name}} sizni kutadi',
              {'name': barber.name}),
          style: AppText.bodyLg.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXl,
        // Booking summary card
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppSpacing.cardPaddingLg,
          child: Column(children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(Icons.calendar_today,
                    color: AppColors.primary),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prettyDate(date),
                      style: AppText.titleSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'soat $time',
                      style: AppText.bodySm,
                    ),
                  ],
                ),
              ),
            ]),
          ]),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 300.ms)
            .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 300.ms),
        AppSpacing.gapXl,
        AppButton(
          label: tr(ref, 'booking.myBookings', 'Mening bronlarim'),
          leadingIcon: Icons.list_alt,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.go('/home'),
        )
            .animate()
            .fadeIn(duration: 300.ms, delay: 500.ms)
            .slideY(begin: 0.2, end: 0, duration: 300.ms, delay: 500.ms),
      ]),
    );
  }
}

// ═════════════════════════ Providers ═════════════════════════

final daySlotsProvider = FutureProvider.family<List<String>,
    ({String barberId, String date})>(
  (ref, key) async {
    final dio = ref.watch(barberRepositoryProvider);
    return dio.scheduleSlots(barberId: key.barberId, date: key.date);
  },
);

final bookedTimesProvider = FutureProvider.family<List<String>,
    ({String barberId, String date})>(
  (ref, key) async {
    final repo = ref.watch(barberRepositoryProvider);
    return repo.bookedTimes(barberId: key.barberId, date: key.date);
  },
);
