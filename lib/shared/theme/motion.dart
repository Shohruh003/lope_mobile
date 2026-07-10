import 'package:flutter/animation.dart';

/// Animatsiya davomiyligi va curve'lari. Har joyda bir xil ishlatilsa —
/// ilova bir maromda "nafas oladi" degan taassurot beradi.
///
/// Material 3 Motion tavsiyalariga asoslangan:
///   short   — 150ms — tap feedback, small state change
///   base    — 250ms — card transition, chip select
///   medium  — 400ms — page-level transition, sheet
///   long    — 600ms — hero animation, celebration
class AppMotion {
  AppMotion._();

  static const Duration short = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration long = Duration(milliseconds: 600);

  // Curve'lar — Material 3 emphasized va standard curve'lariga taqlid.
  //
  //   emphasized      — asosiy element harakati (mavjud narsa o'zgaradi)
  //   emphasizedDec   — bir narsa ekranga kirayapti (masalan sheet ochilyapti)
  //   emphasizedAcc   — bir narsa ekrandan chiqib ketyapti
  //   standard        — kichik state change (ripple, hover)
  //   bouncy          — celebratory (success animation)
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDec = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAcc = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve bouncy = Curves.elasticOut;
}
