import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/errors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../barbers/data/barber_repository.dart';

/// Lightweight "near me" screen: shows every barber with their location and
/// a "Yo'l ko'rsatish" button that opens the native maps app via a
/// `https://maps.google.com/?q=lat,lng` URL. We deliberately don't embed a
/// map widget so the build stays slim and no API key is needed.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barbersListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.map.title', "Yaqin atrofda"))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}", style: const TextStyle(color: AppColors.textMuted))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(tr(ref, 'mobile.map.empty', "Yaqin atrofda sartaroshlar topilmadi"),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.refresh(barbersListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: list.length,
              separatorBuilder: (context, i) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final b = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/barber/${b.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(children: [
                      ClipOval(
                        child: b.avatar.isNotEmpty
                            ? CachedNetworkImage(imageUrl: assetUrl(b.avatar), width: 48, height: 48, fit: BoxFit.cover)
                            : Container(width: 48, height: 48, color: AppColors.background, child: const Icon(Icons.person, color: AppColors.textMuted)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(b.location.isEmpty ? "—" : b.location,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: tr(ref, 'mobile.map.directions',
                            "Yo'l ko'rsatish"),
                        icon: const Icon(Icons.directions, color: AppColors.primary),
                        onPressed: () => _openDirections(b.location),
                      ),
                    ]),
                  ),
                ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
              },
            ),
          );
        },
      ),
    );
  }

  /// Open the native maps app with a search query. We pass the location
  /// string verbatim — never a user-controlled scheme — so no path-injection
  /// surface here.
  Future<void> _openDirections(String location) async {
    if (location.trim().isEmpty) return;
    final q = Uri.encodeComponent(location);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
