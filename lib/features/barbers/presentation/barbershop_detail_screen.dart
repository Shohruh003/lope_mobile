import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../shared/theme/colors.dart';

/// Customer-facing barbershop profile. Shows the salon's hero image, name,
/// address, and the masters who work there — tapping a master opens their
/// own detail screen so the customer can pick a slot.
class BarbershopDetailScreen extends ConsumerWidget {
  const BarbershopDetailScreen({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shopByIdProvider(shopId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Xato: $e", style: const TextStyle(color: AppColors.textMuted))),
        data: (data) {
          final shop = data['shop'] as Map<String, dynamic>;
          final barbers = (data['barbers'] as List).cast<Map<String, dynamic>>();
          final cover = (shop['avatar'] ?? shop['cover'] ?? '').toString();
          final name = (shop['name'] ?? '').toString();
          final address = (shop['address'] ?? shop['location'] ?? '').toString();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.background,
                leading: const BackButton(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(fit: StackFit.expand, children: [
                    if (cover.isNotEmpty)
                      CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                    else
                      Container(color: AppColors.surface),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppColors.background],
                          begin: Alignment.center, end: Alignment.bottomCenter,
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
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: AppColors.textBright)),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(child: Text(address,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
                        ]),
                      ],
                      const SizedBox(height: 22),
                      const Text("Masterlar",
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textBright)),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (barbers.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text("Hali master ro'yxatga olinmagan",
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: barbers.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final b = barbers[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push('/barber/${b['id']}'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            ClipOval(
                              child: ((b['avatar'] ?? '') as String).isNotEmpty
                                  ? CachedNetworkImage(imageUrl: b['avatar'].toString(), width: 56, height: 56, fit: BoxFit.cover)
                                  : Container(width: 56, height: 56, color: AppColors.background, child: const Icon(Icons.person, color: AppColors.textMuted)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((b['name'] ?? '').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                                    const SizedBox(width: 4),
                                    Text(((b['rating'] ?? 0) as num).toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12)),
                                  ]),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textMuted),
                          ]),
                        ),
                      ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms);
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One-off provider — barbershop detail isn't accessed often enough to need
/// its own repository class. Returns both the shop record and the list of
/// barbers that work there.
final _shopByIdProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final Dio dio = ref.watch(dioProvider);
  final shopRes = await dio.get('/barbershops/$id');
  final barbersRes = await dio.get('/barbershops/$id/barbers');
  final barbers = (barbersRes.data is List)
      ? (barbersRes.data as List)
      : (barbersRes.data is Map && (barbersRes.data as Map)['data'] is List
          ? (barbersRes.data as Map)['data'] as List
          : <dynamic>[]);
  return {
    'shop': Map<String, dynamic>.from(shopRes.data as Map),
    'barbers': barbers,
  };
});
