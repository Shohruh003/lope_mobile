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
  String _sort = 'rating'; // 'rating' | 'name' | 'experience' | 'price' | 'distance'
  String _gender = 'ALL'; // 'ALL' | 'MALE' | 'FEMALE'
  bool _filterDefaulted = false;

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

  bool get _tunerActive => _sort != 'rating' || _gender != 'ALL';

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
                if (!_filterDefaulted) {
                  final favs =
                      ref.read(favoritesProvider).asData?.value ?? const [];
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
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AppChip(
                    label: favoritesLabel,
                    selected: filter == 'favorites',
                    leadingIcon: Icons.favorite,
                    onTap: () => onFilter('favorites'),
                  ),
                  AppSpacing.hGapSm,
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
    final favsAsync = ref.watch(favoritesProvider);
    final isFav = favsAsync.maybeWhen<bool>(
        data: (l) => l.any((b) => b.id == barber.id), orElse: () => false);

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
            // Header — gallery photo + heart + status
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
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: TapScale(
                    scale: 0.85,
                    onTap: () async {
                      try {
                        await ref
                            .read(favoritesRepositoryProvider)
                            .toggle(barber.id);
                        ref.invalidate(favoritesProvider);
                      } catch (_) {}
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFav ? AppColors.danger : Colors.white,
                      ),
                    ),
                  ),
                ),
                // Status badge top-right
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
                // Gender preference indicator (bottom-left)
                if (barber.targetGender != null)
                  Positioned(
                    bottom: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: AppRadius.rPill,
                      ),
                      child: Text(
                        barber.targetGender == 'MALE_ONLY' ? '👨' : '👩',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
              ]),
            ),
            // Body — avatar overlaps
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.subtle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: ClipOval(
                          child: avatarUrl.isEmpty
                              ? _AvatarFallback(name: barber.name)
                              : CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const SkeletonCircle(size: 44),
                                  errorWidget: (context, url, err) =>
                                      _AvatarFallback(name: barber.name),
                                ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text(
                              '(${barber.reviewCount})',
                              style: AppText.caption,
                            ),
                          ]),
                          if (barber.location.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 12, color: AppColors.textMuted),
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
                        ],
                      ),
                    ),
                  ],
                ),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppText.titleMd.copyWith(color: Colors.white),
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
