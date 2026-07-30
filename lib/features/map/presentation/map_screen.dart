import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/location_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../barbers/data/barber_repository.dart';
import '../../barbers/domain/barber.dart';

/// Interactive map showing every master's location as a tap-able pin.
/// Tapping a pin slides up a compact card with photo + name + rating +
/// a "Yozilish" CTA. Uses OpenStreetMap tiles via flutter_map so we
/// don't need any Google/Yandex API keys.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  Barber? _selected;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _flyTo(ll.LatLng target, {double zoom = 15}) {
    _mapController.move(target, zoom);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barbersListProvider);
    final me = ref.watch(currentLocationProvider).asData?.value;
    final myLL = me == null ? null : ll.LatLng(me.lat, me.lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.map.title', 'Yaqin atrofda'),
          style: AppText.titleMd,
        ),
        actions: [
          IconButton(
            tooltip: tr(ref, 'mobile.map.recenter', 'Meni topish'),
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              AppHaptics.light();
              // Already resolved — fly to the cached position immediately.
              if (myLL != null) {
                _flyTo(myLL, zoom: 15);
                return;
              }
              // No cached position — user probably denied the permission
              // dialog last time or hadn't been asked. Re-run the
              // provider so the OS prompt appears again, then fly if we
              // got a fix. If it still returns null (denied for good /
              // location services off) surface a snackbar instead of
              // failing silently — before this the button just did
              // nothing and looked broken.
              ref.invalidate(currentLocationProvider);
              final fresh =
                  await ref.read(currentLocationProvider.future);
              if (!context.mounted) return;
              if (fresh != null) {
                _flyTo(ll.LatLng(fresh.lat, fresh.lng), zoom: 15);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(tr(
                        ref,
                        'mobile.map.locationDenied',
                        "Joylashuv ruxsati yo'q. Sozlamalardan yoqing."))));
              }
            },
          ),
        ],
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const BrandedLoader(compact: true),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (list) {
          // Only pin masters that actually have coordinates. Some seed
          // rows come through with 0/0 (never set) which would drop the
          // pin in the Atlantic — treat that as "no location" too.
          final located = list.where((b) {
            if (b.lat == null || b.lng == null) return false;
            if (b.lat == 0 && b.lng == 0) return false;
            return true;
          }).toList(growable: false);
          if (located.isEmpty) {
            return AppEmptyState(
              icon: Icons.location_off_outlined,
              title: tr(ref, 'mobile.map.empty',
                  'Yaqin atrofda sartaroshlar topilmadi'),
            );
          }

          final initial = myLL ??
              ll.LatLng(located.first.lat!, located.first.lng!);

          return Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initial,
                initialZoom: 12,
                minZoom: 4,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, _) {
                  if (_selected != null) {
                    setState(() => _selected = null);
                  }
                },
              ),
              children: [
                // In dark mode we swap to CartoDB Dark Matter — a
                // proper dark cartography (nearly black background,
                // muted roads) so the map matches the rest of the app.
                // The old approach was a ColorFilter over plain OSM
                // tiles but the result still read light-grey, not
                // "night-mode". CartoDB is free with attribution and
                // reliable on real devices (Stadia silently failed on
                // Android in earlier tests, per the removed comment).
                Builder(builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: isDark
                        ? const ['a', 'b', 'c', 'd']
                        : const [],
                    userAgentPackageName: 'uz.lopestyle.mobile',
                    maxNativeZoom: 19,
                    maxZoom: 20,
                    // CartoDB Dark Matter reads 'juda ham qora' — a
                    // near-black canvas with barely-visible roads. Ran
                    // the dark tiles through a lightening + slight
                    // blue-tint matrix so streets stand out and the
                    // whole surface reads 'night map' instead of
                    // 'blackout'. Multiplies RGB by 1.6 and lifts the
                    // black point ~30 to keep landmasses distinct from
                    // the water/void.
                    tileBuilder: isDark
                        ? (context, child, tile) => ColorFiltered(
                              colorFilter: const ColorFilter.matrix([
                                1.55, 0, 0, 0, 32,
                                0, 1.55, 0, 0, 32,
                                0, 0, 1.65, 0, 36,
                                0, 0, 0, 1, 0,
                              ]),
                              child: child,
                            )
                        : null,
                  );
                }),
                if (myLL != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: myLL,
                      width: 24,
                      height: 24,
                      child: const _MePin(),
                    ),
                  ]),
                MarkerLayer(
                  markers: located.map((b) {
                    final isSelected =
                        _selected?.id == b.id;
                    return Marker(
                      point: ll.LatLng(b.lat!, b.lng!),
                      width: isSelected ? 56 : 48,
                      height: isSelected ? 56 : 48,
                      child: _BarberPin(
                        selected: isSelected,
                        available: b.isAvailable,
                        avatar: b.avatar,
                        name: b.name,
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _selected = b);
                          _flyTo(ll.LatLng(b.lat!, b.lng!), zoom: 15);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            // OSM + CARTO attribution — required by license, kept as
            // small as we can legally get away with (7pt text, 40%
            // alpha, tap-through) so it stays present without stealing
            // customer attention. Butunlay olib tashlash mumkin emas —
            // OSM ODbL va CARTO CC BY 3.0 attribution talab qiladi.
            const Positioned(
              left: 4,
              bottom: 4,
              child: _OsmAttribution(),
            ),
            // Missing-location banner used to render here — 'N ta
            // sartarosh manzilni sozlamagan'. Barber dropped it
            // because it distracted customers from the actual map;
            // sartaroshlar who haven't set a location just aren't
            // pinned, no banner needed. missing count still computed
            // above in case we want to expose it in an info sheet
            // later.
            // Selected barber preview card
            if (_selected != null)
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.xl,
                child: _SelectedCard(
                  key: ValueKey(_selected!.id),
                  barber: _selected!,
                  onClose: () => setState(() => _selected = null),
                ).animate().fadeIn(duration: 200.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    duration: 250.ms,
                    curve: AppMotion.emphasized),
              ),
          ]);
        },
      ),
    );
  }
}

class _MePin extends StatelessWidget {
  const _MePin();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _BarberPin extends StatelessWidget {
  const _BarberPin({
    required this.selected,
    required this.available,
    required this.avatar,
    required this.name,
    required this.onTap,
  });
  final bool selected;
  final bool available;
  final String avatar;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = available ? AppColors.primary : context.colors.textMuted;
    final size = selected ? 52.0 : 44.0;
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.none,
      scale: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 3),
          boxShadow: [
            BoxShadow(
              color: ring.withValues(alpha: selected ? 0.6 : 0.35),
              blurRadius: selected ? 18 : 8,
              spreadRadius: selected ? 3 : 1,
            ),
          ],
        ),
        child: ClipOval(
          child: avatar.isEmpty
              ? _fallback(context)
              : CachedNetworkImage(
                  imageUrl: assetUrl(avatar),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _fallback(context),
                  errorWidget: (_, _, _) => _fallback(context),
                ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    // Monogram over the brand gradient — same fallback pattern shops
    // and list tiles use when no avatar is uploaded. Kept a scissors
    // icon before, but a coloured initial reads as "person" instead of
    // a generic pin, which is what the pin actually represents.
    return Container(
      decoration: BoxDecoration(
        gradient: available
            ? AppColors.primaryGradient
            : LinearGradient(colors: [
                context.colors.surface,
                context.colors.surfaceElevated,
              ]),
      ),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.titleSm.copyWith(
          color: available ? Colors.white : context.colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // CARTO tiles require attributing both the underlying OSM data
    // and CartoDB's styling. Light mode uses raw OSM tiles so only
    // the OSM credit is needed. Rendered as small as we can legally
    // get away with — barber flagged the previous pill as a customer
    // distraction. 7pt text, 35% alpha, no chip background — still
    // readable if you look, invisible in a glance.
    final label = isDark ? '© OSM · CARTO' : '© OSM';
    return IgnorePointer(
      ignoring: true,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          height: 1.1,
          letterSpacing: 0.15,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _SelectedCard extends ConsumerWidget {
  const _SelectedCard({
    super.key,
    required this.barber,
    required this.onClose,
  });
  final Barber barber;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentLocationProvider).asData?.value;
    final double? km = (me != null && barber.lat != null && barber.lng != null)
        ? haversineKm(me, LatLng(barber.lat!, barber.lng!))
        : null;
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/barber/${barber.id}'),
      child: Row(children: [
        _AvatarBadge(url: barber.avatar, name: barber.name),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    barber.name,
                    style: AppText.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TapScale(
                  onTap: onClose,
                  scale: 0.85,
                  haptic: HapticStrength.light,
                  // Enlarged from ~18px to a 44px hit area with a
                  // smaller visual pill — meets the touch-target
                  // minimum without stealing space from the title.
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close,
                          size: 14, color: context.colors.textMuted),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.star,
                    size: 12, color: Color(0xFFFBBF24)),
                AppSpacing.hGapXs,
                Text(
                  barber.rating.toStringAsFixed(1),
                  style: AppText.caption.copyWith(
                    color: context.colors.textBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.hGapXs,
                Text('(${barber.reviewCount})',
                    style: AppText.caption),
                if (km != null) ...[
                  AppSpacing.hGapSm,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me,
                            size: 10, color: AppColors.primary),
                        const SizedBox(width: 3),
                        Text(
                          km < 1
                              ? '${(km * 1000).round()} m'
                              : (km < 10
                                  ? '${km.toStringAsFixed(1)} km'
                                  : '${km.round()} km'),
                          style: AppText.overline.copyWith(
                              color: AppColors.primary,
                              fontSize: 10,
                              letterSpacing: 0.2),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'booking.title', 'Yozilish'),
                    leadingIcon: Icons.calendar_month,
                    size: AppButtonSize.sm,
                    fullWidth: true,
                    onPressed: () => context.push('/book/${barber.id}'),
                  ),
                ),
                AppSpacing.hGapSm,
                TapScale(
                  onTap: () => _openDirections(barber, context, ref),
                  scale: 0.9,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions,
                        color: AppColors.primary, size: 20),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _openDirections(
      Barber b, BuildContext context, WidgetRef ref) async {
    AppHaptics.light();
    if (b.lat == null || b.lng == null) return;
    final uri = Uri.parse(
        'https://yandex.uz/maps/?rtext=~${b.lat},${b.lng}&rtt=auto');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      // Was silent — the user tapped Directions, Yandex Maps failed to
      // launch (no browser / blocked intent) and there was zero
      // feedback. Surface it so they can at least try again or open
      // the URL manually.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(ref, 'common.cannotOpenLink',
              "Havolani ochib bo'lmadi"))));
    }
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.url, required this.name});
  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: url.isEmpty
          ? _initialFallback()
          : CachedNetworkImage(
              imageUrl: assetUrl(url),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SkeletonCircle(size: 48),
              errorWidget: (_, _, _) => _initialFallback(),
            ),
    );
  }

  Widget _initialFallback() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        alignment: Alignment.center,
        child: Text(
          (name.isNotEmpty ? name[0] : '?').toUpperCase(),
          style: AppText.titleSm.copyWith(color: Colors.white),
        ),
      );
}
