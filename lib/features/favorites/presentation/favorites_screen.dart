import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../data/favorites_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.customer.favorites.title', 'Masterim'),
          style: AppText.titleMd,
        ),
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const AppListSkeleton(itemCount: 5),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            // Wrap the empty state in a scrollable so pull-to-refresh
            // works even when there are no favorites — otherwise the
            // user has no way to retry after a bad initial load.
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async =>
                  ref.refresh(favoritesProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 420,
                    child: AppEmptyState(
                      icon: Icons.bookmark_border,
                      title: tr(ref, 'mobile.customer.favorites.empty',
                          "Masterlaringiz yo'q"),
                      message: tr(
                        ref,
                        'mobile.customer.favorites.emptyHint',
                        "Sartaroshni masterlaringizga qo'shish uchun uning kartochkasida bookmark belgisini bosing.",
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(favoritesProvider.future),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.pageBottom(context)),
              itemCount: list.length,
              separatorBuilder: (_, _) => AppSpacing.gapSm,
              itemBuilder: (context, i) {
                final b = list[i];
                return AppCard(
                  variant: AppCardVariant.outlined,
                  padding: AppSpacing.cardPadding,
                  onTap: () => context.push('/barber/${b.id}'),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: b.avatar.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: assetUrl(b.avatar),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) =>
                                      const SkeletonCircle(size: 52),
                                )
                              : Container(
                                  width: 52,
                                  height: 52,
                                  color: context.colors.surfaceElevated,
                                  alignment: Alignment.center,
                                  child: Text(
                                    b.name.isNotEmpty
                                        ? b.name[0].toUpperCase()
                                        : '?',
                                    style: AppText.titleMd.copyWith(
                                        color: context.colors.textBright),
                                  ),
                                ),
                        ),
                      ),
                      AppSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: AppText.titleSm),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.star,
                                  size: 12, color: Color(0xFFFBBF24)),
                              AppSpacing.hGapXs,
                              Text(
                                b.rating.toStringAsFixed(1),
                                style: AppText.caption.copyWith(
                                  color: context.colors.textBright,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              AppSpacing.hGapSm,
                              if (b.location.isNotEmpty) ...[
                                Icon(Icons.location_on_outlined,
                                    size: 11, color: context.colors.textMuted),
                                AppSpacing.hGapXs,
                                Expanded(
                                  child: Text(b.location,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.caption),
                                ),
                              ] else
                                const Spacer(),
                            ]),
                          ],
                        ),
                      ),
                      TapScale(
                        onTap: () {
                          AppHaptics.light();
                          ref
                              .read(favoritesControllerProvider.notifier)
                              .toggleOptimistic(b.id);
                        },
                        scale: 0.85,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bookmark,
                              color: AppColors.primary, size: 20),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 250.ms, delay: (i * 30).ms)
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }
}
