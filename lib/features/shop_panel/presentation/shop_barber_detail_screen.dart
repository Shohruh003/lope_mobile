import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../barber_panel/data/barber_panel_repository.dart';
import '../../bookings/data/booking_repository.dart';
import '../data/shop_repository.dart';
import 'shop_bookings_screen.dart' show shopBookingsFilteredProvider;

class ShopBarberDetailScreen extends ConsumerStatefulWidget {
  const ShopBarberDetailScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<ShopBarberDetailScreen> createState() =>
      _ShopBarberDetailScreenState();
}

class _ShopBarberDetailScreenState
    extends ConsumerState<ShopBarberDetailScreen> {
  int _tab = 0;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await AppDatePicker.show(
      context,
      ref: ref,
      initial: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _call(String phone) async {
    AppHaptics.light();
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: clean);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final barberAsync = ref.watch(_shopBarberByIdProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'mobile.shop.barberDetail.title', "Sartarosh"),
            style: AppText.titleMd),
      ),
      body: barberAsync.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          final phone = (b.phone ?? '');
          final showPhone = phone.isNotEmpty && !phone.startsWith('shop:');
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(_shopBarberByIdProvider(widget.barberId));
              ref.invalidate(_shopBarberBookingsProvider(
                  (id: widget.barberId, date: _dateStr(_date))));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [
                _BarberHero(
                  name: b.name,
                  experience: b.experience,
                  avatar: b.avatar ?? '',
                  phone: showPhone ? phone : null,
                  onCall: showPhone ? () => _call(phone) : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: AppRadius.rMd,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    _TabBtn(
                      label: tr(ref, 'mobile.barber.schedule.title', "Jadval"),
                      on: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _TabBtn(
                      label: tr(ref, 'shop.nav.clients', "Mijozlar"),
                      on: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_tab == 0)
                  _ScheduleTab(
                    barberId: widget.barberId,
                    date: _date,
                    onPickDate: _pickDate,
                  )
                else
                  _ClientsTab(barberId: widget.barberId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BarberHero extends StatelessWidget {
  const _BarberHero({
    required this.name,
    required this.experience,
    required this.avatar,
    required this.phone,
    required this.onCall,
  });
  final String name;
  final String experience;
  final String avatar;
  final String? phone;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.14),
          AppColors.primary.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: assetUrl(avatar),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover)
                : Container(
                    width: 64,
                    height: 64,
                    color: context.colors.surface,
                    alignment: Alignment.center,
                    child: Text(
                      (name.isNotEmpty ? name[0] : '?').toUpperCase(),
                      style: AppText.titleLg
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.titleMd),
              if (experience.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(experience, style: AppText.bodySm),
              ],
              if (phone != null && phone!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                TapScale(
                  onTap: onCall,
                  haptic: HapticStrength.light,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(phone!,
                          style: AppText.button.copyWith(
                              color: AppColors.primary, fontSize: 12)),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TapScale(
        onTap: onTap,
        haptic: HapticStrength.selection,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            gradient: on
                ? LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: AppRadius.rSm,
            border: on
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: AppText.button.copyWith(
                  color: on ? AppColors.primary : context.colors.textMuted,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab(
      {required this.barberId, required this.date, required this.onPickDate});
  final String barberId;
  final DateTime date;
  final VoidCallback onPickDate;
  static final _df = DateFormat('dd.MM.yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final async =
        ref.watch(_shopBarberBookingsProvider((id: barberId, date: dateStr)));
    final slotsAsync =
        ref.watch(scheduleSlotsProvider((barberId: barberId, date: dateStr)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Same pattern as the web BarbershopBarberDetail: just the
        // date picker at the top. No separate 'Mijoz qo'shish' button —
        // admins tap an empty slot in the grid to add a client at that
        // specific time.
        TapScale(
          onTap: onPickDate,
          haptic: HapticStrength.light,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.rMd,
              border: Border.all(color: context.colors.border),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.rSm,
                ),
                child: const Icon(Icons.calendar_today,
                    size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(_df.format(date),
                  style: AppText.titleSm.copyWith(fontSize: 14)),
              const Spacer(),
              Icon(Icons.chevron_right,
                  color: context.colors.textMuted, size: 18),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Slot grid — mirrors the barber's own schedule view and the
        // web `Jadval` card. Empty slots tap through to the add-client
        // sheet with the time pre-filled; booked slots show the client
        // name and skip the add-client sheet.
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: AppErrorState(message: humanize(e)),
          ),
          data: (bookings) => slotsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (slots) {
              final active = bookings
                  .where((b) => b.status != 'cancelled')
                  .toList();
              // Booking start-time -> booking. Guarded against duplicate
              // times so the map holds the first booking's client name.
              final startAt = <String, ShopBooking>{};
              for (final b in active) {
                startAt.putIfAbsent(b.time, () => b);
              }
              final allTimes = <String>{...slots, ...startAt.keys}.toList()
                ..sort();
              if (allTimes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.event_available_rounded,
                  title: tr(ref, 'mobile.shop.bookings.emptyForDay',
                      "Bu sanada bronlar yo'q"),
                  message: tr(
                      ref,
                      'mobile.shop.barberDetail.noSchedule',
                      "Sartaroshning bu kunga jadvali yo'q. Master avval ish vaqtini belgilashi kerak."),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 1.75,
                    ),
                    itemCount: allTimes.length,
                    itemBuilder: (context, i) {
                      final t = allTimes[i];
                      final b = startAt[t];
                      return _ShopSlotTile(
                        time: t,
                        booking: b,
                        emptyLabel: tr(ref,
                            'mobile.shop.barberDetail.slotFree', "Bo'sh"),
                        onTap: b == null
                            ? () => _openAddClientSheet(
                                context, ref, dateStr,
                                prefillTime: t)
                            : null,
                      ).animate().fadeIn(
                          duration: 150.ms, delay: (i * 12).ms);
                    },
                  ),
                  if (active.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      tr(ref,
                          'mobile.shop.barberDetail.bookingsForDay',
                          "Bugungi bronlar ({{n}})",
                          {'n': '${active.length}'}),
                      style: AppText.titleSm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...(([...active]..sort(
                            (a, b) => a.time.compareTo(b.time)))
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm),
                              child: _BookingRow(
                                      b: e.value, dateStr: dateStr)
                                  .animate()
                                  .fadeIn(
                                      duration: 200.ms,
                                      delay: (e.key * 25).ms),
                            ))),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Manual booking sheet — barbershop admin schedules a client on
  /// the currently-viewed barber's slot. Ports the barber panel's
  /// `_openManualBookingDialog` so both roles get the same UX.
  /// `prefillTime` is passed when the user tapped a specific empty slot
  /// in the grid; when null the sheet starts with the time picker
  /// unset so the admin can pick any time manually.
  Future<void> _openAddClientSheet(
      BuildContext context, WidgetRef ref, String dateStr,
      {String? prefillTime}) async {
    AppHaptics.selection();
    final services = await ref
        .read(barberPanelRepositoryProvider)
        .servicesForBarber(barberId);
    if (!context.mounted) return;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final selected = <String>{};
    TimeOfDay? pickedTime;
    if (prefillTime != null && prefillTime.contains(':')) {
      final parts = prefillTime.split(':');
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        pickedTime = TimeOfDay(hour: h, minute: m);
      }
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.lg,
            bottom: AppSpacing.xl +
                MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  tr(ref, 'mobile.shop.barberDetail.addClientTitle',
                      "Mijoz qo'shish"),
                  style: AppText.titleMd,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: tr(ref, 'shop.client.name', "Ism"),
                    hintText: tr(ref, 'shop.client.nameHint',
                        "Familya Ism"),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppPhoneField(
                  controller: phoneCtrl,
                  hintText: '+998 XX-XXX-XX-XX',
                ),
                const SizedBox(height: AppSpacing.md),
                // Time picker pill
                TapScale(
                  onTap: () async {
                    final t = await AppTimePicker.show(sheetCtx,
                        ref: ref,
                        initial: pickedTime ??
                            const TimeOfDay(hour: 10, minute: 0));
                    if (t == null) return;
                    setSheet(() => pickedTime = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(children: [
                      const Icon(Icons.access_time,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        pickedTime == null
                            ? tr(ref,
                                'mobile.shop.barberDetail.pickTime',
                                'Vaqtni tanlang')
                            : '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}',
                        style: AppText.titleSm
                            .copyWith(fontSize: 14),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          color: context.colors.textMuted, size: 18),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (services.isEmpty)
                  Text(
                    tr(ref,
                        'mobile.shop.barberDetail.noServices',
                        "Bu master uchun xizmatlar belgilanmagan"),
                    style: AppText.caption,
                  )
                else ...[
                  Text(
                    tr(ref, 'booking.service', 'Xizmat'),
                    style: AppText.overline.copyWith(
                        color: context.colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: services.map((s) {
                      final id = (s['id'] ?? '').toString();
                      final selected0 = selected.contains(id);
                      final name =
                          (s['nameUz'] ?? s['name'] ?? '').toString();
                      final price = ((s['price'] ?? 0) as num).toInt();
                      return AppChip(
                        label: price > 0
                            ? '$name · $price'
                            : name,
                        selected: selected0,
                        onTap: () => setSheet(() {
                          if (selected0) {
                            selected.remove(id);
                          } else {
                            selected.add(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: tr(ref, 'common.save', 'Saqlash'),
                  variant: AppButtonVariant.primary,
                  fullWidth: true,
                  onPressed: () => Navigator.of(sheetCtx).pop(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }
    if (pickedTime == null) {
      if (context.mounted) {
        AppSnack.warning(
            context,
            tr(ref, 'mobile.shop.barberDetail.needTime',
                'Vaqtni tanlang'));
      }
      nameCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }
    final timeStr =
        '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}';
    try {
      final picked = services.where((s) {
        final id = (s['id'] ?? '').toString();
        return selected.contains(id);
      }).toList();
      final fullServices = picked
          .map((s) => {
                'id': s['id'],
                'name': (s['nameUz'] ?? s['name'] ?? '').toString(),
                'nameUz':
                    (s['nameUz'] ?? s['name'] ?? '').toString(),
                'nameRu': (s['nameRu'] ?? '').toString(),
                'price': ((s['price'] ?? 0) as num).toInt(),
                'duration': ((s['duration'] ?? 30) as num).toInt(),
                'icon': (s['icon'] ?? '').toString(),
              })
          .toList();
      final totalPrice = picked.fold<int>(
          0, (a, s) => a + ((s['price'] ?? 0) as num).toInt());
      final totalDuration = picked.fold<int>(
          0, (a, s) => a + ((s['duration'] ?? 30) as num).toInt());
      await ref.read(barberPanelRepositoryProvider).createManual(
            barberId: barberId,
            date: dateStr,
            time: timeStr,
            services: fullServices,
            totalPrice: totalPrice,
            totalDuration: totalDuration,
            guestName: nameCtrl.text.trim(),
            guestPhone: AppPhoneField.rawPhone(phoneCtrl.text),
          );
      // Refresh the schedule list so the new booking appears.
      ref.invalidate(
          _shopBarberBookingsProvider((id: barberId, date: dateStr)));
      ref.invalidate(shopBookingsFilteredProvider);
      if (context.mounted) {
        AppSnack.success(
            context,
            tr(ref, 'mobile.shop.barberDetail.clientAdded',
                "Mijoz qo'shildi"));
      }
    } catch (e) {
      if (context.mounted) AppSnack.error(context, humanize(e));
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }
}

class _BookingRow extends ConsumerWidget {
  const _BookingRow({required this.b, required this.dateStr});
  final ShopBooking b;
  final String dateStr;

  String _statusLabel(WidgetRef ref) {
    switch (b.status) {
      case 'completed':
        return tr(ref, 'myBookings.statusCompleted', 'Yakunlangan');
      case 'cancelled':
        return tr(ref, 'profile.cancelled', 'Bekor');
      default:
        return tr(ref, 'myBookings.statusConfirmed', 'Tasdiqlangan');
    }
  }

  Color _statusColor() {
    switch (b.status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  AppBadgeVariant _statusVariant() {
    switch (b.status) {
      case 'completed':
        return AppBadgeVariant.success;
      case 'cancelled':
        return AppBadgeVariant.danger;
      default:
        return AppBadgeVariant.info;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColor();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.rMd,
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(children: [
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.rSm,
          ),
          alignment: Alignment.center,
          child: Text(b.time,
              style: AppText.button.copyWith(color: color, fontSize: 14)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.userName,
                  style: AppText.titleSm.copyWith(fontSize: 14)),
              const SizedBox(height: 4),
              Row(children: [
                AppBadge(label: _statusLabel(ref), variant: _statusVariant()),
                if (b.totalPrice > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                      "${_fmt(b.totalPrice)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.button.copyWith(
                          color: AppColors.warning, fontSize: 12)),
                ],
              ]),
            ],
          ),
        ),
        if (b.status == 'confirmed' && b.id.isNotEmpty)
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: context.colors.textMuted, size: 20),
            color: context.colors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            onSelected: (value) async {
              switch (value) {
                case 'reschedule':
                  await _reschedule(context, ref);
                  break;
                case 'extend':
                  await _extend(context, ref);
                  break;
                case 'cancel':
                  await _cancel(context, ref);
                  break;
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
              PopupMenuItem(
                value: 'cancel',
                child: Row(children: [
                  const Icon(Icons.close,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Text(tr(ref, 'myBookings.cancel', "Bekor qilish"),
                      style: const TextStyle(color: AppColors.danger)),
                ]),
              ),
            ],
          ),
      ]),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(
            tr(ref, 'myBookings.cancelConfirmTitle',
                "Bronni bekor qilasizmi?"),
            style: AppText.titleMd),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dCtx, true),
            child: Text(tr(ref, 'myBookings.cancel', "Bekor qilish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bookingRepositoryProvider).cancel(b.id);
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final initial = DateTime.tryParse(dateStr) ?? DateTime.now();
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
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
    }
  }

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    int minutes = 30;
    final ok = await showDialog<int>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: context.colors.surface,
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
      ref.invalidate(_shopBarberBookingsProvider);
      ref.invalidate(shopBookingsFilteredProvider);
    } catch (e) {
      if (!context.mounted) return;
      AppSnack.error(context, humanize(e));
    }
  }
}

class _ClientsTab extends ConsumerWidget {
  const _ClientsTab({required this.barberId});
  final String barberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shopBarberClientsProvider(barberId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: AppErrorState(message: humanize(e)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return AppEmptyState(
            icon: Icons.people_outline_rounded,
            title: tr(ref, 'mobile.shop.barberDetail.noClients',
                "Mijozlar topilmadi"),
          );
        }
        return Column(
          children: list
              .asMap()
              .entries
              .map((e) => Padding(
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
                                AppColors.primary.withValues(alpha: 0.25),
                                AppColors.primary.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: AppRadius.rMd,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            ((e.value['name'] ?? '?').toString().isNotEmpty
                                    ? (e.value['name'] as String)[0]
                                    : '?')
                                .toUpperCase(),
                            style: AppText.titleSm
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  (e.value['name'] ?? '').toString().isEmpty
                                      ? (e.value['phone'] ?? '').toString()
                                      : (e.value['name'] ?? '').toString(),
                                  style: AppText.titleSm
                                      .copyWith(fontSize: 14)),
                              if ((e.value['phone'] ?? '').toString().isNotEmpty)
                                Text((e.value['phone'] ?? '').toString(),
                                    style: AppText.caption),
                            ],
                          ),
                        ),
                        if (((e.value['totalVisits'] ?? e.value['bookingsCount'] ?? 0) as num) > 0)
                          AppBadge(
                            label:
                                "${((e.value['totalVisits'] ?? e.value['bookingsCount'] ?? 0) as num).toInt()}",
                            variant: AppBadgeVariant.success,
                          ),
                      ]),
                    ).animate().fadeIn(duration: 200.ms, delay: (e.key * 25).ms),
                  ))
              .toList(),
        );
      },
    );
  }
}

final _shopBarberByIdProvider =
    FutureProvider.family<ShopBarber, String>((ref, id) async {
  return ref.watch(shopRepositoryProvider).getBarber(id);
});

typedef _BookingsKey = ({String id, String date});

final _shopBarberBookingsProvider =
    FutureProvider.family<List<ShopBooking>, _BookingsKey>((ref, k) async {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.bookings(barberId: k.id, date: k.date, limit: 100);
});

final _shopBarberClientsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final repo = ref.watch(shopRepositoryProvider);
  return repo.barberClients(id);
});

/// Single slot tile in the shop-side schedule grid. Mirrors the web
/// BarbershopBarberDetail card: booked slots pick up primary tint and
/// show the client name inline; empty slots are neutral (surface +
/// border) and tap-through to add a client at that time.
class _ShopSlotTile extends StatelessWidget {
  const _ShopSlotTile({
    required this.time,
    required this.booking,
    required this.emptyLabel,
    required this.onTap,
  });
  final String time;
  final ShopBooking? booking;
  final String emptyLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final booked = booking != null;
    final tile = Container(
      decoration: BoxDecoration(
        color: booked
            ? AppColors.primary.withValues(alpha: 0.10)
            : context.colors.surface,
        borderRadius: AppRadius.rMd,
        border: Border.all(
          color: booked
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.colors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: booked
                  ? AppColors.primary
                  : context.colors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            booked
                ? (booking!.userName.isNotEmpty
                    ? booking!.userName
                    : ((booking!.userPhone ?? '').isNotEmpty
                        ? booking!.userPhone!
                        : 'Mijoz'))
                : emptyLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(
              color: booked
                  ? AppColors.primary
                  : context.colors.textMuted,
              fontWeight: booked ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return TapScale(
      onTap: onTap!,
      haptic: HapticStrength.selection,
      scale: 0.96,
      child: tile,
    );
  }
}
