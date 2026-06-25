import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants.dart';
import '../../../core/location_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../favorites/data/favorites_repository.dart';
import '../data/barber_repository.dart';
import '../data/public_barbershop_repository.dart';
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
  // 'rating' | 'name' | 'experience' | 'price' | 'distance' — matches web's
  // CustomerBarbersScreen. 'distance' uses the cached location provider; if
  // the user denies the permission, items without a known location bucket
  // to the bottom and the order falls back to rating.
  String _sort = 'rating';
  String _gender = 'ALL'; // 'ALL' | 'MALE' | 'FEMALE'
  bool _filterDefaulted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Parse the loose `experience` field (server returns either an int year
  /// count or a free-text string like "5 yil") into a sortable number.
  int _parseExperience(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  /// Min service price across the barber's services. Returns a very large
  /// number when there are no services so price-sort buckets them at the end.
  int _minPrice(Barber b) {
    if (b.services.isEmpty) return 1 << 30;
    return b.services.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }

  /// Haversine distance to a barber, or +infinity when their location is
  /// missing so they sort to the bottom under distance order.
  double _distOrInf(LatLng me, double? lat, double? lng) {
    if (lat == null || lng == null) return double.infinity;
    return haversineKm(me, LatLng(lat, lng));
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
                gender: _gender,
                searchHint: '${tr(ref, 'common.search', 'Qidirish')}...',
                allLabel: tr(ref, 'common.all', 'Hammasi'),
                favoritesLabel: tr(ref, 'customerApp.favorites', "Sevimlilar"),
                availableLabel: tr(ref, 'barbers.available', "Bo'sh"),
                ratingLabel: tr(ref, 'barbers.rating', "Reyting"),
                nameLabel: tr(ref, 'barbers.sortByName', "Ism"),
                experienceLabel: tr(ref, 'barbers.experience', "Tajriba"),
                priceLabel: tr(ref, 'booking.price', "Narx"),
                distanceLabel: tr(ref, 'barbers.nearest', "Eng yaqin"),
                maleLabel: tr(ref, 'barbers.genderMale', "Erkak"),
                femaleLabel: tr(ref, 'barbers.genderFemale', "Ayol"),
                onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onFilter: (f) => setState(() => _filter = f),
                onSort: (s) => setState(() => _sort = s),
                onGender: (g) => setState(() => _gender = g),
              ),
            ),

            async.when(
              loading: () => const SliverToBoxAdapter(child: _LoadingGrid()),
              error: (e, _) => SliverToBoxAdapter(child: _ErrorBlock(message: e.toString())),
              data: (list) {
                // Default the filter to 'favorites' on first load if the user
                // has any — same default web's CustomerBarbersScreen uses.
                if (!_filterDefaulted) {
                  final favs = ref.read(favoritesProvider).asData?.value ?? const [];
                  if (favs.isNotEmpty && _filter == 'all') {
                    _filter = 'favorites';
                  }
                  _filterDefaulted = true;
                }
                var filtered = _query.isEmpty
                    ? list
                    : list
                        .where((b) =>
                            b.name.toLowerCase().contains(_query) ||
                            b.location.toLowerCase().contains(_query))
                        .toList();
                if (_filter == 'available') {
                  filtered = filtered.where((b) => b.isAvailable).toList();
                } else if (_filter == 'favorites') {
                  final favs = ref.watch(favoritesProvider).asData?.value ?? const [];
                  final favIds = favs.map((b) => b.id).toSet();
                  filtered = filtered.where((b) => favIds.contains(b.id)).toList();
                }
                // Gender filter — barber.targetGender is 'MALE_ONLY' / 'FEMALE_ONLY'
                // / null. A null (no preference) barber serves anyone, so they
                // appear in every gender bucket. Same semantics web uses.
                if (_gender == 'MALE') {
                  filtered = filtered
                      .where(
                          (b) => b.targetGender == null || b.targetGender == 'MALE_ONLY')
                      .toList();
                } else if (_gender == 'FEMALE') {
                  filtered = filtered
                      .where((b) =>
                          b.targetGender == null ||
                          b.targetGender == 'FEMALE_ONLY')
                      .toList();
                }
                filtered = [...filtered];
                final me = ref.watch(currentLocationProvider).asData?.value;
                switch (_sort) {
                  case 'name':
                    filtered.sort((a, b) => a.name.compareTo(b.name));
                    break;
                  case 'experience':
                    filtered.sort((a, b) =>
                        _parseExperience(b.experience).compareTo(_parseExperience(a.experience)));
                    break;
                  case 'price':
                    filtered.sort((a, b) => _minPrice(a).compareTo(_minPrice(b)));
                    break;
                  case 'distance':
                    if (me != null) {
                      filtered.sort((a, b) {
                        final da = _distOrInf(me, a.lat, a.lng);
                        final db = _distOrInf(me, b.lat, b.lng);
                        return da.compareTo(db);
                      });
                    } else {
                      filtered.sort((a, b) => b.rating.compareTo(a.rating));
                    }
                    break;
                  case 'rating':
                  default:
                    filtered.sort((a, b) => b.rating.compareTo(a.rating));
                }
                // Merge in public barbershops — the customer feed shows
                // standalone barbers AND whole shops in one grid (mirrors
                // web's CustomerBarbersScreen). Shops are hidden when the
                // filter is 'favorites'.
                final shops = ref.watch(publicBarbershopsProvider).asData?.value ?? const [];
                final mergedShops = (_filter == 'favorites')
                    ? const <PublicBarbershop>[]
                    : (_query.isEmpty
                        ? shops
                        : shops
                            .where((s) =>
                                s.name.toLowerCase().contains(_query) ||
                                s.address.toLowerCase().contains(_query))
                            .toList());
                final items = <_FeedItem>[
                  ...filtered.map((b) => _FeedItem.barber(b)),
                  ...mergedShops.map((s) => _FeedItem.shop(s)),
                ];
                if (_sort == 'distance' && me != null) {
                  // Re-sort the merged list so shops mingle with barbers
                  // by distance — same web behaviour.
                  items.sort((a, b) {
                    final aLat = a.barber?.lat ?? a.shop?.lat;
                    final aLng = a.barber?.lng ?? a.shop?.lng;
                    final bLat = b.barber?.lat ?? b.shop?.lat;
                    final bLng = b.barber?.lng ?? b.shop?.lng;
                    return _distOrInf(me, aLat, aLng)
                        .compareTo(_distOrInf(me, bLat, bLng));
                  });
                }
                if (items.isEmpty) return const SliverToBoxAdapter(child: _EmptyState());
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.74,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final child = item.shop != null
                          ? _ShopCard(shop: item.shop!)
                          : _BarberCard(
                              barber: item.barber!,
                              avatarUrl: _avatarUrl(item.barber!.avatar),
                            );
                      return child.animate().fadeIn(duration: 250.ms, delay: (i * 25).ms);
                    },
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
    required this.gender,
    required this.searchHint,
    required this.allLabel,
    required this.favoritesLabel,
    required this.availableLabel,
    required this.ratingLabel,
    required this.nameLabel,
    required this.experienceLabel,
    required this.priceLabel,
    required this.distanceLabel,
    required this.maleLabel,
    required this.femaleLabel,
    required this.onSearch,
    required this.onClearSearch,
    required this.onFilter,
    required this.onSort,
    required this.onGender,
  });
  final TextEditingController searchController;
  final String query;
  final String filter;
  final String sort;
  final String gender;
  final String searchHint;
  final String allLabel;
  final String favoritesLabel;
  final String availableLabel;
  final String ratingLabel;
  final String nameLabel;
  final String experienceLabel;
  final String priceLabel;
  final String distanceLabel;
  final String maleLabel;
  final String femaleLabel;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onGender;

  @override
  double get maxExtent => 142;
  @override
  double get minExtent => 142;
  @override
  bool shouldRebuild(_StickyFilterHeader old) =>
      query != old.query ||
      filter != old.filter ||
      sort != old.sort ||
      gender != old.gender ||
      searchHint != old.searchHint ||
      allLabel != old.allLabel;

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
              hintText: searchHint,
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
                label: favoritesLabel,
                on: filter == 'favorites',
                onTap: () => onFilter('favorites'),
                onColor: AppColors.danger,
              ),
              _Pill(
                label: allLabel,
                on: filter == 'all',
                onTap: () => onFilter('all'),
                onColor: AppColors.primary,
              ),
              _Pill(
                label: availableLabel,
                on: filter == 'available',
                onTap: () => onFilter('available'),
                onColor: AppColors.primary,
              ),
              const _Sep(),
              _Pill(
                label: distanceLabel,
                on: sort == 'distance',
                onTap: () => onSort('distance'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
              _Pill(
                label: ratingLabel,
                on: sort == 'rating',
                onTap: () => onSort('rating'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
              _Pill(
                label: nameLabel,
                on: sort == 'name',
                onTap: () => onSort('name'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
              _Pill(
                label: experienceLabel,
                on: sort == 'experience',
                onTap: () => onSort('experience'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
              _Pill(
                label: priceLabel,
                on: sort == 'price',
                onTap: () => onSort('price'),
                onColor: const Color(0xFF3B82F6),
                tintBg: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Gender pills — match web's ALL/MALE/FEMALE target gender filter
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Pill(
                label: allLabel,
                on: gender == 'ALL',
                onTap: () => onGender('ALL'),
                onColor: const Color(0xFF8B5CF6),
                tintBg: true,
              ),
              _Pill(
                label: maleLabel,
                on: gender == 'MALE',
                onTap: () => onGender('MALE'),
                onColor: const Color(0xFF8B5CF6),
                tintBg: true,
              ),
              _Pill(
                label: femaleLabel,
                on: gender == 'FEMALE',
                onTap: () => onGender('FEMALE'),
                onColor: const Color(0xFF8B5CF6),
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

/// Discriminator wrapper used by the merged barbers+shops grid. Exactly one
/// of [barber] or [shop] is non-null.
class _FeedItem {
  _FeedItem.barber(Barber b)
      : barber = b,
        shop = null;
  _FeedItem.shop(PublicBarbershop s)
      : barber = null,
        shop = s;
  final Barber? barber;
  final PublicBarbershop? shop;
}

/// Barbershop card — same dimensions as _BarberCard so the grid looks even.
/// Header shows a building gradient; body shows shop name + barber count +
/// address (or geoAddress). Tapping routes to /barbershop/:id.
class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});
  final PublicBarbershop shop;

  @override
  Widget build(BuildContext context) {
    final addr = shop.address.isEmpty ? (shop.geoAddress ?? '') : shop.address;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/barbershop/${shop.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 96,
            child: Stack(children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                      const Color(0xFF6366F1).withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.storefront,
                    size: 44, color: Color(0xFFA78BFA)),
              ),
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${shop.barberCount} 👤',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 11, color: AppColors.textMuted),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(addr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Compact 2-column grid card matching the web exactly:
///   - h-24 (96px) photo strip with primary-tinted gradient + first gallery
///     image at 60% opacity
///   - Heart icon top-left in rounded bg-background/70 backdrop
///   - Status badge top-right (10px font)
///   - Body: avatar h-11 (44px) overlapping with -mt-6, title text-sm, then
///     rating/location sub-line
class _BarberCard extends ConsumerWidget {
  const _BarberCard({required this.barber, required this.avatarUrl});
  final Barber barber;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: Consumer(builder: (context, ref, _) {
                  final favsAsync = ref.watch(favoritesProvider);
                  final isFav = favsAsync.maybeWhen<bool>(
                      data: (l) => l.any((b) => b.id == barber.id),
                      orElse: () => false);
                  return InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () async {
                      try {
                        await ref
                            .read(favoritesRepositoryProvider)
                            .toggle(barber.id);
                        ref.invalidate(favoritesProvider);
                      } catch (_) {}
                    },
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isFav ? AppColors.danger : AppColors.textPrimary),
                    ),
                  );
                }),
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
                    barber.isAvailable
                        ? tr(ref, 'barbers.available', "Bo'sh")
                        : tr(ref, 'barbers.unavailable', "Band"),
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(children: [
        const Icon(Icons.content_cut, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(tr(ref, 'barbers.noBarbers', "Sartarosh topilmadi"),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}
