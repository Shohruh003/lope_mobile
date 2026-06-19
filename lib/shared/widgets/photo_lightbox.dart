import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Fullscreen image viewer used across barbershop / barber / gallery pages.
///
/// Mirrors the web's lightbox: swipe-paged carousel, pinch-zoom on each frame,
/// counter pill, prev/next chevrons, close. Lives in shared/ so every page
/// presents the same UX instead of each one rolling its own.
class PhotoLightbox extends StatefulWidget {
  const PhotoLightbox({super.key, required this.images, this.start = 0});
  final List<String> images;
  final int start;

  /// Imperative push helper. Call from any image's onTap.
  static Future<void> show(BuildContext context, List<String> images, int start) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoLightbox(images: images, start: start),
    ));
  }

  @override
  State<PhotoLightbox> createState() => _PhotoLightboxState();
}

class _PhotoLightboxState extends State<PhotoLightbox> {
  late final PageController _ctrl;
  late int _i;

  @override
  void initState() {
    super.initState();
    _i = widget.start;
    _ctrl = PageController(initialPage: widget.start);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (context, i) => InteractiveViewer(
            minScale: 1, maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.images[i],
                fit: BoxFit.contain,
                placeholder: (context, _) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (context, _, _) =>
                    const Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 60),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                "${_i + 1} / ${widget.images.length}",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        if (_i > 0)
          Positioned(
            left: 4,
            top: 0, bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Colors.white, size: 32),
                onPressed: () => _ctrl.previousPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut),
              ),
            ),
          ),
        if (_i < widget.images.length - 1)
          Positioned(
            right: 4,
            top: 0, bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.chevron_right,
                    color: Colors.white, size: 32),
                onPressed: () => _ctrl.nextPage(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut),
              ),
            ),
          ),
      ]),
    );
  }
}
