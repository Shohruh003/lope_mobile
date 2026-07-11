import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/shared.dart';
import 'tr.dart';

/// Thin wrapper around image_picker that lets callers pop a "kameradan
/// olishmi yoki galereyadanmi" sheet without rebuilding the same chooser
/// across every upload screen.
class ImagePickerService {
  ImagePickerService._();
  static final instance = ImagePickerService._();
  final _picker = ImagePicker();

  Future<File?> pickFromSheet(BuildContext context,
      {bool allowCamera = true, WidgetRef? ref}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final colors = sheetCtx.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    ref == null
                        ? "Rasm manbasini tanlang"
                        : tr(ref, 'mobile.imagePicker.title',
                            "Rasm manbasini tanlang"),
                    style: AppText.titleSm,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ref == null
                        ? "Qayerdan rasm olmoqchisiz?"
                        : tr(ref, 'mobile.imagePicker.subtitle',
                            "Qayerdan rasm olmoqchisiz?"),
                    style:
                        AppText.bodySm.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  if (allowCamera) ...[
                    _SourceTile(
                      icon: Icons.camera_alt_rounded,
                      title: ref == null
                          ? "Kamera"
                          : tr(ref, 'mobile.imagePicker.camera', "Kamera"),
                      subtitle: ref == null
                          ? "Hozir yangi rasm oling"
                          : tr(ref, 'mobile.imagePicker.cameraHint',
                              "Hozir yangi rasm oling"),
                      onTap: () =>
                          Navigator.of(sheetCtx).pop(ImageSource.camera),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _SourceTile(
                    icon: Icons.photo_library_rounded,
                    title: ref == null
                        ? "Galereya"
                        : tr(ref, 'mobile.imagePicker.gallery', "Galereya"),
                    subtitle: ref == null
                        ? "Mavjud rasmlardan tanlang"
                        : tr(ref, 'mobile.imagePicker.galleryHint',
                            "Mavjud rasmlardan tanlang"),
                    onTap: () =>
                        Navigator.of(sheetCtx).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null) return null;
    try {
      final res = await _picker.pickImage(
          source: source, maxWidth: 2048, imageQuality: 85);
      return res == null ? null : File(res.path);
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> pickMulti({int? limit}) async {
    try {
      final res =
          await _picker.pickMultiImage(maxWidth: 2048, imageQuality: 85);
      final picked = res.map((x) => File(x.path)).toList();
      if (limit != null && picked.length > limit) {
        return picked.sublist(0, limit);
      }
      return picked;
    } catch (_) {
      return [];
    }
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TapScale(
      onTap: onTap,
      scale: 0.97,
      haptic: HapticStrength.selection,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.primaryGlow(AppColors.primary),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodyLg
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      AppText.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: colors.textMuted),
        ]),
      ),
    );
  }
}
