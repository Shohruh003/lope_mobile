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
            onPressed: myLL == null
                ? null
                : () {
                    AppHaptics.light();
                    _flyTo(myLL, zoom: 15);
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
          // Only pin masters that actually have coordinates. Others show
          // up in Yaqin atrofda list but not on the map.
          final located = list
              .where((b) => b.lat != null && b.lng != null)
              .toList(growable: false);
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
                // Stadia Alidade Smooth for light + Alidade Smooth Dark
                // for dark. Both are Yandex-flavoured OSM styles with
                // clear road hierarchy and coloured POIs. Free tier
                // covers dev / early prod (200k tiles/month, no API
                // key on localhost). For the dark variant we push the
                // tiles through a saturation + brightness boost so the
                // canvas doesn't read "hira" (dull) - matches the
                // navy-blue Yandex night map the user asked for.
                Builder(builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  final tiles = TileLayer(
                    urlTemplate: isDark
                        ? 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png'
                        : 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}{r}.png',
                    additionalOptions: const {'r': ''},
                    userAgentPackageName: 'uz.lopestyle.mobile',
                    maxZoom: 20,
                    retinaMode: MediaQuery.of(ctx).devicePixelRatio > 1.5,
                  );
                  if (!isDark) return tiles;
                  return ColorFiltered(
                    // Saturation ~1.5x + slight brightness lift.
                    // sat = 1.5, lum(R)=0.213, lum(G)=0.715, lum(B)=0.072
                    // Row = lum + (1-lum) * sat matrix from Porterduff
                    // color-boost table.
                    colorFilter: const ColorFilter.matrix(<double>[
                      1.463, -0.358, -0.036, 0, 14,
                      -0.107, 1.213,  -0.036, 0, 14,
                      -0.107, -0.358, 1.535,  0, 14,
                      0,      0,       0,      1, 0,
                    ]),
                    child: tiles,
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
                      width: 44,
                      height: 44,
                      child: _BarberPin(
                        selected: isSelected,
                        available: b.isAvailable,
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
            // OSM attribution — required by license.
            const Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: _OsmAttribution(),
            ),
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
    required this.onTap,
  });
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.primary : context.colors.textMuted;
    return TapScale(
      onTap: onTap,
      haptic: HapticStrength.none,
      scale: 0.85,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: selected ? 44 : 36,
        height: selected ? 44 : 36,
        decoration: BoxDecoration(
          gradient: available ? AppColors.primaryGradient : null,
          color: available ? null : context.colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: selected ? 0.6 : 0.35),
              blurRadius: selected ? 18 : 8,
              spreadRadius: selected ? 3 : 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.content_cut,
          color: available ? Colors.white : context.colors.textMuted,
          size: selected ? 20 : 16,
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: AppRadius.rSm,
      ),
      child: Text(
        '© OpenStreetMap',
        style: AppText.overline.copyWith(
            color: Colors.white70, fontSize: 9, letterSpacing: 0.2),
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
