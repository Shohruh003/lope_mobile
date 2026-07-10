import 'package:flutter/material.dart';

/// Card va boshqa komponentlar uchun yumshoq shadow. Dark theme'da katta
/// blur bilan past opacity yaxshi ko'rinadi — aks holda "kirlangan" tuyuladi.
/// Har shadow uchun 2 qatlam — atrofidagi soft glow + ostidagi aniq contact.
class AppShadows {
  AppShadows._();

  /// Card ustidagi juda yengil oyna effekti. Ro'yxat elementlariga qo'yiladi.
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x14000000),  // 8% black
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  /// Asosiy card shadow — hero cardlar, dashboard bloklari.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1F000000),  // 12% black
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
    BoxShadow(
      color: Color(0x0F000000),  // 6% black
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Bottom sheet, dialog, floating action button.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x33000000),  // 20% black
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  /// Doim ustida turadigan floating elementlar (tooltip, snackbar).
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x4D000000),  // 30% black
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];

  /// Primary rangida yumshoq glow — CTA tugmasi uchun.
  static List<BoxShadow> primaryGlow(Color primary) => [
        BoxShadow(
          color: primary.withValues(alpha: 0.25),
          offset: const Offset(0, 8),
          blurRadius: 20,
        ),
      ];
}
