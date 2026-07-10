import 'package:flutter/widgets.dart';

/// 4-point spacing scale. Har bir qadam 4px — bu Uzum Bank, Click va boshqa
/// professional ilovalarda ishlatiladigan standart shkala. Har joyda shu
/// tokenlarni ishlating — magic number (`padding: 13`) yo'q qiling.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;    // ikonka va matn oralig'i
  static const double sm = 8;    // ichki padding, chip padding
  static const double md = 12;   // input padding, tugma padding
  static const double lg = 16;   // card padding, section padding
  static const double xl = 20;   // katta card padding
  static const double xxl = 24;  // screen edge padding
  static const double xxxl = 32; // section separator
  static const double huge = 48; // hero section

  // Tez foydalanish uchun tayyor EdgeInsets.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: xxl);
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(xl);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(horizontal: md, vertical: sm);

  // Vertikal gap (Column/ListView orasi).
  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);

  // Gorizontal gap (Row orasi).
  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
}
