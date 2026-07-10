import 'package:flutter/services.dart';

/// Haptik kuchining darajalari — TapScale va AppButton umumiy enum ishlatishi
/// uchun bir joyda saqlanadi.
enum HapticStrength { none, light, medium, selection }

/// Haptik feedback wrapper. Uzum Bank / Click darajasidagi ilova har tap'da
/// telefon biroz "vibratsiya" qiladi — bu foydalanuvchiga ilova "javob
/// beryapti" degan tuyg'u beradi.
///
/// Muhim: haddan tashqari vibro ham yomon. Har haptik chaqiruvni **50ms**
/// debounce qilamiz — birin ketin bir necha marta tap qilinsa, faqat
/// birinchisi ishlaydi.
class AppHaptics {
  AppHaptics._();

  static DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);
  static const _debounce = Duration(milliseconds: 50);

  static bool _shouldFire() {
    final now = DateTime.now();
    if (now.difference(_lastFire) < _debounce) return false;
    _lastFire = now;
    return true;
  }

  /// Yengil tap — kartochka, chip, tugma.
  static void light() {
    if (!_shouldFire()) return;
    HapticFeedback.lightImpact();
  }

  /// O'rta — muhim tugma (buyurtma tasdiqlash).
  static void medium() {
    if (!_shouldFire()) return;
    HapticFeedback.mediumImpact();
  }

  /// Kuchli — xato yoki tanqidiy holat.
  static void heavy() {
    if (!_shouldFire()) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection tick — filter almashish, tab o'zgarishi.
  static void selection() {
    if (!_shouldFire()) return;
    HapticFeedback.selectionClick();
  }

  /// Muvaffaqiyat — buyurtma qabul qilindi.
  static void success() {
    if (!_shouldFire()) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Xatolik — validatsiya tushdi.
  static void error() {
    if (!_shouldFire()) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });
  }
}
