import 'package:flutter/material.dart';

/// Brand palette — mirrors the web app's dark theme exactly so users moving
/// from app.lopestyle.uz to the native build never sense a context switch.
class AppColors {
  AppColors._();

  // Primary accent — matches the web Tailwind `primary` (sky-500 vibe).
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF2563EB);

  // Surfaces — deep blue-tinted black for that premium feel.
  static const Color background = Color(0xFF09090B);
  static const Color surface = Color(0xFF141417);
  static const Color surfaceElevated = Color(0xFF1C1C21);
  static const Color border = Color(0xFF27272A);

  // Text
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF71717A);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Premium accent gradients (used for cards, buttons, decorative)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF18181B), Color(0xFF0B0B0E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
