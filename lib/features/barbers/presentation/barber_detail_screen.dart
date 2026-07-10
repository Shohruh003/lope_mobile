import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/photo_lightbox.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/barber_repository.dart';
import '../domain/barber.dart';

/// Redesigned barber detail screen. State/API preserved:
///   - favorite toggle with optimistic UI + rollback
///   - 4 tabs (Aloqa / Xizmatlar / Galereya / Sharhlar)
///   - Photo lightbox for gallery
///   - Yandex map for location
///   - Social links opened in external browser
class BarberDetailScreen extends ConsumerStatefulWidget {
  const BarberDetailScreen({super.key, required this.barberId});
  final String barberId;
  @override
  ConsumerState<BarberDetailScreen> createState() => _BarberDetailScreenState();
}

class _BarberDetailScreenState extends ConsumerState<BarberDetailScreen> {
  int _tab = 0; // 0=contact, 1=services, 2=gallery, 3=reviews
  bool? _favoritedOverride;
  bool _favoriteBusy = false;

  String _avatarUrl(String a) => assetUrl(a);

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    AppHaptics.light();
    setState(() => _favoriteBusy = true);
    try {
      final next =
          await ref.read(favoritesRepositoryProvider).toggle(widget.barberId);
      if (!mounted) return;
      setState(() => _favoritedOverride = next);
      ref.invalidate(favoritesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberDetailProvider(widget.barberId));
    return Scaffold(
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(
          message: humanize(e),
          onRetry: () => ref.invalidate(barberDetailProvider(widget.barberId)),
        ),
        data: (b) => _content(b),
      ),
    );
  }

  Widget _content(Barber b) {
    final reviewsAsync = ref.watch(barberReviewsProvider(widget.barberId));
    return SafeArea(
      child: Column(children: [
        // ===== Sticky top bar =====
        _TopBar(
          barberId: widget.barberId,
          favOverride: _favoritedOverride,
          busy: _favoriteBusy,
          onFavorite: _toggleFavorite,
          onBack: () => context.pop(),
        ),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppSpacing.gapLg,
              // ===== Header =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _HeaderRow(b: b, avatarUrl: _avatarUrl(b.avatar)),
              ),
              if (b.bio.isNotEmpty) ...[
                AppSpacing.gapLg,
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    b.bio,
                    style: AppText.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],

              AppSpacing.gapLg,

              // ===== CTA =====
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AppButton(
                  label: tr(ref, 'barbers.bookAppointment', 'Bron qilish'),
                  leadingIcon: Icons.calendar_today,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed:
                      b.isAvailable ? () => context.push('/book/${b.id}') : null,
                ),
              ),

              AppSpacing.gapLg,

              // ===== Tabs =====
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _TabsRow(
                  labels: [
                    tr(ref, 'barbers.contact', 'Aloqa'),
                    tr(ref, 'barbers.services', 'Xizmatlar'),
                    tr(ref, 'barbers.gallery', 'Galereya'),
                    tr(ref, 'barbers.reviewsTab', 'Sharhlar'),
                  ],
                  selected: _tab,
                  onChange: (i) => setState(() => _tab = i),
                ),
              ),

              AppSpacing.gapMd,

              // ===== Tab content =====
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: switch (_tab) {
                  0 => _contactTab(b),
                  1 => _servicesTab(b),
                  2 => _galleryTab(b),
                  _ => _reviewsTab(reviewsAsync),
                },
              ),
              AppSpacing.gapXxl,
            ],
          ),
        ),
      ]),
    );
  }

  // ─────────────────────── Aloqa (Contact) ───────────────────────
  Widget _contactTab(Barber b) {
    final hasSocials = (b.instagram?.isNotEmpty ?? false) ||
        (b.telegram?.isNotEmpty ?? false) ||
        (b.facebook?.isNotEmpty ?? false);
    return Column(children: [
      // Working hours card
      AppCard(
        variant: AppCardVariant.outlined,
        padding: AppSpacing.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.access_time,
                size: 16, color: AppColors.primary),
            AppSpacing.hGapSm,
            Text(tr(ref, 'barbers.workingHours', 'Ish soatlari'),
                style: AppText.titleSm),
          ]),
          AppSpacing.gapSm,
          ..._workingHoursRows(b.workingHours),
        ]),
      ),
      AppSpacing.gapMd,

      // Location card
      AppCard(
        variant: AppCardVariant.outlined,
        padding: AppSpacing.cardPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined,
                size: 16, color: AppColors.primary),
            AppSpacing.hGapSm,
            Expanded(
              child: Text(
                b.location.isEmpty
                    ? tr(ref, 'barbers.locationNotSet',
                        "Manzil ko'rsatilmagan")
                    : b.location,
                style: AppText.body,
              ),
            ),
          ]),
          if (b.lat != null && b.lng != null) ...[
            AppSpacing.gapMd,
            Row(children: [
              Expanded(
                child: AppButton(
                  label: tr(ref, 'barberApp.route', "Yo'l"),
                  leadingIcon: Icons.navigation,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  fullWidth: true,
                  onPressed: () => _openRoute(b),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: AppButton(
                  label: tr(ref, 'barberApp.viewOnMap', 'Xaritada'),
                  leadingIcon: Icons.open_in_new,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  fullWidth: true,
                  onPressed: () => _openMap(b),
                ),
              ),
            ]),
          ],
        ]),
      ),

      if (hasSocials) ...[
        AppSpacing.gapMd,
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppSpacing.cardPadding,
          child: Column(children: [
            if (b.instagram?.isNotEmpty ?? false)
              _socialRow(
                bgColor: const Color(0xFFE1306C),
                icon: Icons.camera_alt,
                handle: '@${b.instagram}',
                onTap: () => _openUrl('https://instagram.com/${b.instagram}'),
              ),
            if (b.telegram?.isNotEmpty ?? false) ...[
              if (b.instagram?.isNotEmpty ?? false) AppSpacing.gapSm,
              _socialRow(
                bgColor: const Color(0xFF2AABEE),
                icon: Icons.send,
                handle: '@${b.telegram}',
                onTap: () => _openUrl('https://t.me/${b.telegram}'),
              ),
            ],
            if (b.facebook?.isNotEmpty ?? false) ...[
              if ((b.instagram?.isNotEmpty ?? false) ||
                  (b.telegram?.isNotEmpty ?? false))
                AppSpacing.gapSm,
              _socialRow(
                bgColor: const Color(0xFF1877F2),
                icon: Icons.facebook,
                handle: b.facebook!,
                onTap: () => _openUrl('https://facebook.com/${b.facebook}'),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }

  List<Widget> _workingHoursRows(Map<String, dynamic>? wh) {
    const dayKeys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    const dayFallback = [
      'Dushanba',
      'Seshanba',
      'Chorshanba',
      'Payshanba',
      'Juma',
      'Shanba',
      'Yakshanba'
    ];
    final dayNames = trList(ref, 'mobile.dates.weekDaysLong', dayFallback);
    return List.generate(dayKeys.length, (i) {
      final entry = wh?[dayKeys[i]] as Map<String, dynamic>?;
      final isOpen = entry?['isOpen'] == true;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(dayNames[i], style: AppText.caption)),
          Text(
            isOpen
                ? "${entry!['open'] ?? '—'} - ${entry['close'] ?? '—'}"
                : tr(ref, 'barbers.closed', 'Yopiq'),
            style: AppText.caption.copyWith(
              color: isOpen ? AppColors.textBright : AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      );
    });
  }

  Widget _socialRow({
    required Color bgColor,
    required IconData icon,
    required String handle,
    required VoidCallback onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: bgColor, size: 16),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Text(handle,
              style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
        ),
        const Icon(Icons.arrow_forward_ios,
            size: 12, color: AppColors.textMuted),
      ]),
    );
  }

  Future<void> _openRoute(Barber b) async {
    if (b.lat == null || b.lng == null) return;
    AppHaptics.light();
    final url = 'https://yandex.uz/maps/?pt=${b.lng},${b.lat}&z=16';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMap(Barber b) async {
    if (b.lat == null || b.lng == null) return;
    AppHaptics.light();
    final url = 'https://yandex.uz/maps/?pt=${b.lng},${b.lat}&z=16';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return;
    AppHaptics.light();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────── Xizmatlar (Services) ───────────────────────
  Widget _servicesTab(Barber b) {
    if (b.services.isEmpty) {
      return SizedBox(
        height: 220,
        child: AppEmptyState(
          icon: Icons.content_cut_rounded,
          title: tr(ref, 'profile.noServices', "Xizmatlar ro'yxati bo'sh"),
        ),
      );
    }
    return Column(
      children: b.services
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  variant: AppCardVariant.outlined,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  onTap: () {},
                  child: Row(children: [
                    Text(s.icon, style: const TextStyle(fontSize: 26)),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: AppText.titleSm),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.access_time_outlined,
                                size: 11, color: AppColors.textMuted),
                            AppSpacing.hGapXs,
                            Text(
                              "${s.duration} ${tr(ref, 'booking.duration', 'daq')}",
                              style: AppText.caption,
                            ),
                          ]),
                        ],
                      ),
                    ),
                    AppSpacing.hGapSm,
                    Text(
                      s.priceMax != null && s.priceMax! > s.price
                          ? "${_fmt(s.price)} – ${_fmt(s.priceMax!)} ${tr(ref, 'common.currency', "so'm")}"
                          : "${_fmt(s.price)} ${tr(ref, 'common.currency', "so'm")}",
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
              ))
          .toList(),
    );
  }

  // ─────────────────────── Galereya ───────────────────────
  Widget _galleryTab(Barber b) {
    if (b.gallery.isEmpty) {
      return SizedBox(
        height: 220,
        child: AppEmptyState(
          icon: Icons.photo_library_outlined,
          title: tr(ref, 'profile.noGallery', "Portfolio bo'sh"),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
      ),
      itemCount: b.gallery.length,
      itemBuilder: (context, i) {
        return TapScale(
          onTap: () => _openLightbox(b.gallery, i),
          scale: 0.97,
          child: ClipRRect(
            borderRadius: AppRadius.rMd,
            child: CachedNetworkImage(
              imageUrl: _avatarUrl(b.gallery[i]),
              fit: BoxFit.cover,
              placeholder: (_, _) => const SkeletonRect(radius: AppRadius.md),
              errorWidget: (_, _, _) => Container(
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: AppColors.textMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openLightbox(List<String> images, int start) {
    AppHaptics.light();
    PhotoLightbox.show(context, images, start);
  }

  // ─────────────────────── Sharhlar (Reviews) ───────────────────────
  Widget _reviewsTab(AsyncValue<List<Review>> async) {
    return async.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: const SkeletonRect(height: 72, radius: AppRadius.md),
              )),
        ),
      ),
      error: (e, _) => SizedBox(
        height: 200,
        child: AppErrorState(message: humanize(e)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return SizedBox(
            height: 220,
            child: AppEmptyState(
              icon: Icons.rate_review_outlined,
              title: tr(ref, 'barbers.noReviews', "Sharhlar yo'q"),
            ),
          );
        }
        return Column(
          children: list
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      variant: AppCardVariant.outlined,
                      padding: AppSpacing.cardPadding,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  r.userName.isEmpty ? 'Mijoz' : r.userName,
                                  style: AppText.titleSm,
                                ),
                              ),
                              Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                            i < r.rating
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 12,
                                            color: i < r.rating
                                                ? const Color(0xFFFBBF24)
                                                : AppColors.textMuted,
                                          ))),
                            ]),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                r.comment,
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ]),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  String _fmt(int n) {
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

// ─────────────────────────────────────────────────────────────────────────
// Top bar with back + favorite
// ─────────────────────────────────────────────────────────────────────────
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.barberId,
    required this.favOverride,
    required this.busy,
    required this.onFavorite,
    required this.onBack,
  });
  final String barberId;
  final bool? favOverride;
  final bool busy;
  final VoidCallback onFavorite;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final bool isFav = favOverride ??
        favoritesAsync.maybeWhen<bool>(
            data: (l) => l.any((b) => b.id == barberId), orElse: () => false);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _CircleButton(
          icon: Icons.arrow_back,
          onTap: onBack,
        ),
        const Spacer(),
        busy
            ? const SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textPrimary),
                  ),
                ),
              )
            : _CircleButton(
                icon: isFav ? Icons.favorite : Icons.favorite_border,
                iconColor: isFav ? AppColors.danger : AppColors.textPrimary,
                onTap: onFavorite,
              ),
      ]),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.textPrimary,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Header row — avatar + name + badges + rating
// ─────────────────────────────────────────────────────────────────────────
class _HeaderRow extends ConsumerWidget {
  const _HeaderRow({required this.b, required this.avatarUrl});
  final Barber b;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.primaryGlow(AppColors.primary),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SkeletonCircle(size: 76),
                    errorWidget: (_, _, _) => _AvatarFallback(name: b.name),
                  )
                : _AvatarFallback(name: b.name),
          ),
        ),
        AppSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    b.name,
                    style: AppText.titleLg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (b.isVip) ...[
                  AppSpacing.hGapXs,
                  const _VipBadge(),
                ],
              ]),
              AppSpacing.gapXs,
              AppBadge(
                label: b.isAvailable
                    ? tr(ref, 'barbers.available', "Bo'sh")
                    : tr(ref, 'barbers.unavailable', 'Band'),
                variant: b.isAvailable
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.neutral,
                dot: true,
              ),
              if (b.experience != null) ...[
                AppSpacing.gapSm,
                Row(children: [
                  const Icon(Icons.workspace_premium_outlined,
                      size: 14, color: AppColors.textMuted),
                  AppSpacing.hGapXs,
                  Text(
                    "${b.experience} ${tr(ref, 'barbers.experience', 'yil tajriba')}",
                    style: AppText.bodySm,
                  ),
                ]),
              ],
              AppSpacing.gapXs,
              Row(children: [
                ...List.generate(5, (i) {
                  final filled = i < b.rating.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 14,
                    color: filled
                        ? const Color(0xFFFBBF24)
                        : AppColors.textMuted,
                  );
                }),
                AppSpacing.hGapXs,
                Text(
                  b.rating.toStringAsFixed(1),
                  style: AppText.body.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.hGapXs,
                Text('(${b.reviewCount})', style: AppText.caption),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFBBF24)],
        ),
        borderRadius: AppRadius.rSm,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.workspace_premium,
            size: 11, color: Color(0xFFA16207)),
        AppSpacing.hGapXs,
        Text('VIP',
            style: AppText.caption.copyWith(
              color: const Color(0xFFA16207),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tab strip
// ─────────────────────────────────────────────────────────────────────────
class _TabsRow extends StatelessWidget {
  const _TabsRow({
    required this.labels,
    required this.selected,
    required this.onChange,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == selected;
          return Expanded(
            child: TapScale(
              onTap: () => onChange(i),
              haptic: HapticStrength.selection,
              scale: 0.97,
              child: AnimatedContainer(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: on ? AppColors.background : Colors.transparent,
                  borderRadius: AppRadius.rSm,
                  border: on ? Border.all(color: AppColors.border) : null,
                  boxShadow: on ? AppShadows.subtle : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: AppText.caption.copyWith(
                      fontSize: 12,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color:
                          on ? AppColors.textBright : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        (name.isNotEmpty ? name[0] : '?').toUpperCase(),
        style: AppText.titleLg.copyWith(color: Colors.white, fontSize: 30),
      ),
    );
  }
}
