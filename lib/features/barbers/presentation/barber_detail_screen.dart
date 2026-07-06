import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/asset_url.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/photo_lightbox.dart';
import '../../../shared/widgets/shadcn.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../reviews/data/reviews_repository.dart';
import '../data/barber_repository.dart';
import '../domain/barber.dart';

/// Mirrors `CustomerBarberDetailScreen.tsx` 1:1.
///
/// Layout:
///   - Sticky back-arrow + Heart button bar at top
///   - Header row: 80px avatar + name+heart+badge + experience row + rating
///   - Bio paragraph (if present)
///   - "Bron qilish" full-width primary button
///   - 4 tabs: Aloqa / Xizmatlar / Galereya / Sharhlar
///     · Aloqa → Working hours card + Location card (with Yo'l/Xaritada
///       tugmalari) + Social links card (IG/TG/FB)
///     · Xizmatlar → list with price+duration
///     · Galereya → image grid, tap → lightbox with prev/next
///     · Sharhlar → cards with star rating + comment + date
class BarberDetailScreen extends ConsumerStatefulWidget {
  const BarberDetailScreen({super.key, required this.barberId});
  final String barberId;
  @override
  ConsumerState<BarberDetailScreen> createState() => _BarberDetailScreenState();
}

class _BarberDetailScreenState extends ConsumerState<BarberDetailScreen> {
  int _tab = 0; // 0=contact, 1=services, 2=gallery, 3=reviews
  bool? _favoritedOverride; // null = use server snapshot, true/false = optimistic
  bool _favoriteBusy = false;

  String _avatarUrl(String a) => assetUrl(a);

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    try {
      final next = await ref
          .read(favoritesRepositoryProvider)
          .toggle(widget.barberId);
      if (!mounted) return;
      setState(() => _favoritedOverride = next);
      ref.invalidate(favoritesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
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
        loading: () => const AppListSkeleton(),
        error: (e, _) =>
            Center(child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}", style: const TextStyle(color: AppColors.textMuted))),
        data: (b) => _content(b),
      ),
    );
  }

  Widget _content(Barber b) {
    final reviewsAsync = ref.watch(barberReviewsProvider(widget.barberId));
    return SafeArea(
      child: Column(children: [
        // ===== Sticky top bar =====
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
              onPressed: () => context.pop(),
            ),
            const Spacer(),
            Consumer(builder: (context, ref, _) {
              final favoritesAsync = ref.watch(favoritesProvider);
              final bool isFav = _favoritedOverride ??
                  favoritesAsync.maybeWhen<bool>(
                      data: (l) => l.any((b) => b.id == widget.barberId),
                      orElse: () => false);
              return IconButton(
                icon: _favoriteBusy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textPrimary))
                    : Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? AppColors.danger : AppColors.textPrimary,
                        size: 20),
                onPressed: _favoriteBusy ? null : _toggleFavorite,
              );
            }),
          ]),
        ),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 16),
              // ===== Header row =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipOval(
                      child: _avatarUrl(b.avatar).isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _avatarUrl(b.avatar),
                              width: 80, height: 80,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, err) =>
                                  _AvatarFallback(name: b.name),
                            )
                          : _AvatarFallback(name: b.name),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(b.name,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textBright)),
                            ),
                            // VIP crown badge (only when active)
                            if (b.isVip) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFEF3C7), Color(0xFFFBBF24)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.workspace_premium,
                                      size: 11, color: Color(0xFFA16207)),
                                  SizedBox(width: 3),
                                  Text("VIP",
                                      style: TextStyle(
                                          color: Color(0xFFA16207),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5)),
                                ]),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: (b.isAvailable
                                        ? AppColors.success
                                        : AppColors.textMuted)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                b.isAvailable
                                    ? tr(ref, 'barbers.available', "Bo'sh")
                                    : tr(ref, 'barbers.unavailable', "Band"),
                                style: TextStyle(
                                  color: b.isAvailable ? AppColors.success : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                          if (b.experience != null) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Text("${b.experience} ${tr(ref, 'barbers.experience', 'yil tajriba')}",
                                  style: const TextStyle(
                                      fontSize: 14, color: AppColors.textMuted)),
                            ]),
                          ],
                          const SizedBox(height: 6),
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
                            const SizedBox(width: 4),
                            Text(b.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textBright)),
                            const SizedBox(width: 4),
                            Text("(${b.reviewCount})",
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (b.bio.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(b.bio,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.5)),
                ),
              ],

              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(tr(ref, 'barbers.bookAppointment', "Bron qilish"),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    onPressed: b.isAvailable
                        ? () => context.push('/book/${b.id}')
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 18),
              // ===== Tabs strip =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: List.generate(4, (i) {
                    final labels = [
                      tr(ref, 'barbers.contact', 'Aloqa'),
                      tr(ref, 'barbers.services', 'Xizmatlar'),
                      tr(ref, 'barbers.gallery', 'Galereya'),
                      tr(ref, 'barbers.reviewsTab', 'Sharhlar'),
                    ];
                    final on = i == _tab;
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _tab = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: on ? AppColors.background : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: on ? Border.all(color: AppColors.border) : null,
                          ),
                          child: Center(
                            child: Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                                color: on ? AppColors.textBright : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  })),
                ),
              ),

              const SizedBox(height: 14),

              // ===== Tab content =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: switch (_tab) {
                  0 => _contactTab(b),
                  1 => _servicesTab(b),
                  2 => _galleryTab(b),
                  _ => _reviewsTab(reviewsAsync),
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ]),
    );
  }

  // ===== Aloqa (Contact) =====
  Widget _contactTab(Barber b) {
    return Column(children: [
      // Working hours card
      ShadCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.access_time, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(tr(ref, 'barbers.workingHours', "Ish soatlari"),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright)),
          ]),
          const SizedBox(height: 8),
          ..._workingHoursRows(b.workingHours),
        ]),
      ),
      const SizedBox(height: 12),

      // Location card
      ShadCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(b.location.isEmpty
                      ? tr(ref, 'barbers.locationNotSet', "Manzil ko'rsatilmagan")
                      : b.location,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textBright)),
            ),
          ]),
          if (b.lat != null && b.lng != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text("${b.lat!.toStringAsFixed(6)}, ${b.lng!.toStringAsFixed(6)}",
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.textMuted)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.navigation, size: 16),
                    label: Text(tr(ref, 'barberApp.route', "Yo'l"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => _openRoute(b),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(tr(ref, 'barberApp.viewOnMap', "Xaritada"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () => _openMap(b),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),

      // Social links — only when any present
      if ((b.instagram?.isNotEmpty ?? false) ||
          (b.telegram?.isNotEmpty ?? false) ||
          (b.facebook?.isNotEmpty ?? false)) ...[
        const SizedBox(height: 10),
        ShadCard(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (b.instagram?.isNotEmpty ?? false)
              _socialRow(
                bgColor: const Color(0xFFE1306C),
                icon: Icons.camera_alt,
                handle: "@${b.instagram}",
                onTap: () => _openUrl("https://instagram.com/${b.instagram}"),
              ),
            if (b.telegram?.isNotEmpty ?? false) ...[
              if (b.instagram?.isNotEmpty ?? false) const SizedBox(height: 10),
              _socialRow(
                bgColor: const Color(0xFF2AABEE),
                icon: Icons.send,
                handle: "@${b.telegram}",
                onTap: () => _openUrl("https://t.me/${b.telegram}"),
              ),
            ],
            if (b.facebook?.isNotEmpty ?? false) ...[
              if ((b.instagram?.isNotEmpty ?? false) || (b.telegram?.isNotEmpty ?? false))
                const SizedBox(height: 10),
              _socialRow(
                bgColor: const Color(0xFF1877F2),
                icon: Icons.facebook,
                handle: b.facebook!,
                onTap: () => _openUrl("https://facebook.com/${b.facebook}"),
              ),
            ],
          ]),
        ),
      ],
    ]);
  }

  List<Widget> _workingHoursRows(Map<String, dynamic>? wh) {
    const dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayFallback = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
    final dayNames = trList(ref, 'mobile.dates.weekDaysLong', dayFallback);
    return List.generate(dayKeys.length, (i) {
      final entry = wh?[dayKeys[i]] as Map<String, dynamic>?;
      final isOpen = entry?['isOpen'] == true;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
            child: Text(dayNames[i],
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          Text(
            isOpen
                ? "${entry!['open'] ?? '—'} - ${entry['close'] ?? '—'}"
                : tr(ref, 'barbers.closed', "Yopiq"),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOpen ? AppColors.textBright : AppColors.textMuted,
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
    return InkWell(
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: bgColor, size: 16),
        ),
        const SizedBox(width: 12),
        Text(handle,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textBright)),
      ]),
    );
  }

  Future<void> _openRoute(Barber b) async {
    if (b.lat == null || b.lng == null) return;
    final url = "https://yandex.uz/maps/?pt=${b.lng},${b.lat}&z=16";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMap(Barber b) async {
    if (b.lat == null || b.lng == null) return;
    final url = "https://yandex.uz/maps/?pt=${b.lng},${b.lat}&z=16";
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ===== Xizmatlar (Services) =====
  Widget _servicesTab(Barber b) {
    if (b.services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(tr(ref, 'profile.noServices', "Xizmatlar ro'yxati bo'sh"),
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return Column(
      children: b.services
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShadCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Text(s.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                  color: AppColors.textBright)),
                          const SizedBox(height: 2),
                          Text("${s.duration} ${tr(ref, 'booking.duration', 'daq')}",
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(
                        s.priceMax != null && s.priceMax! > s.price
                            ? "${_fmt(s.price)} – ${_fmt(s.priceMax!)} ${tr(ref, 'common.currency', "so'm")}"
                            : "${_fmt(s.price)} ${tr(ref, 'common.currency', "so'm")}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontSize: 14)),
                  ]),
                ),
              ))
          .toList(),
    );
  }

  // ===== Galereya (Gallery) =====
  Widget _galleryTab(Barber b) {
    if (b.gallery.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(tr(ref, 'profile.noGallery', "Portfolio bo'sh"),
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: b.gallery.length,
      itemBuilder: (context, i) {
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openLightbox(b.gallery, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: _avatarUrl(b.gallery[i]),
              fit: BoxFit.cover,
              placeholder: (context, _) =>
                  Container(color: AppColors.surfaceElevated),
              errorWidget: (context, _, _) =>
                  Container(color: AppColors.surfaceElevated),
            ),
          ),
        );
      },
    );
  }

  void _openLightbox(List<String> images, int start) {
    PhotoLightbox.show(context, images, start);
  }

  // ===== Sharhlar (Reviews) =====
  Widget _reviewsTab(AsyncValue<List<Review>> async) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}",
            style: const TextStyle(color: AppColors.textMuted)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(tr(ref, 'barbers.noReviews', "Sharhlar yo'q"),
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          );
        }
        return Column(
          children: list
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ShadCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                    r.userName.isEmpty ? 'Mijoz' : r.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                        color: AppColors.textBright)),
                              ),
                              Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                            i < r.rating ? Icons.star : Icons.star_border,
                                            size: 12,
                                            color: i < r.rating
                                                ? const Color(0xFFFBBF24)
                                                : AppColors.textMuted,
                                          ))),
                            ]),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(r.comment,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                      height: 1.4)),
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

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text((name.isNotEmpty ? name[0] : '?').toUpperCase(),
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 30,
              fontWeight: FontWeight.w700)),
    );
  }
}

