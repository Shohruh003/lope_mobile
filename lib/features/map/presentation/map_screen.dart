import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/location_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../barbers/data/barber_repository.dart';
import '../../barbers/domain/barber.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barbersListProvider);
    final me = ref.watch(currentLocationProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.map.title', 'Yaqin atrofda'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (list) {
          if (list.isEmpty) {
            return AppEmptyState(
              icon: Icons.location_off_outlined,
              title: tr(ref, 'mobile.map.empty',
                  'Yaqin atrofda sartaroshlar topilmadi'),
            );
          }
          // Sort by distance so nearest are on top. Barbers without
          // coordinates fall to the bottom (Infinity comparator).
          final sorted = [...list];
          if (me != null) {
            sorted.sort((a, b) {
              final da = _distOrInf(me, a.lat, a.lng);
              final db = _distOrInf(me, b.lat, b.lng);
              return da.compareTo(db);
            });
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(barbersListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final b = sorted[i];
                final km = (me != null && b.lat != null && b.lng != null)
                    ? haversineKm(me, LatLng(b.lat!, b.lng!))
                    : null;
                return AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  onTap: () => context.push('/barber/${b.id}'),
                  child: Row(children: [
                    ClipOval(
                      child: b.avatar.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: assetUrl(b.avatar),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  const SkeletonCircle(size: 48),
                              errorWidget: (_, _, _) =>
                                  _avatarFallback(b.name),
                            )
                          : _avatarFallback(b.name),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: AppText.titleSm),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: AppColors.textMuted),
                            AppSpacing.hGapXs,
                            Expanded(
                              child: Text(
                                b.location.isEmpty ? '—' : b.location,
                                style: AppText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),
                          if (km != null) ...[
                            const SizedBox(height: 4),
                            _DistancePill(km: km),
                          ],
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: () => _openDirections(b),
                      scale: 0.9,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions,
                            color: AppColors.primary, size: 20),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(
                    duration: 250.ms,
                    delay: (i * 25).ms,
                    curve: AppMotion.emphasized);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        alignment: Alignment.center,
        child: Text(
          (name.isNotEmpty ? name[0] : '?').toUpperCase(),
          style: AppText.titleSm.copyWith(color: Colors.white),
        ),
      );

  static double _distOrInf(LatLng me, double? lat, double? lng) {
    if (lat == null || lng == null) return double.infinity;
    return haversineKm(me, LatLng(lat, lng));
  }

  Future<void> _openDirections(Barber b) async {
    AppHaptics.light();
    // Prefer precise coords → yandex.uz maps. Falls back to a text search
    // via the location string when coords are missing.
    final Uri uri;
    if (b.lat != null && b.lng != null) {
      uri = Uri.parse(
          'https://yandex.uz/maps/?rtext=~${b.lat},${b.lng}&rtt=auto');
    } else if (b.location.trim().isNotEmpty) {
      uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(b.location)}');
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.km});
  final double km;

  String get _label {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me,
              size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(_label,
              style: AppText.overline.copyWith(
                  color: AppColors.primary,
                  fontSize: 10,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}
