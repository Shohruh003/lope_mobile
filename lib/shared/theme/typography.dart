import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Tipografiya shkalasi. Google Fonts orqali Inter — sistema shrifti bilan
/// bir xil ko'rinishga ega. Har style'da `height` (line-height) va
/// `letterSpacing` aniq belgilangan — Uzum/Click sifatidagi tozalik shu
/// tafsilotlardan chiqadi.
///
/// Ishlatish:  Text('Salom', style: AppText.titleLg)
class AppText {
  AppText._();

  // Hero — welcome, splash
  static TextStyle get display => GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.15,
        letterSpacing: -0.5,
        color: AppColors.textBright,
      );

  // Screen title, section title
  static TextStyle get titleLg => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
        color: AppColors.textBright,
      );

  // Card title, dialog title
  static TextStyle get titleMd => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: AppColors.textBright,
      );

  // List item title
  static TextStyle get titleSm => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.textPrimary,
      );

  // Katta body — hero description
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  // Standart body
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  // Kichik body — sekundar matn, subtitle
  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  // Caption — meta ma'lumot (sana, holat)
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textMuted,
      );

  // Overline — kichik badge, tag
  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
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
        color: AppColors.textBright,
      );
}
