import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../shared/theme/colors.dart';
import '../shared/theme/lope_colors.dart';

/// App theme. Accepts a brightness so we can build both a dark and a
/// light [ThemeData] from the same tokens. Widgets that read colours
/// through `context.colors.xxx` will pick up the right palette
/// automatically because both ThemeData objects register a matching
/// [LopeColors] extension.
///
/// Semantic colours (primary, success, danger, warning) live on
/// `AppColors` and stay identical in both modes — they're brand tokens.
ThemeData buildAppTheme([Brightness brightness = Brightness.dark]) {
  final palette = brightness == Brightness.dark
      ? LopeColors.dark
      : LopeColors.light;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: brightness == Brightness.dark
        ? ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.primary,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: AppColors.danger,
          )
        : ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            secondary: AppColors.primary,
            surface: palette.surface,
            onSurface: palette.textPrimary,
            error: AppColors.danger,
          ),
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    extensions: <ThemeExtension<dynamic>>[palette],
  );

  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.textBright,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: palette.border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceElevated,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(
          color: palette.textMuted, fontSize: 14, fontWeight: FontWeight.w400),
      labelStyle: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: palette.surfaceElevated,
        disabledForegroundColor: palette.textMuted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size.fromHeight(40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size.fromHeight(40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.surfaceElevated,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      side: BorderSide(color: palette.border),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    dividerTheme:
        DividerThemeData(color: palette.border, thickness: 1, space: 1),
    // Floating pill-style snackbars app-wide — every
    // `ScaffoldMessenger.showSnackBar` inherits this without touching
    // the callsite. The old defaults (full-width, dark ribbon at the
    // bottom edge) clashed with the rest of the design system.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.surfaceElevated,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textBright,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      actionTextColor: AppColors.primary,
      showCloseIcon: false,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    splashFactory: InkRipple.splashFactory,
  );
}
