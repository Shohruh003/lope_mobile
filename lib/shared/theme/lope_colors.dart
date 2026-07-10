import 'package:flutter/material.dart';

/// Runtime-swappable colour palette registered as a [ThemeExtension] on
/// both the light and dark [ThemeData]. Widgets read colours through
/// [BuildContext.colors] (defined below) so the palette follows the
/// active [Brightness] automatically.
///
/// Semantic colours (primary / success / warning / danger) live on
/// `AppColors` and don't need to swap between modes — they're brand
/// tokens. Only surface + text tokens flip with the theme.
@immutable
class LopeColors extends ThemeExtension<LopeColors> {
  const LopeColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textBright,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color textBright;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Dark palette — matches the web shadcn/ui defaults 1:1.
  static const dark = LopeColors(
    background: Color(0xFF0A0F1F),
    surface: Color(0xFF0A0F1F),
    surfaceElevated: Color(0xFF101729),
    border: Color(0xFF1E293B),
    textBright: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
  );

  /// Light palette — slate-based greys so the brand primary still pops.
  static const light = LopeColors(
    background: Color(0xFFF8FAFC), // slate-50
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9), // slate-100
    border: Color(0xFFE2E8F0),          // slate-200
    textBright: Color(0xFF0F172A),      // slate-900
    textPrimary: Color(0xFF1E293B),     // slate-800
    textSecondary: Color(0xFF475569),   // slate-600
    textMuted: Color(0xFF64748B),       // slate-500
  );

  @override
  LopeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? textBright,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return LopeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      textBright: textBright ?? this.textBright,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  LopeColors lerp(ThemeExtension<LopeColors>? other, double t) {
    if (other is! LopeColors) return this;
    return LopeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      textBright: Color.lerp(textBright, other.textBright, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Sugar so widgets can write `context.colors.background` instead of
/// `Theme.of(context).extension<LopeColors>()!.background`.
extension LopeColorsContext on BuildContext {
  LopeColors get colors {
    return Theme.of(this).extension<LopeColors>() ?? LopeColors.dark;
  }
}
