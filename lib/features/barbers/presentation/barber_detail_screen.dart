import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../shared/theme/colors.dart';
import '../data/barber_repository.dart';
import '../domain/barber.dart';

/// Barber detail — hero header, bio, services grid, "Bron qilish" CTA that
/// pushes to the booking flow.
class BarberDetailScreen extends ConsumerWidget {
  const BarberDetailScreen({super.key, required this.barberId});
  final String barberId;

  String _avatarUrl(String avatar) {
    if (avatar.isEmpty) return '';
    if (avatar.startsWith('http')) return avatar;
    return '${AppConfig.apiUrl}$avatar';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(barberDetailProvider(barberId));
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Yuklab bo'lmadi: $e")),
        data: (barber) => _Content(barber: barber, avatarUrl: _avatarUrl(barber.avatar)),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.barber, required this.avatarUrl});
  final Barber barber;
  final String avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppColors.background,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: const BackButton(color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (avatarUrl.isEmpty)
                      Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient))
                    else
                      CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, err) =>
                            Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
                      ),
                    // Bottom gradient — keeps the name + rating readable
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, AppColors.background.withValues(alpha: 0.95)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            barber.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 18),
                              const SizedBox(width: 4),
                              Text(barber.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(width: 4),
                              Text("(${barber.reviewCount} sharh)",
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  if (barber.location.isNotEmpty) ...[
                    _InfoRow(icon: Icons.location_on_outlined, text: barber.location),
                    const SizedBox(height: 8),
                  ],
                  if (barber.phone != null && barber.phone!.isNotEmpty)
                    _InfoRow(icon: Icons.phone_outlined, text: barber.phone!),
                  if (barber.bio.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text("Tavsif", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(barber.bio,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                  ],
                  const SizedBox(height: 24),
                  const Text("Xizmatlar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (barber.services.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text("Xizmatlar mavjud emas",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                    )
                  else
                    ...barber.services.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ServiceRow(service: s),
                        )),
                ]),
              ),
            ),
          ],
        ),

        // Floating CTA — sits above the scroll, always reachable
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: ElevatedButton(
              onPressed: barber.isAvailable
                  ? () => context.push('/book/${barber.id}')
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: barber.isAvailable ? AppColors.primary : AppColors.surfaceElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                barber.isAvailable ? "Bron qilish" : "Hozir mavjud emas",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .slideY(begin: 0.5, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary))),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});
  final BarberService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(service.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text("${service.duration} daqiqa",
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(
            "${_fmt(service.price)} so'm",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i;
      buf.write(s[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buf.write(' ');
    }
    return buf.toString();
  }
}
