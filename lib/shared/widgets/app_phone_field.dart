import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared.dart';

/// Uzbek phone-number field with an always-visible `+998` prefix and
/// paste normalisation — port of the web app's `<PhoneInput>` so both
/// platforms accept the same range of formats:
///
///   +998 90 123 45 67
///   998901234567
///   0901234567
///   90 123 45 67
///
/// All of those paste-normalise into the same rendered value
/// `+998 90-123-45-67`; the raw digits after +998 are exposed via
/// [rawDigits]. Use [rawPhone] to get the canonical
/// `+998XXXXXXXXX` string to send to the backend.
class AppPhoneField extends StatefulWidget {
  const AppPhoneField({
    super.key,
    required this.controller,
    this.hintText,
    this.autofocus = false,
    this.onChanged,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  /// Extract the 9-digit local part (without `+998`) from an arbitrary
  /// phone string. Handles the paste patterns listed on the class doc.
  static String extractDigits(String value) {
    final d = value.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('998')) {
      final rest = d.substring(3);
      return rest.length > 9 ? rest.substring(0, 9) : rest;
    }
    if (d.startsWith('0')) {
      final rest = d.substring(1);
      return rest.length > 9 ? rest.substring(0, 9) : rest;
    }
    return d.length > 9 ? d.substring(0, 9) : d;
  }

  /// Format the 9-digit local part into `XX-XXX-XX-XX` groups.
  static String formatDisplay(String rawDigits) {
    final d = rawDigits.replaceAll(RegExp(r'\D'), '');
    final s = d.length > 9 ? d.substring(0, 9) : d;
    if (s.length <= 2) return s;
    if (s.length <= 5) return '${s.substring(0, 2)}-${s.substring(2)}';
    if (s.length <= 7) {
      return '${s.substring(0, 2)}-${s.substring(2, 5)}-${s.substring(5)}';
    }
    return '${s.substring(0, 2)}-${s.substring(2, 5)}-${s.substring(5, 7)}-${s.substring(7)}';
  }

  /// Convert any accepted display value into the canonical
  /// `+998XXXXXXXXX` string for the backend. Returns empty if there
  /// aren't enough digits to form a full number.
  static String rawPhone(String display) {
    final digits = extractDigits(display);
    if (digits.length != 9) return '';
    return '+998$digits';
  }

  @override
  State<AppPhoneField> createState() => _AppPhoneFieldState();
}

class _AppPhoneFieldState extends State<AppPhoneField> {
  static const _prefix = '+998';

  @override
  void initState() {
    super.initState();
    // Prime the controller with the prefix (or normalise whatever is
    // already sitting there) so the field never renders empty.
    final digits = AppPhoneField.extractDigits(widget.controller.text);
    final formatted = AppPhoneField.formatDisplay(digits);
    final desired = formatted.isEmpty ? _prefix : '$_prefix $formatted';
    if (widget.controller.text != desired) {
      widget.controller.text = desired;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      style: AppText.body.copyWith(
        fontWeight: FontWeight.w600,
        color: palette.textBright,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      inputFormatters: [
        _PhonePrefixFormatter(),
      ],
      decoration: InputDecoration(
        hintText: widget.hintText ?? '+998 XX-XXX-XX-XX',
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// Keeps the visible text pinned to `+998 XX-XXX-XX-XX`. Handles paste
/// (multi-digit insertions), backspace (never chews into the prefix),
/// and single-digit typing (append and re-format).
class _PhonePrefixFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = AppPhoneField.extractDigits(newValue.text);
    final formatted = AppPhoneField.formatDisplay(digits);
    final text = formatted.isEmpty ? '+998' : '+998 $formatted';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
