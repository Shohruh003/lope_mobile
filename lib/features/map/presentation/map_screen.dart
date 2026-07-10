import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../barbers/data/barber_repository.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barbersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.map.title', 'Yaqin atrofda'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
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
              itemCount: list.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final b = list[i];
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
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient),
                              alignment: Alignment.center,
                              child: Text(
                                (b.name.isNotEmpty ? b.name[0] : '?')
                                    .toUpperCase(),
                                style: AppText.titleSm
                                    .copyWith(color: Colors.white),
                              ),
                            ),
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
                        ],
                      ),
                    ),
                    TapScale(
                      onTap: () => _openDirections(b.location),
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

  Future<void> _openDirections(String location) async {
    if (location.trim().isEmpty) return;
    AppHaptics.light();
    final q = Uri.encodeComponent(location);
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
