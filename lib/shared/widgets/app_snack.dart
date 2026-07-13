import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../shared.dart';

/// Themed toast helper — shows an animated pill notification anchored
/// to the bottom of the screen so success / error / info feedback
/// reads at a glance instead of blending into Flutter's default grey
/// ribbon.
///
/// Uses an [OverlayEntry] instead of `ScaffoldMessenger.showSnackBar`
/// so we control the entire animation — slide-up with a spring, fade
/// in, and dismiss with a matching slide-down. Chained through
/// flutter_animate for a smooth feel that matches the rest of the
/// design system.
///
///   AppSnack.success(context, "Saqlandi");
///   AppSnack.error(context, humanize(e));
///   AppSnack.info(context, "Nusxalandi");
class AppSnack {
  AppSnack._();

  /// Currently-visible toast so a fast-fire sequence (e.g. multiple
  /// save calls in a row) replaces rather than stacks. Kept static
  /// because there is only one toast on screen at a time by design.
  static OverlayEntry? _current;
  static Timer? _dismissTimer;

  static void success(BuildContext context, String message) =>
      _show(context, message,
          color: AppColors.success, icon: Icons.check_circle_rounded);

  static void error(BuildContext context, String message) =>
      _show(context, message,
          color: AppColors.danger, icon: Icons.error_outline_rounded);

  static void info(BuildContext context, String message) =>
      _show(context, message,
          color: AppColors.primary, icon: Icons.info_outline_rounded);

  static void warning(BuildContext context, String message) =>
      _show(context, message,
          color: AppColors.warning, icon: Icons.warning_amber_rounded);

  static void _show(
    BuildContext context,
    String message, {
    required Color color,
    required IconData icon,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Kill any in-flight toast so the new one takes its place — the
    // last event is usually the one the user cares about.
    _dismissTimer?.cancel();
    _current?.remove();
    _current = null;

    final entry = OverlayEntry(
      builder: (_) => _AppSnackToast(
        message: message,
        color: color,
        icon: icon,
      ),
    );
    _current = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(const Duration(milliseconds: 2800), () {
      _current?.remove();
      _current = null;
    });
  }
}

class _AppSnackToast extends StatelessWidget {
  const _AppSnackToast({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final mq = MediaQuery.of(context);
    // Positioning uses the safe-area inset so the pill floats a bit
    // above the bottom nav — never covered by it.
    return Positioned(
      left: 16,
      right: 16,
      bottom: mq.padding.bottom + 84,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: palette.textBright,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        )
            // Slide in from below with a light spring, fade in, and
            // pulse the icon container slightly on entry so the eye
            // catches the color-coded status before the message.
            .animate()
            .slideY(
                begin: 1.4,
                end: 0,
                duration: 380.ms,
                curve: Curves.easeOutCubic)
            .fadeIn(duration: 240.ms)
            .scale(
                begin: const Offset(0.94, 0.94),
                end: const Offset(1, 1),
                duration: 340.ms,
                curve: Curves.easeOutBack),
      ),
    );
  }
}
