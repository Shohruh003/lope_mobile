import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/asset_url.dart';
import '../shared.dart';

/// Circular avatar for a booking client — a `CachedNetworkImage` when
/// the registered client has uploaded a photo, otherwise a gradient
/// monogram of their first initial. Both branches produce the same
/// visual footprint so lists don't jitter as network images resolve.
///
/// Kept generic (name + optional avatar path) so any list that ends
/// up rendering booking rows can share one avatar treatment — the
/// schedule screen's 'Bugungi bronlar' list, the bookings tab's
/// [BookingTile], and any future places all pull the same widget.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar({
    super.key,
    required this.name,
    this.avatar,
    this.size = 40,
    this.ring = false,
  });

  final String name;

  /// Relative asset path returned by the backend (e.g.
  /// `uploads/avatars/...`). Passed through `assetUrl` so it resolves
  /// against the API's base URL. Empty or null → fallback monogram.
  final String? avatar;

  /// Overall diameter of the avatar circle.
  final double size;

  /// When true, wraps the image in a 2px primary-gradient ring — used
  /// by the barber panel's booking list rows so the client visually
  /// pops against the tile background.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initial =
        (name.isNotEmpty ? name[0] : '?').toUpperCase();
    final hasAvatar = avatar != null && avatar!.isNotEmpty;

    final inner = SizedBox(
      width: ring ? size - 4 : size,
      height: ring ? size - 4 : size,
      child: ClipOval(
        child: hasAvatar
            ? CachedNetworkImage(
                imageUrl: assetUrl(avatar!),
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    _Monogram(initial: initial, size: size),
                errorWidget: (_, _, _) =>
                    _Monogram(initial: initial, size: size),
              )
            : _Monogram(initial: initial, size: size),
      ),
    );

    if (!ring) return inner;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(child: inner),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(gradient: AppColors.primaryGradient),
      child: Text(
        initial,
        style: AppText.titleSm.copyWith(
          color: Colors.white,
          // Scale the initial with the container size so an 80px
          // avatar isn't stuck at the default 16pt.
          fontSize: (size * 0.42).clamp(14, 32),
        ),
      ),
    );
  }
}
