import 'package:flutter/material.dart';

/// Brand palette — matches the web's `index.css` dark theme HSL variables 1:1
/// so the mobile and web app look identical side-by-side. The web uses
/// shadcn/ui defaults (slate + blue) — NOT the zinc/neutral gray we had.
class AppColors {
  AppColors._();

  // --- Primary (matches `--primary: 217.2 91.2% 59.8%`) ---
  static const Color primary = Color(0xFF3B82F6);      // blue-500
  static const Color primaryDark = Color(0xFF2563EB);  // blue-600

  // --- Surfaces (matches `--background` / `--card`) ---
  // Web has `--background == --card`. Cards differentiate by BORDER, not by
  // a different shade. Both are the same deep navy-tinted slate.
  static const Color background = Color(0xFF0A0F1F);
  static const Color surface = Color(0xFF0A0F1F);          // SAME as background
  static const Color surfaceElevated = Color(0xFF101729);  // hover / popover

  // `--border: 217.2 32.6% 17.5%` → slate-800-ish
  static const Color border = Color(0xFF1E293B);

  // --- Text (matches `--foreground` / `--muted-foreground`) ---
  static const Color textBright = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFF8FAFC);   // slate-50
  static const Color textSecondary = Color(0xFFCBD5E1); // slate-300
  static const Color textMuted = Color(0xFF94A3B8);     // slate-400

  // --- Semantic (web uses default red/amber/green-500) ---
  static const Color success = Color(0xFF22C55E);  // green-500
  static const Color warning = Color(0xFFF59E0B);  // amber-500
  static const Color danger = Color(0xFFEF4444);   // red-500

  // --- Gradients (used for hero blocks like the wallet card) ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF101729), Color(0xFF0A0F1F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
