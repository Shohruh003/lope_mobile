import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/location_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../favorites/data/favorites_repository.dart';
import '../data/barber_repository.dart';
import '../data/public_barbershop_repository.dart';
import '../domain/barber.dart';

/// Redesigned customer-facing barber discovery feed. Uzum/Click darajasidagi
/// polish maqsadida:
///
///   1) Sarlavha — 3 qator chip o'rniga bitta qator: 3 ta asosiy filter
///      (Sevimlilar/Barchasi/Bo'sh) + tuner iconi. Sort va gender endi
///      bottom sheet ichida — hech narsa sig'may qolmaydi.
///   2) Kartochkalar — barber va salon uchun bir xil "shell" (AppCard).
///      Farqi faqat: barber — avatar, salon — building icon + usta soni badge.
///   3) Status badge — yashil dot bilan aniq "Bo'sh/Band" ko'rsatuvchi
///      AppBadge (top-right). Bir qarashda ko'rinadi.
///   4) TapScale — har kartochka tap qilinganda ozgina 0.96 scale + haptik.
class BarbersListScreen extends ConsumerStatefulWidget {
  const BarbersListScreen({super.key});

  @override
  ConsumerState<BarbersListScreen> createState() => _BarbersListScreenState();
}

class _BarbersListScreenState extends ConsumerState<BarbersListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all'; // 'all' | 'favorites' | 'available'
  String _sort = 'distance'; // 'distance' | 'rating' | 'name' | 'experience' | 'price'
  String _gender = 'ALL'; // 'ALL' | 'MALE' | 'FEMALE'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _parseExperience(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  int _minPrice(Barber b) {
    if (b.services.isEmpty) return 1 << 30;
    return b.services.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }

  double _distOrInf(LatLng me, double? lat, double? lng) {
    if (lat == null || lng == null) return double.infinity;
    return haversineKm(me, LatLng(lat, lng));
  }

  String _avatarUrl(String avatar) => assetUrl(avatar);

  Future<void> _openTuner() async {
    AppHaptics.light();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.rTopXl),
      isScrollControlled: true,
      builder: (_) => _TunerSheet(
        sort: _sort,
        gender: _gender,
        onApply: (s, g) => setState(() {
          _sort = s;
          _gender = g;
        }),
      ),
    );
  }

  bool get _tunerActive => _sort != 'distance' || _gender != 'ALL';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barbersListProvider);
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.refresh(barbersListProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyFilterHeader(
                searchController: _searchController,
                query: _query,
                filter: _filter,
                tunerActive: _tunerActive,
                searchHint: '${tr(ref, 'common.search', 'Qidirish')}...',
                allLabel: tr(ref, 'common.all', 'Hammasi'),
                favoritesLabel: tr(ref, 'customerApp.favorites', "Sevimlilar"),
                availableLabel: tr(ref, 'barbers.available', "Bo'sh"),
                onSearch: (v) => setState(() => _query = v.trim().toLowerCase()),
                onClearSearch: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                onFilter: (f) => setState(() => _filter = f),
                onOpenTuner: _openTuner,
              ),
            ),
            async.when(
              // Keep showing the previous data during a pull-to-refresh so
              // the screen never goes blank — user sees stale cards with
              // the RefreshIndicator spinner overlay rather than a wall of
              // shimmering skeletons every 3 seconds.
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => const SliverToBoxAdapter(child: _LoadingGrid()),
              error: (e, _) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 380,
                  child: AppErrorState(
                    message: humanize(e),
                    onRetry: () => ref.invalidate(barbersListProvider),
                  ),
                ),
              ),
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
                } else if (_filter == 'favorites') {
                  final favs =
                      ref.watch(favoritesProvider).asData?.value ?? const [];
                  final favIds = favs.map((b) => b.id).toSet();
                  filtered =
                      filtered.where((b) => favIds.contains(b.id)).toList();
                }
                if (_gender == 'MALE') {
                  filtered = filtered
                      .where((b) =>
                          b.targetGender == null ||
                          b.targetGender == 'MALE_ONLY')
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
                    filtered.sort((a, b) => _parseExperience(b.experience)
                        .compareTo(_parseExperience(a.experience)));
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
                final shops =
                    ref.watch(publicBarbershopsProvider).asData?.value ??
                        const [];
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
                  items.sort((a, b) {
                    final aLat = a.barber?.lat ?? a.shop?.lat;
                    final aLng = a.barber?.lng ?? a.shop?.lng;
                    final bLat = b.barber?.lat ?? b.shop?.lat;
                    final bLng = b.barber?.lng ?? b.shop?.lng;
                    return _distOrInf(me, aLat, aLng)
                        .compareTo(_distOrInf(me, bLat, bLng));
                  });
                }
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(child: _EmptyState());
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.72,
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
                      return child.animate().fadeIn(
                            duration: 250.ms,
                            delay: (i * 25).ms,
                            curve: AppMotion.emphasized,
                          );
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

// ─────────────────────────────────────────────────────────────────────────
// Sticky filter header — search + primary chips + tuner button
// ─────────────────────────────────────────────────────────────────────────
class _StickyFilterHeader extends SliverPersistentHeaderDelegate {
  _StickyFilterHeader({
    required this.searchController,
    required this.query,
    required this.filter,
    required this.tunerActive,
    required this.searchHint,
    required this.allLabel,
    required this.favoritesLabel,
    required this.availableLabel,
    required this.onSearch,
    required this.onClearSearch,
    required this.onFilter,
    required this.onOpenTuner,
  });
  final TextEditingController searchController;
  final String query;
  final String filter;
  final bool tunerActive;
  final String searchHint;
  final String allLabel;
  final String favoritesLabel;
  final String availableLabel;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFilter;
  final VoidCallback onOpenTuner;

  @override
  double get maxExtent => 108;
  @override
  double get minExtent => 108;
  @override
  bool shouldRebuild(_StickyFilterHeader old) =>
      query != old.query ||
      filter != old.filter ||
      tunerActive != old.tunerActive ||
      searchHint != old.searchHint;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search bar
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.rMd,
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            style: AppText.body.copyWith(color: AppColors.textBright),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textMuted, size: 20),
              hintText: searchHint,
              hintStyle: AppText.body.copyWith(color: AppColors.textMuted),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        AppHaptics.light();
                        onClearSearch();
                      },
                    )
                  : null,
            ),
          ),
        ),
        AppSpacing.gapSm,
        // Filter chips + tuner
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 36,
              // Sevimlilar chip is now a header shortcut icon that
              // pushes to /favorites — keep just the list-scope filters
              // here.
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip(
                    label: allLabel,
                    selected: filter == 'all',
                    onTap: () => onFilter('all'),
                  ),
                  AppSpacing.hGapSm,
                  AppChip(
                    label: availableLabel,
                    selected: filter == 'available',
                    onTap: () => onFilter('available'),
                  ),
                ],
              ),
            ),
          ),
          AppSpacing.hGapSm,
          // Tuner button — opens bottom sheet with sort + gender
          TapScale(
            onTap: onOpenTuner,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tunerActive
                    ? AppColors.primary
                    : AppColors.surfaceElevated,
                borderRadius: AppRadius.rPill,
                border: Border.all(
                  color: tunerActive ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Icon(
                Icons.tune,
                size: 16,
                color: tunerActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tuner bottom sheet — sort + gender in one dialog
// ─────────────────────────────────────────────────────────────────────────
class _TunerSheet extends ConsumerStatefulWidget {
  const _TunerSheet({
    required this.sort,
    required this.gender,
    required this.onApply,
  });
  final String sort;
  final String gender;
  final void Function(String sort, String gender) onApply;

  @override
  ConsumerState<_TunerSheet> createState() => _TunerSheetState();
}

class _TunerSheetState extends ConsumerState<_TunerSheet> {
  late String _sort = widget.sort;
  late String _gender = widget.gender;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.rPill,
                  ),
                ),
              ),
              AppSpacing.gapLg,
              Text(
                tr(ref, 'mobile.barbers.tunerTitle', "Saralash va filter"),
                style: AppText.titleMd,
              ),
              AppSpacing.gapLg,
              // Sort
              Text(
                tr(ref, 'mobile.barbers.sortLabel', 'Saralash'),
                style: AppText.overline,
              ),
              AppSpacing.gapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _sortChip('rating', tr(ref, 'barbers.rating', 'Reyting'),
                      Icons.star),
                  _sortChip('distance',
                      tr(ref, 'barbers.nearest', 'Eng yaqin'), Icons.near_me),
                  _sortChip(
                      'name', tr(ref, 'barbers.sortByName', 'Ism'), Icons.sort_by_alpha),
                  _sortChip('experience',
                      tr(ref, 'barbers.experience', 'Tajriba'), Icons.workspace_premium),
                  _sortChip(
                      'price', tr(ref, 'booking.price', 'Narx'), Icons.payments),
                ],
              ),
              AppSpacing.gapLg,
              // Gender
              Text(
                tr(ref, 'mobile.barbers.genderLabel', 'Jinsi'),
                style: AppText.overline,
              ),
              AppSpacing.gapSm,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _genderChip(
                      'ALL', tr(ref, 'common.all', 'Hammasi')),
                  _genderChip(
                      'MALE', "👨 ${tr(ref, 'barbers.genderMale', 'Erkak')}"),
                  _genderChip('FEMALE',
                      "👩 ${tr(ref, 'barbers.genderFemale', 'Ayol')}"),
                ],
              ),
              AppSpacing.gapXl,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.reset', 'Tozalash'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      AppHaptics.light();
                      setState(() {
                        _sort = 'rating';
                        _gender = 'ALL';
                      });
                    },
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.apply', "Qo'llash"),
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      widget.onApply(_sort, _gender);
                      Navigator.pop(context);
                    },
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String key, String label, IconData icon) {
    return AppChip(
      label: label,
      leadingIcon: icon,
      selected: _sort == key,
      onTap: () => setState(() => _sort = key),
    );
  }

  Widget _genderChip(String key, String label) {
    return AppChip(
      label: label,
      selected: _gender == key,
      onTap: () => setState(() => _gender = key),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Feed item + unified cards
// ─────────────────────────────────────────────────────────────────────────
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

class _ShopCard extends ConsumerWidget {
  const _ShopCard({required this.shop});
  final PublicBarbershop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addr = shop.address.isEmpty ? (shop.geoAddress ?? '') : shop.address;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      onTap: () => context.push('/barbershop/${shop.id}'),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — building gradient + count badge
            SizedBox(
              height: 96,
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                        const Color(0xFF6366F1).withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.storefront,
                      size: 42, color: Color(0xFFA78BFA)),
                ),
                // Shop marker top-left
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business,
                            size: 10, color: Colors.white),
                        AppSpacing.hGapXs,
                        Text(
                          tr(ref, 'mobile.barbers.salonBadge', 'Salon'),
                          style: AppText.caption
                              .copyWith(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                // Barber count badge top-right
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups,
                            size: 12, color: Colors.white),
                        AppSpacing.hGapXs,
                        Text(
                          '${shop.barberCount}',
                          style: AppText.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleSm,
                  ),
                  const SizedBox(height: 6),
                  if (addr.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textMuted),
                      AppSpacing.hGapXs,
                      Expanded(
                        child: Text(
                          addr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarberCard extends ConsumerWidget {
  const _BarberCard({required this.barber, required this.avatarUrl});
  final Barber barber;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstGallery = barber.gallery.isNotEmpty ? barber.gallery.first : '';
    // Watch the optimistic-favorites Set so the bookmark flips instantly
    // on tap. Server list still drives the initial value via the
    // controller's seed listener.
    final favIds = ref.watch(favoritesControllerProvider);
    final isFav = favIds.contains(barber.id);

    // Distance to the customer — used to show a "1.2 km" pill next to
    // the location. Falls back to null when we don't have the user's
    // geolocation OR the master lacks coordinates.
    final me = ref.watch(currentLocationProvider).asData?.value;
    final double? km = (me != null && barber.lat != null && barber.lng != null)
        ? haversineKm(me, LatLng(barber.lat!, barber.lng!))
        : null;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: EdgeInsets.zero,
      radius: AppRadius.lg,
      onTap: () => context.push('/barber/${barber.id}'),
      child: ClipRRect(
        borderRadius: AppRadius.rLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header — gallery photo (or fallback avatar as bg) + bookmark
            // + status badge. Cleaner than the old avatar-overlap trick
            // that caused the "random emoji" artefact users reported.
            AspectRatio(
              aspectRatio: 1.35,
              child: Stack(fit: StackFit.expand, children: [
                _HeaderMedia(
                  gallery: firstGallery,
                  avatarUrl: avatarUrl,
                  name: barber.name,
                ),
                // Dark scrim so bookmark + badge stay readable on light
                // gallery photos.
                const _HeaderScrim(),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: TapScale(
                    scale: 0.85,
                    onTap: () => ref
                        .read(favoritesControllerProvider.notifier)
                        .toggleOptimistic(barber.id),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.bookmark : Icons.bookmark_border,
                        size: 17,
                        color: isFav ? Colors.white : Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: AppBadge(
                    label: barber.isAvailable
                        ? tr(ref, 'barbers.available', "Bo'sh")
                        : tr(ref, 'barbers.unavailable', "Band"),
                    variant: barber.isAvailable
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.neutral,
                    dot: true,
                  ),
                ),
              ]),
            ),
            // Body — no more Transform.translate; content sits neatly
            // under the header.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    barber.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleSm,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star,
                        size: 12, color: Color(0xFFFBBF24)),
                    AppSpacing.hGapXs,
                    Text(
                      barber.rating.toStringAsFixed(1),
                      style: AppText.caption.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.hGapXs,
                    Text('(${barber.reviewCount})',
                        style: AppText.caption),
                    if (km != null) ...[
                      AppSpacing.hGapSm,
                      _DistancePill(km: km),
                    ],
                  ]),
                  if (barber.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: AppColors.textMuted),
                      AppSpacing.hGapXs,
                      Expanded(
                        child: Text(
                          barber.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _BookNowButton(barberId: barber.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card header media. Prefers the barber's first gallery photo; falls
/// back to the avatar zoomed in as a moody background; falls back again
/// to a monogram-on-gradient tile so a card without any imagery still
/// looks intentional instead of an empty dark rectangle.
class _HeaderMedia extends StatelessWidget {
  const _HeaderMedia({
    required this.gallery,
    required this.avatarUrl,
    required this.name,
  });
  final String gallery;
  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    if (gallery.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: assetUrl(gallery),
        fit: BoxFit.cover,
        placeholder: (_, _) => const _MonogramFallback(name: '?'),
        errorWidget: (_, _, _) => _MonogramFallback(name: name),
      );
    }
    if (avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => const _MonogramFallback(name: '?'),
        errorWidget: (_, _, _) => _MonogramFallback(name: name),
      );
    }
    return _MonogramFallback(name: name);
  }
}

/// Dark bottom-to-top scrim so bookmark + status pills stay readable
/// on top of light gallery photos.
class _HeaderScrim extends StatelessWidget {
  const _HeaderScrim();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.25),
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
    );
  }
}

/// Monogram-on-gradient tile used when no image is available. Fills the
/// full header area so the card never has an empty dark rectangle.
class _MonogramFallback extends StatelessWidget {
  const _MonogramFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppText.display.copyWith(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Small distance chip shown next to the rating on each barber card
/// when the user's geolocation is available. Under 1 km shows metres;
/// otherwise rounded km.
class _DistancePill extends StatelessWidget {
  const _DistancePill({required this.km});
  final double km;

  String get _label {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me, size: 10, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            _label,
            style: AppText.overline.copyWith(
              color: AppColors.primary,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact primary CTA on each barber card — jumps straight into the
/// booking flow so the customer skips one navigation step.
class _BookNowButton extends ConsumerWidget {
  const _BookNowButton({required this.barberId});
  final String barberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TapScale(
      onTap: () {
        AppHaptics.selection();
        context.push('/barber/$barberId/book');
      },
      scale: 0.96,
      child: Container(
        height: 32,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: AppRadius.rSm,
          boxShadow: AppShadows.primaryGlow(AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month,
                size: 14, color: Colors.white),
            AppSpacing.hGapXs,
            Text(
              tr(ref, 'booking.title', 'Yozilish'),
              style: AppText.button.copyWith(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Loading grid — proper skeleton (not just blank shimmer)
// ─────────────────────────────────────────────────────────────────────────
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.72,
        ),
        itemCount: 6,
        itemBuilder: (context, _) => const SkeletonBarberCard(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 380,
      child: AppEmptyState(
        icon: Icons.content_cut_rounded,
        title: tr(ref, 'barbers.noBarbers', "Sartarosh topilmadi"),
        message: tr(
          ref,
          'barbers.noBarbersHint',
          "Filtrni o'zgartirib ko'ring yoki qidiruvni tozalang.",
        ),
      ),
    );
  }
}
