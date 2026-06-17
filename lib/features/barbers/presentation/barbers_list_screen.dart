import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants.dart';
import '../../../shared/theme/colors.dart';
import '../data/barber_repository.dart';
import '../domain/barber.dart';

/// Customer-facing barber discovery screen — the main "feed" of the app.
/// Search field at the top, then a vertical list of barber cards with
/// avatar, name, rating, location and an "Bron qilish" button.
class BarbersListScreen extends ConsumerStatefulWidget {
  const BarbersListScreen({super.key});

  @override
  ConsumerState<BarbersListScreen> createState() => _BarbersListScreenState();
}

class _BarbersListScreenState extends ConsumerState<BarbersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all'; // 'all' | 'available' | 'top'
  String _sort = 'rating'; // 'rating' | 'name'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _avatarUrl(String avatar) {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${AppConfig.apiUrl}$avatar';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barbersListProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(barbersListProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Sartaroshlar",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textBright,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Qidirish...",
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Filter chip row
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(label: "Hammasi", on: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                            _FilterChip(label: "Bo'sh", on: _filter == 'available', onTap: () => setState(() => _filter = 'available')),
                            _FilterChip(label: "Top", on: _filter == 'top', onTap: () => setState(() => _filter = 'top')),
                            const SizedBox(width: 6),
                            const VerticalDivider(width: 16, indent: 8, endIndent: 8, color: AppColors.border),
                            const SizedBox(width: 6),
                            _FilterChip(label: "Reyting", on: _sort == 'rating', onTap: () => setState(() => _sort = 'rating')),
                            _FilterChip(label: "Ism", on: _sort == 'name', onTap: () => setState(() => _sort = 'name')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              async.when(
                loading: () => const SliverToBoxAdapter(child: _LoadingList()),
                error: (e, _) => SliverToBoxAdapter(child: _ErrorBlock(message: e.toString())),
                data: (list) {
                  var filtered = _query.isEmpty
                      ? list
                      : list
                          .where((b) =>
                              b.name.toLowerCase().contains(_query) ||
                              b.location.toLowerCase().contains(_query))
                          .toList();
                  // Filter chips
                  if (_filter == 'available') {
                    filtered = filtered.where((b) => b.isAvailable).toList();
                  } else if (_filter == 'top') {
                    filtered = filtered.where((b) => b.rating >= 4.5).toList();
                  }
                  // Sort
                  filtered = [...filtered];
                  if (_sort == 'rating') {
                    filtered.sort((a, b) => b.rating.compareTo(a.rating));
                  } else {
                    filtered.sort((a, b) => a.name.compareTo(b.name));
                  }
                  if (filtered.isEmpty) {
                    return const SliverToBoxAdapter(child: _EmptyState());
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, i) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => _BarberCard(
                        barber: filtered[i],
                        avatarUrl: _avatarUrl(filtered[i].avatar),
                      ).animate().fadeIn(duration: 300.ms, delay: (i * 40).ms),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  const _BarberCard({required this.barber, required this.avatarUrl});
  final Barber barber;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final firstGalleryUrl = barber.gallery.isNotEmpty ? barber.gallery.first : '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/barber/${barber.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top photo strip — 128px tall, gallery image at 60% opacity, fallback gradient.
            Stack(
              children: [
                Container(
                  height: 128,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: firstGalleryUrl.isEmpty
                      ? null
                      : Opacity(
                          opacity: 0.6,
                          child: CachedNetworkImage(
                            imageUrl: firstGalleryUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
                // Status badge top-right
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: barber.isAvailable
                          ? AppColors.success.withValues(alpha: 0.85)
                          : AppColors.surfaceElevated.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      barber.isAvailable ? "Bo'sh" : "Band",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar overlapping the photo strip by -40px (-mt-10 in web)
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 4),
                      ),
                      child: ClipOval(
                        child: avatarUrl.isEmpty
                            ? _AvatarFallback(name: barber.name)
                            : CachedNetworkImage(
                                imageUrl: avatarUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const _AvatarShimmer(),
                                errorWidget: (context, url, err) => _AvatarFallback(name: barber.name),
                              ),
                      ),
                    ),
                  ),
                  // Pull subsequent content back up to compensate for the avatar offset.
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + star/rating
                        Row(children: [
                          Expanded(
                            child: Text(
                              barber.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textBright,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
                          const SizedBox(width: 4),
                          Text(barber.rating.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          Text("(${barber.reviewCount})",
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ]),

                        const SizedBox(height: 6),
                        if (barber.location.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(barber.location,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ]),
                        if (barber.experience != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text("${barber.experience} yil tajriba",
                                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ]),
                        ],
                        if (barber.bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            barber.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                          ),
                        ],

                        // Service tags
                        if (barber.services.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: [
                              ...barber.services.take(3).map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Text("${s.icon} ${s.name}",
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  )),
                              if (barber.services.length > 3)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text("+${barber.services.length - 3}",
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),
                        // 2-button row: Book + About
                        Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: barber.isAvailable
                                    ? () => context.push('/book/${barber.id}')
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                child: Text(barber.isAvailable ? "Bron qilish" : "Band"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: () => context.push('/barber/${barber.id}'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              child: const Text("Batafsil"),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(color: AppColors.textBright, fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }
}

class _AvatarShimmer extends StatelessWidget {
  const _AvatarShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceElevated,
      highlightColor: AppColors.border,
      child: Container(width: 64, height: 64, color: AppColors.surface),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.25),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: AppColors.surface,
              highlightColor: AppColors.surfaceElevated,
              child: Container(
                height: 92,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text("Yuklab bo'lmadi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            message.length > 120 ? message.substring(0, 120) : message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text("Hech narsa topilmadi", style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
