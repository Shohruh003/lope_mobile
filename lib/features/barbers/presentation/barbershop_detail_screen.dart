import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';

class BarbershopDetailScreen extends ConsumerWidget {
  const BarbershopDetailScreen({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shopByIdProvider(shopId));
    final lang = ref.watch(localeProvider).asData?.value.locale ?? 'uz';
    return Scaffold(
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(_shopByIdProvider(shopId)),
        ),
        data: (shop) {
          final barbers = ((shop['barbers'] ?? const []) as List)
              .cast<Map<String, dynamic>>();
          final cover = (shop['avatar'] ?? shop['cover'] ?? '').toString();
          final name = (shop['name'] ?? '').toString();
          final address =
              (shop['address'] ?? shop['geoAddress'] ?? '').toString();
          final phone = (shop['phone'] ?? '').toString();
          final lat = (shop['latitude'] as num?)?.toDouble();
          final lng = (shop['longitude'] as num?)?.toDouble();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async =>
                ref.refresh(_shopByIdProvider(shopId).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: context.colors.background,
                  leading: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: TapScale(
                      onTap: () => context.pop(),
                      scale: 0.9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      if (cover.isNotEmpty)
                        CachedNetworkImage(
                            imageUrl: assetUrl(cover),
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const SkeletonRect())
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.3),
                                const Color(0xFF6366F1)
                                    .withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.storefront,
                                color: Colors.white38, size: 72),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              context.colors.background
                            ],
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppText.titleLg,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppSpacing.gapSm,
                        if (address.isNotEmpty)
                          Row(children: [
                            Icon(Icons.location_on_outlined,
                                size: 16,
                                color: context.colors.textSecondary),
                            AppSpacing.hGapXs,
                            Expanded(
                              child: Text(address,
                                  style: AppText.bodySm.copyWith(
                                      color: context.colors.textSecondary)),
                            ),
                          ]),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          TapScale(
                            onTap: () async {
                              AppHaptics.light();
                              await launchUrl(Uri.parse('tel:$phone'));
                            },
                            child: Row(children: [
                              const Icon(Icons.phone_outlined,
                                  size: 16,
                                  color: AppColors.primary),
                              AppSpacing.hGapXs,
                              Text(phone,
                                  style: AppText.bodySm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                        if (lat != null && lng != null) ...[
                          AppSpacing.gapMd,
                          AppButton(
                            label: tr(ref, 'customerApp.route', "Yo'l"),
                            leadingIcon: Icons.navigation,
                            variant: AppButtonVariant.secondary,
                            fullWidth: true,
                            onPressed: () async {
                              AppHaptics.light();
                              await launchUrl(
                                Uri.parse(
                                    'https://yandex.uz/maps/?pt=$lng,$lat&z=16'),
                                mode: LaunchMode.externalApplication,
                              );
                            },
                          ),
                        ],
                        AppSpacing.gapXl,
                        Row(children: [
                          Text(
                            tr(ref, 'mobile.shop.home.masters',
                                'Masterlar'),
                            style: AppText.overline,
                          ),
                          AppSpacing.hGapXs,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.15),
                              borderRadius: AppRadius.rPill,
                            ),
                            child: Text(
                              '${barbers.length}',
                              style: AppText.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ]),
                        AppSpacing.gapMd,
                      ],
                    ),
                  ),
                ),
                if (barbers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: tr(ref, 'mobile.shop.masters.empty',
                          "Hali master ro'yxatga olinmagan"),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    sliver: SliverList.separated(
                      itemCount: barbers.length,
                      separatorBuilder: (_, _) => AppSpacing.gapSm,
                      itemBuilder: (context, i) {
                        final b = barbers[i];
                        final user = (b['user'] ?? const {})
                            as Map<String, dynamic>;
                        final barberName =
                            (user['name'] ?? '').toString();
                        final avatar = (user['avatar'] ?? '').toString();
                        final rating =
                            (b['rating'] as num?)?.toDouble() ?? 0;
                        final reviewCount =
                            ((b['reviewCount'] ?? 0) as num).toInt();
                        final experience =
                            (b['experience'] ?? '').toString();
                        final isAvailable = b['isAvailable'] == true;
                        final services =
                            ((b['services'] ?? const []) as List)
                                .cast<Map<String, dynamic>>();
                        final minPrice = services.isEmpty
                            ? null
                            : services
                                .map((s) =>
                                    (s['price'] as num?)?.toInt() ?? 0)
                                .reduce((a, b) => a < b ? a : b);

                        return AppCard(
                          variant: AppCardVariant.outlined,
                          padding: AppSpacing.cardPadding,
                          onTap: () => context.push('/barber/${b['id']}'),
                          child: Row(children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: ClipOval(
                                child: avatar.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: assetUrl(avatar),
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) =>
                                            const SkeletonCircle(size: 52),
                                      )
                                    : Container(
                                        width: 52,
                                        height: 52,
                                        color: context.colors.surface,
                                        alignment: Alignment.center,
                                        child: Text(
                                          (barberName.isNotEmpty
                                                  ? barberName[0]
                                                  : '?')
                                              .toUpperCase(),
                                          style: AppText.titleMd,
                                        ),
                                      ),
                              ),
                            ),
                            AppSpacing.hGapMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(barberName,
                                      style: AppText.titleSm),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.star,
                                        size: 12,
                                        color: Color(0xFFFBBF24)),
                                    AppSpacing.hGapXs,
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: AppText.caption.copyWith(
                                        color: context.colors.textBright,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (reviewCount > 0) ...[
                                      AppSpacing.hGapXs,
                                      Text('($reviewCount)',
                                          style: AppText.caption),
                                    ],
                                    if (experience.isNotEmpty &&
                                        experience != '0') ...[
                                      AppSpacing.hGapSm,
                                      Text(
                                        '· $experience ${_yearWord(lang)}',
                                        style: AppText.caption,
                                      ),
                                    ],
                                  ]),
                                  if (minPrice != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      "${_fmt(minPrice)} ${tr(ref, 'common.currency', "so'm")}${_fromWord(lang)}",
                                      style: AppText.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            AppSpacing.hGapSm,
                            AppBadge(
                              label: isAvailable
                                  ? tr(ref, 'barbers.available',
                                      "Bo'sh")
                                  : tr(ref, 'barbers.unavailable',
                                      'Band'),
                              variant: isAvailable
                                  ? AppBadgeVariant.success
                                  : AppBadgeVariant.neutral,
                              dot: true,
                            ),
                          ]),
                        ).animate().fadeIn(
                            duration: 250.ms,
                            delay: (i * 30).ms,
                            curve: AppMotion.emphasized);
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _yearWord(String lang) {
    switch (lang) {
      case 'ru':
        return 'лет';
      case 'en':
        return 'yrs';
      default:
        return 'yil';
    }
  }

  static String _fromWord(String lang) {
    switch (lang) {
      case 'ru':
        return ' от';
      case 'en':
        return '+';
      default:
        return 'dan';
    }
  }

  static String _fmt(int n) {
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

final _shopByIdProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershops/$id');
  return Map<String, dynamic>.from(res.data as Map);
});
