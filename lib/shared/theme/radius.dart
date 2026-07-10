import 'package:flutter/widgets.dart';

/// Radius shkalasi. Har komponent aynan qaysi qiymatni ishlatishi kerakligi
/// bir marta shu yerda belgilanadi — screen'lar orasida farq bo'lmasin.
///
///   xs=4    — kichik chip, tag
///   sm=6    — kichik badge, input hint
///   md=10   — input, tugma, kichik card (theme default'i shu)
///   lg=14   — asosiy card (list item)
///   xl=20   — hero card, bottom sheet
///   xxl=28  — modal, dialog
///   pill    — chip filter, badge (999px)
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
  static const double xxl = 28;
  static const double pill = 999;

  // Tayyor BorderRadius — takror yozib ketmaslik uchun.
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));

  // Bottom sheet uchun faqat yuqori burchak.
  static const BorderRadius rTopXl = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
}
