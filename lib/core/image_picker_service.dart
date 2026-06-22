import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../shared/theme/colors.dart';
import 'tr.dart';

/// Thin wrapper around image_picker that lets callers pop a "kameradan
/// olishmi yoki galereyadanmi" sheet without rebuilding the same chooser
/// across every upload screen.
class ImagePickerService {
  ImagePickerService._();
  static final instance = ImagePickerService._();
  final _picker = ImagePicker();

  Future<File?> pickFromSheet(BuildContext context, {bool allowCamera = true, WidgetRef? ref}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (allowCamera)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: Text(ref == null
                    ? "Kamera"
                    : tr(ref, 'mobile.imagePicker.camera', "Kamera")),
                onTap: () => Navigator.of(sheetCtx).pop(ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: Text(ref == null
                  ? "Galereya"
                  : tr(ref, 'mobile.imagePicker.gallery', "Galereya")),
              onTap: () => Navigator.of(sheetCtx).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    try {
      final res = await _picker.pickImage(source: source, maxWidth: 2048, imageQuality: 85);
      return res == null ? null : File(res.path);
    } catch (_) {
      return null;
    }
  }

  Future<List<File>> pickMulti({int? limit}) async {
    try {
      final res = await _picker.pickMultiImage(maxWidth: 2048, imageQuality: 85);
      final picked = res.map((x) => File(x.path)).toList();
      if (limit != null && picked.length > limit) return picked.sublist(0, limit);
      return picked;
    } catch (_) {
      return [];
    }
  }
}
