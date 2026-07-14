import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/barber_profile_repository.dart';

class BarberLocationScreen extends ConsumerStatefulWidget {
  const BarberLocationScreen({super.key});
  @override
  ConsumerState<BarberLocationScreen> createState() =>
      _BarberLocationScreenState();
}

class _BarberLocationScreenState
    extends ConsumerState<BarberLocationScreen> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mapController = MapController();

  bool _seeded = false;
  bool _editing = false;
  bool _saving = false;

  /// Toshkent center — used as the initial map view when the barber
  /// has never set coordinates before. Approx Chorsu.
  static final _defaultCenter =
      ll.LatLng(41.311081, 69.240562);

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _addressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Pulled every time the map settles on a new position — writes the
  /// new lat/lng back into the text controllers so the barber can
  /// see the exact numbers change as they pan / zoom.
  void _syncCoordsFromMap() {
    final c = _mapController.camera.center;
    _latCtrl.text = c.latitude.toStringAsFixed(6);
    _lngCtrl.text = c.longitude.toStringAsFixed(6);
  }

  Future<void> _save(String barberId) async {
    AppHaptics.medium();
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      AppHaptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.invalidLatLng',
              "Kenglik / Uzunlik noto'g'ri"))));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .updateBarber(barberId, {
        'latitude': lat,
        'longitude': lng,
        'geoAddress': _addressCtrl.text.trim(),
      });
      ref.invalidate(barberProfileProvider(barberId));
      AppHaptics.success();
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'common.saved', 'Saqlandi'))));
      }
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyAddress(String text) async {
    AppHaptics.light();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'mobile.barber.location.copied',
              'Nusxalandi'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(barberProfileProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.location_on,
              color: AppColors.primary, size: 22),
          AppSpacing.hGapSm,
          Text(
            tr(ref, 'barberApp.myLocation', 'Manzilim'),
            style: AppText.titleMd,
          ),
        ]),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (b) {
          if (!_seeded) {
            _seeded = true;
            _latCtrl.text =
                (b['latitude'] ?? b['lat'] ?? '').toString();
            _lngCtrl.text =
                (b['longitude'] ?? b['lng'] ?? '').toString();
            _addressCtrl.text = (b['geoAddress'] ??
                    b['locationUz'] ??
                    b['location'] ??
                    '')
                .toString();
          }
          final hasLocation = _addressCtrl.text.isNotEmpty;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _seeded = false;
              // Force a re-fetch — ref.watch above will re-emit on the
              // new state so we don't need the returned future here.
              // ignore: unused_result
              ref.refresh(barberProfileProvider(user.id));
            },
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              if (_editing) ...[
                Text(
                  tr(ref, 'mobile.barber.location.editHint',
                      'Mijozlar sizni xaritada topa olishi uchun aniq manzil va koordinatalarni kiriting'),
                  style: AppText.bodyLg
                      .copyWith(color: context.colors.textSecondary),
                ),
                AppSpacing.gapLg,
                // Embedded interactive map — the barber pans the map,
                // the fixed center pin marks the picked spot, and the
                // lat/lng text fields update live. Replaces the old
                // flow that dumped users into Yandex Maps to copy
                // coordinates back by hand.
                _LocationPickerMap(
                  controller: _mapController,
                  initial: () {
                    final lat = double.tryParse(_latCtrl.text.trim());
                    final lng = double.tryParse(_lngCtrl.text.trim());
                    if (lat != null && lng != null) {
                      return ll.LatLng(lat, lng);
                    }
                    return _defaultCenter;
                  }(),
                  onIdle: _syncCoordsFromMap,
                ),
                AppSpacing.gapMd,
                AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr(ref, 'mobile.barber.location.addressLabel',
                            'Manzil matni'),
                        style: AppText.overline,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: tr(
                              ref,
                              'mobile.barber.location.addressPlaceholder',
                              "Toshkent, Yunusobod tumani, Amir Temur ko'chasi 7"),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapLg,
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.cancel', 'Bekor'),
                      variant: AppButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      fullWidth: true,
                    ),
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: AppButton(
                      label: tr(ref, 'common.save', 'Saqlash'),
                      variant: AppButtonVariant.primary,
                      loading: _saving,
                      onPressed: _saving ? null : () => _save(user.id),
                      fullWidth: true,
                    ),
                  ),
                ]),
              ] else ...[
                if (hasLocation)
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: AppSpacing.cardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.15),
                            borderRadius: AppRadius.rSm,
                          ),
                          child: const Icon(Icons.location_on,
                              color: AppColors.primary, size: 22),
                        ),
                        AppSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(_addressCtrl.text,
                                  style: AppText.body),
                              if (_latCtrl.text.isNotEmpty &&
                                  _lngCtrl.text.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_latCtrl.text}, ${_lngCtrl.text}',
                                  style: AppText.caption.copyWith(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppSpacing.hGapSm,
                        TapScale(
                          onTap: () =>
                              _copyAddress(_addressCtrl.text),
                          scale: 0.9,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceElevated,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.copy,
                                size: 14,
                                color: context.colors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AppEmptyState(
                    icon: Icons.location_off,
                    title: tr(ref, 'barbers.locationNotSet',
                        'Manzil belgilanmagan'),
                  ),
                AppSpacing.gapLg,
                AppButton(
                  label: hasLocation
                      ? tr(
                          ref,
                          'mobile.barber.location.changeBtn',
                          "Manzilni o'zgartirish")
                      : tr(
                          ref,
                          'mobile.barber.location.setBtn',
                          'Manzilni belgilash'),
                  leadingIcon: Icons.location_on,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => setState(() => _editing = true),
                ),
              ],
            ],
          ),
          );
        },
      ),
    );
  }
}

/// Embedded flutter_map card with a fixed center pin. The barber pans
/// / zooms the map to place the pin over their shop; on every idle
/// (drag end / zoom end) [onIdle] fires and the parent syncs the new
/// centre into the lat/lng text fields.
///
/// Uses the same Stadia Alidade Smooth tiles as the customer map so
/// the two features look like the same product.
class _LocationPickerMap extends StatelessWidget {
  const _LocationPickerMap({
    required this.controller,
    required this.initial,
    required this.onIdle,
  });

  final MapController controller;
  final ll.LatLng initial;
  final VoidCallback onIdle;

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
            mapController: controller,
            options: MapOptions(
              initialCenter: initial,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) onIdle();
              },
              onTap: (tap, latlng) {
                controller.move(latlng, controller.camera.zoom);
                onIdle();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
                    : 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png',
                additionalOptions: const {'r': ''},
                userAgentPackageName: 'uz.lopestyle.mobile',
                maxZoom: 20,
                retinaMode:
                    MediaQuery.of(context).devicePixelRatio > 1.5,
              ),
            ],
          ),
          // Fixed centre pin — always at the geometric middle of the
          // map viewport. The idle-camera position IS the picked
          // location.
          const IgnorePointer(
            ignoring: true,
            child: Center(
              child: Padding(
                // Nudge up by half the icon so the tip lands on the
                // exact centre pixel.
                padding: EdgeInsets.only(bottom: 32),
                child: Icon(Icons.location_on,
                    color: AppColors.primary, size: 40),
              ),
            ),
          ),
          // Bottom-right recentre hint pill so the user learns to
          // just pan the map.
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
              child: const Text(
                'Xaritani surib joyni belgilang',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
