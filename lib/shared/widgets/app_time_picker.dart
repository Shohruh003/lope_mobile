import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tr.dart';
import '../shared.dart';

/// Scrollable wheel-style time picker that replaces Flutter's built-in
/// `showTimePicker` clock face across the barber panel. The dial was
/// too small on the user's phone ("juda ham kichik, o'qishga qiyin")
/// and the localisation defaulted to Russian on a UZ-first app.
///
/// Renders a Cupertino wheel inside a themed bottom sheet with Uzbek
/// Bekor / Tayyor buttons. Returns the picked `TimeOfDay` or `null` on
/// cancel.
///
/// Usage:
///
///     final picked = await AppTimePicker.show(context, initial: t, ref: ref);
class AppTimePicker {
  AppTimePicker._();

  static Future<TimeOfDay?> show(
    BuildContext context, {
    required WidgetRef ref,
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0),
    int minuteInterval = 1,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        TimeOfDay pending = initial;
        return _WheelSheet(
          title: tr(ref, 'mobile.timePicker.title', 'Vaqtni tanlang'),
          cancelLabel: tr(ref, 'common.cancel', 'Bekor'),
          okLabel: tr(ref, 'common.done', 'Tayyor'),
          onOk: () => Navigator.of(sheetCtx).pop(pending),
          onCancel: () => Navigator.of(sheetCtx).pop(),
          child: SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(sheetCtx).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: sheetCtx.colors.textBright,
                  ),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: minuteInterval,
                initialDateTime: DateTime(2020, 1, 1, initial.hour,
                    initial.minute),
                onDateTimeChanged: (dt) {
                  pending = TimeOfDay(hour: dt.hour, minute: dt.minute);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Wheel-style picker for slot intervals — the barber's "Slot oralig'i"
/// setting on the working-hours screen. Options are a curated set of
/// booking-friendly durations (15/20/30/45/60/90 daq). Same bottom
/// sheet chrome as [AppTimePicker] so the two feel like one component.
///
///     final picked = await AppSlotPicker.show(context, ref: ref,
///         initial: 30, options: [15, 20, 30, 45, 60, 90]);
class AppSlotPicker {
  AppSlotPicker._();

  static Future<int?> show(
    BuildContext context, {
    required WidgetRef ref,
    required int initial,
    List<int> options = const [15, 20, 30, 45, 60, 90],
    String? title,
  }) {
    // Snap the initial value to the nearest option — otherwise a stale
    // backend value (e.g. 25 from an older schema) would leave the
    // wheel idx at -1 and Cupertino would silently default to the
    // first item, hiding the current selection from the user.
    final startIdx = () {
      final i = options.indexOf(initial);
      if (i >= 0) return i;
      var best = 0;
      var bestDelta = (options.first - initial).abs();
      for (var j = 1; j < options.length; j++) {
        final d = (options[j] - initial).abs();
        if (d < bestDelta) {
          best = j;
          bestDelta = d;
        }
      }
      return best;
    }();

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        int pending = options[startIdx];
        return _WheelSheet(
          title: title ??
              tr(ref, 'profile.slotInterval', "Slot oralig'i (daqiqa)"),
          cancelLabel: tr(ref, 'common.cancel', 'Bekor'),
          okLabel: tr(ref, 'common.done', 'Tayyor'),
          onOk: () => Navigator.of(sheetCtx).pop(pending),
          onCancel: () => Navigator.of(sheetCtx).pop(),
          child: SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(sheetCtx).brightness,
                textTheme: CupertinoTextThemeData(
                  pickerTextStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: sheetCtx.colors.textBright,
                  ),
                ),
              ),
              child: CupertinoPicker(
                itemExtent: 40,
                magnification: 1.05,
                squeeze: 1.1,
                useMagnifier: true,
                scrollController:
                    FixedExtentScrollController(initialItem: startIdx),
                onSelectedItemChanged: (i) {
                  pending = options[i];
                },
                children: [
                  for (final v in options)
                    Center(
                      child: Text(
                        '$v ${tr(ref, 'profile.minutesShort', 'daq')}',
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-sheet chrome used by both [AppTimePicker] and (eventually) a
/// matching date picker — kept private so the picker widgets share a
/// consistent look (drag handle, title row, Bekor / Tayyor buttons).
class _WheelSheet extends StatelessWidget {
  const _WheelSheet({
    required this.title,
    required this.cancelLabel,
    required this.okLabel,
    required this.onCancel,
    required this.onOk,
    required this.child,
  });

  final String title;
  final String cancelLabel;
  final String okLabel;
  final VoidCallback onCancel;
  final VoidCallback onOk;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.lg, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                TapScale(
                  onTap: onCancel,
                  scale: 0.95,
                  haptic: HapticStrength.selection,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Text(
                      cancelLabel,
                      style: AppText.body.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(title, style: AppText.titleSm),
                  ),
                ),
                TapScale(
                  onTap: onOk,
                  scale: 0.95,
                  haptic: HapticStrength.medium,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Text(
                      okLabel,
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
