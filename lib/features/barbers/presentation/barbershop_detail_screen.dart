import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../core/asset_url.dart';
import '../../../core/l10n.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';

/// Customer-facing barbershop profile. Mirrors web's
/// `CustomerBarbershopDetailScreen` 1:1 — hero, name, address, phone, route
/// button, and a barbers list with rating, experience, review count, min
/// price and availability badge. Single GET /barbershops/:id provides
/// everything in one round-trip (same endpoint web uses).
class BarbershopDetailScreen extends ConsumerWidget {
  const BarbershopDetailScreen({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shopByIdProvider(shopId));
    final lang = ref.watch(localeProvider).asData?.value.locale ?? 'uz';
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}",
                style: const TextStyle(color: AppColors.textMuted))),
        data: (shop) {
          final barbers =
              ((shop['barbers'] ?? const []) as List).cast<Map<String, dynamic>>();
          final cover = (shop['avatar'] ?? shop['cover'] ?? '').toString();
          final name = (shop['name'] ?? '').toString();
          final address = (shop['address'] ?? shop['geoAddress'] ?? '').toString();
          final phone = (shop['phone'] ?? '').toString();
          final lat = (shop['latitude'] as num?)?.toDouble();
          final lng = (shop['longitude'] as num?)?.toDouble();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(_shopByIdProvider(shopId).future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: AppColors.background,
                  leading: const BackButton(color: Colors.white),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(fit: StackFit.expand, children: [
                      if (cover.isNotEmpty)
                        CachedNetworkImage(imageUrl: assetUrl(cover), fit: BoxFit.cover)
                      else
                        Container(color: AppColors.surface,
                            child: const Center(
                                child: Icon(Icons.content_cut,
                                    color: AppColors.textMuted, size: 48))),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, AppColors.background],
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: AppColors.textBright)),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(address,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                            ),
                          ]),
                        ],
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () =>
                                launchUrl(Uri.parse('tel:$phone')),
                            child: Row(children: [
                              const Icon(Icons.phone_outlined,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(phone,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14)),
                            ]),
                          ),
                        ],
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => launchUrl(
                                Uri.parse(
                                    'https://yandex.uz/maps/?pt=$lng,$lat&z=16'),
                                mode: LaunchMode.externalApplication,
                              ),
                              icon: const Icon(Icons.navigation_outlined,
                                  size: 18),
                              label: Text(tr(ref, 'customerApp.route', "Yo'l")),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Text(
                            "${tr(ref, 'mobile.shop.home.masters', "Masterlar")} (${barbers.length})",
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.textMuted,
                                letterSpacing: 0.6)),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                if (barbers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                            tr(ref, 'mobile.shop.masters.empty',
                                "Hali master ro'yxatga olinmagan"),
                            style: const TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: barbers.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = barbers[i];
                        final user =
                            (b['user'] ?? const {}) as Map<String, dynamic>;
                        final barberName = (user['name'] ?? '').toString();
                        final avatar = (user['avatar'] ?? '').toString();
                        final rating = (b['rating'] as num?)?.toDouble() ?? 0;
                        final reviewCount =
                            ((b['reviewCount'] ?? 0) as num).toInt();
                        final experience = (b['experience'] ?? '').toString();
                        final isAvailable = b['isAvailable'] == true;
                        final services = ((b['services'] ?? const []) as List)
                            .cast<Map<String, dynamic>>();
                        final minPrice = services.isEmpty
                            ? null
                            : services
                                .map((s) => (s['price'] as num?)?.toInt() ?? 0)
                                .reduce((a, b) => a < b ? a : b);

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/barber/${b['id']}'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(children: [
                              ClipOval(
                                child: avatar.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: assetUrl(avatar),
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: AppColors.background,
                                        child: const Icon(Icons.person,
                                            color: AppColors.textMuted),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(barberName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      const Icon(Icons.star,
                                          size: 12, color: AppColors.warning),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500)),
                                      if (reviewCount > 0) ...[
                                        const SizedBox(width: 4),
                                        Text("($reviewCount)",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted)),
                                      ],
                                      if (experience.isNotEmpty &&
                                          experience != '0') ...[
                                        const SizedBox(width: 6),
                                        Text(
                                            "• $experience ${_yearWord(lang)}",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted)),
                                      ],
                                    ]),
                                    if (minPrice != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                          "${_fmt(minPrice)} ${tr(ref, 'common.currency', "so'm")}${_fromWord(lang)}",
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isAvailable
                                          ? AppColors.success
                                              .withValues(alpha: 0.3)
                                          : AppColors.border),
                                ),
                                child: Text(
                                    isAvailable
                                        ? tr(ref, 'barbers.available', 'Bo\'sh')
                                        : tr(ref, 'barbers.unavailable', 'Band'),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isAvailable
                                            ? AppColors.success
                                            : AppColors.textMuted)),
                              ),
                            ]),
                          ),
                        ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms);
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

/// Single GET /barbershops/:id — response includes the barbers array with
/// rating, reviewCount, experience, services, isAvailable (same shape web
/// uses via `getPublicBarbershopAPI`).
final _shopByIdProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final res = await dio.get('/barbershops/$id');
  return Map<String, dynamic>.from(res.data as Map);
});
