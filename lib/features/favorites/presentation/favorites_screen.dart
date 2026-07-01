import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../data/favorites_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.customer.favorites.title', "Sevimlilar"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: $e")),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_border, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 14),
                    Text(tr(ref, 'mobile.customer.favorites.empty', "Sevimlilar ro'yxati bo'sh"),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(favoritesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => context.push('/barber/${b.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: b.avatar.isNotEmpty
                              ? CachedNetworkImage(imageUrl: assetUrl(b.avatar), width: 48, height: 48, fit: BoxFit.cover)
                              : Container(width: 48, height: 48, color: AppColors.surfaceElevated, child: const Icon(Icons.person, color: AppColors.textMuted)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                                const SizedBox(width: 4),
                                Text(b.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(b.location,
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                ),
                              ]),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite, color: AppColors.danger),
                          onPressed: () async {
                            try {
                              await ref.read(favoritesRepositoryProvider).toggle(b.id);
                              ref.invalidate(favoritesProvider);
                            } catch (_) {}
                          },
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms).slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }
}
