import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lope_colors.dart';

/// Tipografiya shkalasi. Google Fonts orqali Inter — sistema shrifti bilan
/// bir xil ko'rinishga ega. Har style'da `height` (line-height) va
/// `letterSpacing` aniq belgilangan — Uzum/Click sifatidagi tozalik shu
/// tafsilotlardan chiqadi.
///
/// Ranglar `AppText.brightness` orqali runtime'da almashadi. `app.dart`
/// har build oldida bu qiymatni themeModeProvider'dan hisoblab qo'yadi
/// va getter'lar shu paytdagi paletka rangini qaytaradi. Shuning uchun
/// `AppText.titleLg` chaqirig'i qorong'i rejimda oq, yorug' rejimda
/// esa slate-900 (deyarli qora) rangda chiqadi — hech qaerni tegishga
/// hojat qolmaydi.
class AppText {
  AppText._();

  // ─── Runtime brightness ────────────────────────────────────────────
  static Brightness brightness = Brightness.dark;
  static LopeColors get _palette =>
      brightness == Brightness.dark ? LopeColors.dark : LopeColors.light;

  // ─── Styles ────────────────────────────────────────────────────────

  // Hero — welcome, splash
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: _palette.textBright,
      );

  // Screen title, section title
  static TextStyle get titleLg => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
        color: _palette.textBright,
      );

  // Card title, dialog title
  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: _palette.textBright,
      );

  // List item title
  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: _palette.textPrimary,
      );

  // Katta body — hero description
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: _palette.textPrimary,
      );

  // Standart body
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: _palette.textPrimary,
      );

  // Kichik body — sekundar matn, subtitle
  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: _palette.textSecondary,
      );

  // Caption — meta ma'lumot (sana, holat)
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
        color: _palette.textMuted,
      );

  // Overline — kichik badge, tag
  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.6,
        color: _palette.textMuted,
      );

  // Tugma matni
  static TextStyle get button => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      );

  // Katta tugma (CTA)
  static TextStyle get buttonLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
      );

  // Raqamlar — narx, balans, statistika (tabular figures)
  static TextStyle get numeric => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: _palette.textBright,
      );
}
