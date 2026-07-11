import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/asset_url.dart';
import '../../../core/errors.dart';
import '../../../core/image_picker_service.dart';
import '../../../core/tr.dart';
import '../../../shared/shared.dart';
import '../../../shared/widgets/app_states.dart';
import '../../../shared/widgets/photo_lightbox.dart';
import '../data/barber_profile_repository.dart';

class BarberGalleryScreen extends ConsumerStatefulWidget {
  const BarberGalleryScreen({super.key, required this.barberId});
  final String barberId;

  @override
  ConsumerState<BarberGalleryScreen> createState() =>
      _BarberGalleryScreenState();
}

class _BarberGalleryScreenState extends ConsumerState<BarberGalleryScreen> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    AppHaptics.light();
    final files = await ImagePickerService.instance.pickMulti(limit: 10);
    if (files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .uploadGallery(widget.barberId, files);
      AppHaptics.success();
      ref.invalidate(barberProfileProvider(widget.barberId));
    } catch (e) {
      AppHaptics.error();
      if (mounted) {
        // humanize turns Dio's opaque exceptions into readable Uzbek
        // messages — same treatment the _delete path already uses.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(ref, 'mobile.barber.gallery.uploadError',
                'Yuklashda xato: {{msg}}', {'msg': humanize(e)}))));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(String url) async {
    AppHaptics.light();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => Dialog(
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(ref, 'mobile.barber.gallery.deleteTitle',
                    "Rasmni o'chirish?"),
                style: AppText.titleMd,
              ),
              AppSpacing.gapSm,
              Text(
                tr(ref, 'mobile.barber.gallery.deleteBody',
                    "Rasm portfolyodan butunlay o'chiriladi. Bu jarayonni bekor qilib bo'lmaydi."),
                style: AppText.bodySm,
              ),
              AppSpacing.gapLg,
              Row(children: [
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.cancel', 'Bekor'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pop(dCtx, false),
                    fullWidth: true,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: AppButton(
                    label: tr(ref, 'common.delete', "O'chirish"),
                    variant: AppButtonVariant.danger,
                    onPressed: () => Navigator.pop(dCtx, true),
                    fullWidth: true,
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(barberProfileRepositoryProvider)
          .deleteGalleryImage(widget.barberId, url);
      ref.invalidate(barberProfileProvider(widget.barberId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "${tr(ref, 'common.error', 'Xatolik')}: ${humanize(e)}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(barberProfileProvider(widget.barberId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(ref, 'mobile.barber.gallery.title', 'Portfolio'),
          style: AppText.titleMd,
        ),
      ),
      floatingActionButton: TapScale(
        onTap: _uploading ? null : _pickAndUpload,
        scale: 0.94,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.rPill,
            boxShadow: AppShadows.primaryGlow(AppColors.primary),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add_a_photo_outlined,
                    color: Colors.white, size: 18),
            AppSpacing.hGapSm,
            Text(
              tr(ref, 'mobile.barber.gallery.addBtn', "Qo'shish"),
              style: AppText.button.copyWith(color: Colors.white),
            ),
          ]),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async =>
            ref.refresh(barberProfileProvider(widget.barberId).future),
        child: async.when(
          loading: () => const AppListSkeleton(),
          error: (e, _) => AppErrorState(message: humanize(e)),
          data: (barber) {
          final gallery = ((barber['gallery'] as List?) ?? [])
              .map((e) => e.toString())
              .where((u) => u.isNotEmpty)
              .toList();
          if (gallery.isEmpty) {
            // Scrollable wrapper so pull-to-refresh works on the empty
            // portfolio too — the barber can retry after a bad upload
            // without leaving the tab.
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 400,
                  child: AppEmptyState(
                    icon: Icons.photo_library_outlined,
                    title: tr(ref, 'mobile.barber.gallery.empty',
                        "Portfolio bo'sh"),
                    message: tr(ref, 'mobile.barber.gallery.emptyHint',
                        "Ishlaringizdan rasm yuklang — mijozlar sizni tanlashda yordam beradi."),
                  ),
                ),
              ],
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              96,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemCount: gallery.length,
            itemBuilder: (context, i) {
              final url = gallery[i];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.rMd,
                    child: TapScale(
                      onTap: () {
                        AppHaptics.light();
                        PhotoLightbox.show(
                            context, gallery.cast<String>(), i);
                      },
                      scale: 0.97,
                      child: CachedNetworkImage(
                        imageUrl: assetUrl(url),
                        fit: BoxFit.cover,
                        placeholder: (context, _) =>
                            const SkeletonRect(radius: AppRadius.md),
                        errorWidget: (context, _, _) => Container(
                          color: context.colors.surface,
                          child: Icon(Icons.broken_image,
                              color: context.colors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 0,
                    child: TapScale(
                      onTap: () => _delete(url),
                      scale: 0.85,
                      // Outer 44px hit area with a smaller visual pill —
                      // meets the Material touch-target minimum without
                      // stealing space from the thumbnail.
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 250.ms, delay: (i * 30).ms);
            },
          );
          },
        ),
      ),
    );
  }
}
