import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/errors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/asset_url.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/theme/colors.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/photo_lightbox.dart';
import '../data/barber_profile_repository.dart';

/// Portfolio uploader. Pulls current gallery from /barbers/:id, lets barber
/// add multiple from device library or delete any existing URL.
class BarberGalleryScreen extends ConsumerStatefulWidget {
  const BarberGalleryScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BarberGalleryScreen> createState() => _BarberGalleryScreenState();
}

class _BarberGalleryScreenState extends ConsumerState<BarberGalleryScreen> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final files = await ImagePickerService.instance.pickMulti(limit: 10);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await ref.read(barberProfileRepositoryProvider).uploadGallery(widget.barberId, files);
      ref.invalidate(barberProfileProvider(widget.barberId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'mobile.barber.gallery.uploadError',
                'Yuklashda xato: {{msg}}', {'msg': '$e'}))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(String url) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr(ref, 'mobile.barber.gallery.deleteTitle', "Rasmni o'chirish?")),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(false),
              child: Text(tr(ref, 'common.cancel', "Bekor"))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: Text(tr(ref, 'common.delete', "O'chirish")),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(barberProfileRepositoryProvider).deleteGalleryImage(widget.barberId, url);
      ref.invalidate(barberProfileProvider(widget.barberId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'mobile.barber.gallery.title', "Portfolio"))),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(tr(ref, 'mobile.barber.gallery.addBtn', "Qo'shish")),
      ),
      body: async.when(
        loading: () => const AppListSkeleton(),
        error: (e, _) => AppErrorState(message: humanize(e)),
        data: (barber) {
          final gallery = ((barber['gallery'] as List?) ?? [])
              .map((e) => e.toString())
              .where((u) => u.isNotEmpty)
              .toList();
          if (gallery.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    Text(tr(ref, 'mobile.barber.gallery.empty', "Portfolio bo'sh"),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3)),
                    const SizedBox(height: 6),
                    Text(tr(ref, 'mobile.barber.gallery.emptyHint', "Ishlaringizdan rasm yuklang"),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: gallery.length,
            itemBuilder: (context, i) {
              final url = gallery[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: GestureDetector(
                      onTap: () => PhotoLightbox.show(
                          context, gallery.cast<String>(), i),
                      child: CachedNetworkImage(
                        imageUrl: assetUrl(url),
                        fit: BoxFit.cover,
                        placeholder: (context, _) => Container(color: AppColors.surface),
                        errorWidget: (context, _, _) =>
                            Container(color: AppColors.surface, child: const Icon(Icons.broken_image, color: AppColors.textMuted)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: InkWell(
                      onTap: () => _delete(url),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 250.ms, delay: (i * 30).ms);
            },
          );
        },
      ),
    );
  }
}
