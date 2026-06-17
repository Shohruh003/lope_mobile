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

/// Customer-facing barber discovery feed — mirrors the web's
/// CustomerBarbersScreen exactly: sticky search + chip filters + sort chips +
/// 2-column grid of compact cards (h-24 photo strip + h-11 avatar overlap).
class BarbersListScreen extends ConsumerStatefulWidget {
  const BarbersListScreen({super.key});

  @override
  ConsumerState<BarbersListScreen> createState() => _BarbersListScreenState();
}

class _BarbersListScreenState extends ConsumerState<BarbersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all'; // 'all' | 'favorites' | 'available'
  String _sort = 'rating'; // 'rating' | 'experience'

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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(barbersListProvider.future),
        child: CustomScrollView(
          slivers: [
            // Sticky search + filter chips
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyFilterHeader(
                searchController: _searchController,
                query: _query,
                filter: _filter,
                sort: _sort,
                onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onFilter: (f) => setState(() => _filter = f),
                onSort: (s) => setState(() => _sort = s),
              ),
            ),

            async.when(
              loading: () => const SliverToBoxAdapter(child: _LoadingGrid()),
              error: (e, _) => SliverToBoxAdapter(child: _ErrorBlock(message: e.toString())),
              data: (list) {
                var filtered = _query.isEmpty
                    ? list
                    : list
                        .where((b) =>
                            b.name.toLowerCase().contains(_query) ||
                            b.location.toLowerCase().contains(_query))
                        .toList();
                if (_filter == 'available') {
                  filtered = filtered.where((b) => b.isAvailable).toList();
                }
                filtered = [...filtered];
                if (_sort == 'rating') {
                  filtered.sort((a, b) => b.rating.compareTo(a.rating));
                } else {
                  filtered.sort((a, b) => a.name.compareTo(b.name));
                }
                if (filtered.isEmpty) return const SliverToBoxAdapter(child: _EmptyState());
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _BarberCard(
                      barber: filtered[i],
                      avatarUrl: _avatarUrl(filtered[i].avatar),
                    ).animate().fadeIn(duration: 250.ms, delay: (i * 25).ms),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyFilterHeader extends SliverPersistentHeaderDelegate {
  _StickyFilterHeader({
    required this.searchController,
    required this.query,
    required this.filter,
    required this.sort,
    required this.onSearch,
    required this.onClearSearch,
    required this.onFilter,
    required this.onSort,
  });
  final TextEditingController searchController;
  final String query;
  final String filter;
  final String sort;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSort;

  @override
  double get maxExtent => 108;
  @override
  double get minExtent => 108;
  @override
  bool shouldRebuild(_StickyFilterHeader old) =>
      query != old.query || filter != old.filter || sort != old.sort;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search bar — h-10 (40px) with pl-9 left icon
        SizedBox(
          height: 40,
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14, color: AppColors.textBright, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 16),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              hintText: "Qidirish...",
              suffixIcon: query.isNotEmpty
                  ? GestureDetector(
                      onTap: onClearSearch,
                      child: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Filter pills — rounded-full px-3 py-1.5 text-xs
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Pill(
                label: "Hammasi",
                on: filter == 'all',
                onTap: () => onFilter('all'),
                onColor: AppColors.primary,
              ),
              _Pill(
                label: "Bo'sh",
                on: filter == 'available',
                onTap: () => onFilter('available'),
                onColor: AppColors.primary,
              ),
              const _Sep(),
              _Pill(
                label: "Reyting",
                on: sort == 'rating',
                onTap: () => onSort('rating'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
              _Pill(
                label: "Ism",
                on: sort == 'name',
                onTap: () => onSort('name'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.on,
    required this.onTap,
    required this.onColor,
    this.tintBg = false,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;
  final Color onColor;
  final bool tintBg;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on
                ? (tintBg ? onColor.withValues(alpha: 0.1) : onColor)
                : AppColors.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on ? onColor : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: on
                    ? (tintBg ? onColor : Colors.white)
                    : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        color: AppColors.border,
      );
}

/// Compact 2-column grid card matching the web exactly:
///   - h-24 (96px) photo strip with primary-tinted gradient + first gallery
///     image at 60% opacity
///   - Heart icon top-left in rounded bg-background/70 backdrop
///   - Status badge top-right (10px font)
///   - Body: avatar h-11 (44px) overlapping with -mt-6, title text-sm, then
///     rating/location sub-line
class _BarberCard extends StatelessWidget {
  const _BarberCard({required this.barber, required this.avatarUrl});
  final Barber barber;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final firstGallery = barber.gallery.isNotEmpty ? barber.gallery.first : '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/barber/${barber.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header strip h-24 (96px)
          SizedBox(
            height: 96,
            child: Stack(children: [
              Container(
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
                child: firstGallery.isEmpty
                    ? null
                    : Opacity(
                        opacity: 0.6,
                        child: CachedNetworkImage(
                          imageUrl: firstGallery,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
              // Heart top-left
              Positioned(
                top: 6, left: 6,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_border, size: 14, color: AppColors.textPrimary),
                ),
              ),
              // Status badge top-right
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: barber.isAvailable
                        ? AppColors.success.withValues(alpha: 0.85)
                        : AppColors.surfaceElevated.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    barber.isAvailable ? "Bo'sh" : "Band",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ]),
          ),

          // Body — relative -mt-6 so avatar overlaps
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: avatarUrl.isEmpty
                          ? _AvatarFallback(name: barber.name)
                          : CachedNetworkImage(
                              imageUrl: avatarUrl,
                              width: 44, height: 44,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const _AvatarShimmer(),
                              errorWidget: (context, url, err) => _AvatarFallback(name: barber.name),
                            ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(barber.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBright)),
                    const SizedBox(height: 4),
                    // Rating row (web shows this for barbers)
                    Row(children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 3),
                      Text(barber.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const SizedBox(width: 3),
                      Text("(${barber.reviewCount})",
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ]),
                    if (barber.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 11, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(barber.location,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ]),
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
      width: 44, height: 44,
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: Text(initial,
          style: const TextStyle(color: AppColors.textBright, fontSize: 18, fontWeight: FontWeight.w700)),
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
      child: Container(width: 44, height: 44, color: AppColors.surfaceElevated),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: 6,
        itemBuilder: (context, _) => Shimmer.fromColors(
          baseColor: AppColors.surfaceElevated,
          highlightColor: AppColors.border,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
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
          const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(children: const [
        Icon(Icons.content_cut, size: 40, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text("Sartarosh topilmadi",
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}
