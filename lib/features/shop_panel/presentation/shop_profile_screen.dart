import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/location_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/shop_repository.dart';

class ShopProfileScreen extends ConsumerStatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  ConsumerState<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends ConsumerState<ShopProfileScreen> {
  static const _dayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _geoAddressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _reminderDaysCtrl = TextEditingController(text: '20');
  final _reminderHoursCtrl = TextEditingController(text: '1');
  final _slotDurationCtrl = TextEditingController(text: '30');
  final _mapController = MapController();

  /// Toshkent center — used when the salon has no coordinates yet.
  static final _defaultCenter = ll.LatLng(41.311081, 69.240562);

  /// Pushed on every map idle (pan / zoom end) — writes the picked
  /// centre back into the lat/lng text fields so the barber sees the
  /// numbers change live as they drag the map.
  void _syncCoordsFromMap() {
    final c = _mapController.camera.center;
    _latCtrl.text = c.latitude.toStringAsFixed(6);
    _lngCtrl.text = c.longitude.toStringAsFixed(6);
  }

  late List<_DayHours> _hours;
  bool _seeded = false;
  bool _saving = false;

  /// Snapshot of the seeded form values. `_isDirty` compares against
  /// this so the Save button starts disabled and only enables once the
  /// admin actually edits something.
  Map<String, String> _snapshot = const {};
  List<_DayHours> _hoursSnapshot = const [];

  List<TextEditingController> get _controllers => [
        _nameCtrl,
        _phoneCtrl,
        _addressCtrl,
        _geoAddressCtrl,
        _latCtrl,
        _lngCtrl,
        _reminderDaysCtrl,
        _reminderHoursCtrl,
        _slotDurationCtrl,
      ];

  @override
  void initState() {
    super.initState();
    _hours = List.generate(
      7,
      (i) => _DayHours(
        day: _dayKeys[i],
        isOpen: i < 6,
        open: i == 5 ? '10:00' : '09:00',
        close: i == 5 ? '17:00' : '19:00',
      ),
    );
    for (final c in _controllers) {
      c.addListener(_bump);
    }
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  bool get _isDirty {
    if (_snapshot.isEmpty) return false;
    if (_snapshot['name'] != _nameCtrl.text) return true;
    if (_snapshot['phone'] != _phoneCtrl.text) return true;
    if (_snapshot['address'] != _addressCtrl.text) return true;
    if (_snapshot['geoAddress'] != _geoAddressCtrl.text) return true;
    if (_snapshot['lat'] != _latCtrl.text) return true;
    if (_snapshot['lng'] != _lngCtrl.text) return true;
    if (_snapshot['reminderDays'] != _reminderDaysCtrl.text) return true;
    if (_snapshot['reminderHours'] != _reminderHoursCtrl.text) return true;
    if (_snapshot['slotDuration'] != _slotDurationCtrl.text) return true;
    for (var i = 0; i < _hours.length; i++) {
      final a = _hours[i];
      final b = _hoursSnapshot[i];
      if (a.isOpen != b.isOpen ||
          a.open != b.open ||
          a.close != b.close) {
        return true;
      }
    }
    return false;
  }

  void _rebuildSnapshot() {
    _snapshot = {
      'name': _nameCtrl.text,
      'phone': _phoneCtrl.text,
      'address': _addressCtrl.text,
      'geoAddress': _geoAddressCtrl.text,
      'lat': _latCtrl.text,
      'lng': _lngCtrl.text,
      'reminderDays': _reminderDaysCtrl.text,
      'reminderHours': _reminderHoursCtrl.text,
      'slotDuration': _slotDurationCtrl.text,
    };
    _hoursSnapshot = _hours
        .map((h) => _DayHours(
              day: h.day,
              isOpen: h.isOpen,
              open: h.open,
              close: h.close,
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.removeListener(_bump);
    }
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _geoAddressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _reminderDaysCtrl.dispose();
    _reminderHoursCtrl.dispose();
    _slotDurationCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int i, bool isStart) async {
    final current = isStart ? _hours[i].open : _hours[i].close;
    final parts = current.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked =
        await AppTimePicker.show(context, ref: ref, initial: initial);
    if (picked == null) return;
    setState(() {
      final s =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _hours[i] = _hours[i].copyWith(
          open: isStart ? s : _hours[i].open,
          close: isStart ? _hours[i].close : s);
    });
  }

  Future<void> _save() async {
    final reminderDays = int.tryParse(_reminderDaysCtrl.text.trim()) ?? 20;
    final reminderHours = int.tryParse(_reminderHoursCtrl.text.trim()) ?? 1;
    final slotDuration = int.tryParse(_slotDurationCtrl.text.trim()) ?? 30;

    if (reminderDays < 1 || reminderDays > 365) {
      if (!mounted) return;
      AppSnack.warning(
          context,
          tr(ref, 'mobile.shop.profile.invalidReminder',
              "Eslatma kunlari 1-365 oraliqda bo'lsin"));
      return;
    }
    if (slotDuration < 5 || slotDuration > 240) {
      if (!mounted) return;
      AppSnack.warning(
          context,
          tr(ref, 'mobile.shop.profile.invalidSlot',
              "Slot 5-240 daqiqa oraliqda bo'lsin"));
      return;
    }

    setState(() => _saving = true);
    try {
      final workingHours = <String, dynamic>{};
      for (final h in _hours) {
        workingHours[h.day] = {
          'isOpen': h.isOpen,
          'open': h.open,
          'close': h.close,
        };
      }
      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      await ref.read(shopRepositoryProvider).updateMe({
        'name': _nameCtrl.text.trim(),
        'phone': AppPhoneField.rawPhone(_phoneCtrl.text),
        'address': _addressCtrl.text.trim(),
        'geoAddress': _geoAddressCtrl.text.trim(),
        'latitude': ?lat,
        'longitude': ?lng,
        'reminderDays': reminderDays,
        'reminderHoursBefore': reminderHours,
        'slotDuration': slotDuration,
        'workingHours': workingHours,
      });
      ref.invalidate(shopMeProvider);
      // Reset the baseline so the Save button flips back to disabled
      // until the next edit.
      _rebuildSnapshot();
      if (mounted) {
        AppHaptics.success();
        AppSnack.success(context, tr(ref, 'common.saved', 'Saqlandi'));
      }
    } catch (e) {
      if (mounted) {
        AppHaptics.error();
        AppSnack.error(context, humanize(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _seed(Map<String, dynamic> m) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = (m['name'] ?? '').toString();
    _phoneCtrl.text = (m['phone'] ?? '').toString();
    _addressCtrl.text = (m['address'] ?? m['location'] ?? '').toString();
    _geoAddressCtrl.text = (m['geoAddress'] ?? '').toString();
    final lat = m['latitude'];
    final lng = m['longitude'];
    if (lat is num) _latCtrl.text = lat.toString();
    if (lng is num) _lngCtrl.text = lng.toString();
    _reminderDaysCtrl.text =
        ((m['reminderDays'] ?? 20) as num).toInt().toString();
    _reminderHoursCtrl.text =
        ((m['reminderHoursBefore'] ?? 1) as num).toInt().toString();
    _slotDurationCtrl.text =
        ((m['slotDuration'] ?? 30) as num).toInt().toString();
    final wh = m['workingHours'];
    if (wh is Map) {
      for (var i = 0; i < _dayKeys.length; i++) {
        final v = wh[_dayKeys[i]];
        if (v is Map) {
          _hours[i] = _DayHours(
            day: _dayKeys[i],
            isOpen: v['isOpen'] == true,
            open: (v['open'] ?? '09:00').toString(),
            close: (v['close'] ?? '19:00').toString(),
          );
        }
      }
    }
    // Baseline the dirty tracker — Save stays disabled until the
    // admin edits something.
    _rebuildSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopMeProvider);
    final dayShorts = trList(ref, 'mobile.dates.weekDaysShort',
        const ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya']);
    return Scaffold(
      appBar: AppBar(
          title: Text(
              tr(ref, 'mobile.shop.settings.salonProfile', "Salon profili"),
              style: AppText.titleMd)),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (m) {
          _seed(m);
          return ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
            children: [
              _SectionHeader(
                icon: Icons.store,
                title: tr(ref, 'mobile.shop.profile.basicInfo',
                    "Asosiy ma'lumotlar"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(tr(ref, 'mobile.shop.profile.salonName', "Salon nomi")),
                    const SizedBox(height: 6),
                    TextField(controller: _nameCtrl),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'auth.phone', "Telefon")),
                    const SizedBox(height: 6),
                    AppPhoneField(controller: _phoneCtrl),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'profile.location', "Manzil")),
                    const SizedBox(height: 6),
                    TextField(controller: _addressCtrl),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.geoAddress',
                        "Geo manzil (xaritada)")),
                    const SizedBox(height: 6),
                    TextField(controller: _geoAddressCtrl),
                    const SizedBox(height: AppSpacing.md),
                    // Embedded interactive map — admin pans / zooms
                    // the map to place the pin over the salon; every
                    // idle syncs the coordinates back into the
                    // (hidden) _latCtrl / _lngCtrl so the save path
                    // can send them. The lat/lng number fields and
                    // 'Yandex'da topish' external launcher were
                    // removed at user's request — the map is the
                    // single source of truth for location now.
                    _ShopLocationPickerMap(
                      controller: _mapController,
                      initial: () {
                        final lat =
                            double.tryParse(_latCtrl.text.trim());
                        final lng =
                            double.tryParse(_lngCtrl.text.trim());
                        if (lat != null && lng != null) {
                          return ll.LatLng(lat, lng);
                        }
                        return _defaultCenter;
                      }(),
                      onIdle: _syncCoordsFromMap,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.access_time,
                title: tr(ref, 'profile.workingHours', "Ish soatlari"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hours[i].isOpen
                                ? AppColors.primary.withValues(alpha: 0.04)
                                : context.colors.background,
                            borderRadius: AppRadius.rSm,
                            border: Border.all(
                                color: _hours[i].isOpen
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : context.colors.border),
                          ),
                          child: Row(children: [
                            SizedBox(
                              width: 32,
                              child: Text(dayShorts[i],
                                  style: AppText.button.copyWith(
                                      color: _hours[i].isOpen
                                          ? context.colors.textBright
                                          : context.colors.textMuted,
                                      fontSize: 13)),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Row(children: [
                                _TimePill(
                                    label: _hours[i].open,
                                    enabled: _hours[i].isOpen,
                                    onTap: () => _pickTime(i, true)),
                                const SizedBox(width: 6),
                                Text('—',
                                    style: TextStyle(
                                        color: context.colors.textMuted)),
                                const SizedBox(width: 6),
                                _TimePill(
                                    label: _hours[i].close,
                                    enabled: _hours[i].isOpen,
                                    onTap: () => _pickTime(i, false)),
                              ]),
                            ),
                            Switch(
                              value: _hours[i].isOpen,
                              activeThumbColor: AppColors.primary,
                              onChanged: (v) {
                                AppHaptics.selection();
                                setState(() =>
                                    _hours[i] = _hours[i].copyWith(isOpen: v));
                              },
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              _SectionHeader(
                icon: Icons.settings,
                title: tr(ref, 'mobile.shop.profile.settings', "Sozlamalar"),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                variant: AppCardVariant.flat,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(tr(ref, 'mobile.shop.profile.reminderDays',
                        "Eslatma kunlari (oxirgi tashrifdan)")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reminderDaysCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'kun'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.reminderHours',
                        "Bron oldidan eslatma (soat)")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reminderHoursCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'soat'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Label(tr(ref, 'mobile.shop.profile.slotDuration',
                        "Slot davomiyligi")),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _slotDurationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      decoration: const InputDecoration(suffixText: 'daq'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: tr(ref, 'common.save', "Saqlash"),
                onPressed:
                    (_saving || !_isDirty) ? null : _save,
                loading: _saving,
                leadingIcon: Icons.check,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayHours {
  const _DayHours({
    required this.day,
    required this.isOpen,
    required this.open,
    required this.close,
  });
  final String day;
  final bool isOpen;
  final String open;
  final String close;
  _DayHours copyWith({bool? isOpen, String? open, String? close}) =>
      _DayHours(
        day: day,
        isOpen: isOpen ?? this.isOpen,
        open: open ?? this.open,
        close: close ?? this.close,
      );
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
      Text(title.toUpperCase(),
          style: AppText.overline
              .copyWith(color: AppColors.primary, letterSpacing: 1)),
    ]);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500));
}

class _TimePill extends StatelessWidget {
  const _TimePill(
      {required this.label, required this.enabled, required this.onTap});
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: enabled ? onTap : null,
      haptic: HapticStrength.light,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.colors.surface,
          borderRadius: AppRadius.rSm,
          border: Border.all(
              color: enabled
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : context.colors.border),
        ),
        child: Text(label,
            style: AppText.button.copyWith(
                color: enabled ? AppColors.primary : context.colors.textMuted)),
      ),
    );
  }
}

/// Embedded flutter_map with a fixed centre pin. The admin pans / zooms
/// to place the pin over the salon; every idle triggers [onIdle] so the
/// parent state can sync lat/lng back into the text fields. Same shape
/// / tile provider as the barber location picker. A "my location" FAB
/// in the bottom-right recentres the map on the device's GPS position
/// (permission prompt + AppSnack fallback on denial).
class _ShopLocationPickerMap extends ConsumerStatefulWidget {
  const _ShopLocationPickerMap({
    required this.controller,
    required this.initial,
    required this.onIdle,
  });

  final MapController controller;
  final ll.LatLng initial;
  final VoidCallback onIdle;

  @override
  ConsumerState<_ShopLocationPickerMap> createState() =>
      _ShopLocationPickerMapState();
}

class _ShopLocationPickerMapState
    extends ConsumerState<_ShopLocationPickerMap> {
  bool _locating = false;

  Future<void> _locateMe() async {
    if (_locating) return;
    AppHaptics.selection();
    setState(() => _locating = true);
    final pos = await ref.read(locationServiceProvider).currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos == null) {
      AppSnack.warning(
          context,
          tr(ref, 'mobile.shop.profile.locationDenied',
              "Joylashuvni aniqlab bo'lmadi. Ilova sozlamalarida ruxsat bering."));
      return;
    }
    widget.controller.move(ll.LatLng(pos.lat, pos.lng), 16);
    widget.onIdle();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: AppRadius.rLg,
        border: Border.all(color: context.colors.border),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Stack(children: [
          FlutterMap(
            mapController: widget.controller,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) widget.onIdle();
              },
              onTap: (tap, latlng) {
                widget.controller
                    .move(latlng, widget.controller.camera.zoom);
                widget.onIdle();
              },
            ),
            children: [
              // OSM tiles for parity with barber_location — Stadia
              // rendered fine over debug wifi but silently failed on
              // real Android devices (240px map area went blank).
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'uz.lopestyle.mobile',
                maxNativeZoom: 19,
                maxZoom: 20,
                tileBuilder: isDark
                    ? (context, child, tile) => ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            0.6, 0.3, 0.1, 0, 0,
                            0.3, 0.6, 0.1, 0, 0,
                            0.3, 0.3, 0.4, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                          child: child,
                        )
                    : null,
              ),
            ],
          ),
          const IgnorePointer(
            ignoring: true,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Icon(Icons.location_on,
                    color: AppColors.primary, size: 40),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: AppRadius.rPill,
              ),
              child: Text(
                tr(ref, 'mobile.shop.profile.dragHint',
                    'Xaritani surib joyni belgilang'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _locateMe,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: _locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.primary),
                            ),
                          )
                        : const Icon(Icons.my_location,
                            color: AppColors.primary, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
