import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tr.dart';
import '../shared.dart';

/// Uzbek-first date picker that replaces Flutter's built-in
/// `showDatePicker`. The Material picker fell back to Russian
/// localisation on a UZ-first app (Flutter's `GlobalMaterialLocalizations`
/// doesn't ship `uz`), and the calendar UI was busy for the barber
/// panel's simple "pick a day in this month" use cases.
///
/// Renders three scroll wheels (day / month / year) inside the same
/// themed bottom sheet as [AppTimePicker], with Uzbek month names.
///
/// Usage:
///
///     final picked = await AppDatePicker.show(
///       context,
///       ref: ref,
///       initial: DateTime.now(),
///       firstDate: DateTime.now().subtract(const Duration(days: 30)),
///       lastDate: DateTime.now().add(const Duration(days: 365)),
///     );
class AppDatePicker {
  AppDatePicker._();

  static const _monthsUz = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avgust',
    'sentyabr',
    'oktyabr',
    'noyabr',
    'dekabr',
  ];

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static Future<DateTime?> show(
    BuildContext context, {
    required WidgetRef ref,
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _DateWheelSheet(
        initial: initial,
        firstDate: firstDate,
        lastDate: lastDate,
        title: tr(ref, 'mobile.datePicker.title', 'Sanani tanlang'),
        cancelLabel: tr(ref, 'common.cancel', 'Bekor'),
        okLabel: tr(ref, 'common.done', 'Tayyor'),
      ),
    );
  }
}

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.cancelLabel,
    required this.okLabel,
  });

  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String cancelLabel;
  final String okLabel;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late int _year = widget.initial.year;
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  late final int _minYear = widget.firstDate.year;
  late final int _maxYear = widget.lastDate.year;

  late final FixedExtentScrollController _yearCtrl;
  late final FixedExtentScrollController _monthCtrl;
  late final FixedExtentScrollController _dayCtrl;

  @override
  void initState() {
    super.initState();
    _yearCtrl = FixedExtentScrollController(
        initialItem: _year - _minYear);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  }

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  DateTime get _picked {
    final safeDay =
        _day.clamp(1, AppDatePicker._daysInMonth(_year, _month));
    return DateTime(_year, _month, safeDay);
  }

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
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 12, AppSpacing.lg, 16),
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
                  onTap: () => Navigator.pop(context),
                  scale: 0.95,
                  haptic: HapticStrength.selection,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Text(
                      widget.cancelLabel,
                      style: AppText.body.copyWith(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(widget.title, style: AppText.titleSm),
                  ),
                ),
                TapScale(
                  onTap: () {
                    final picked = _picked;
                    // Clamp within firstDate/lastDate defensively.
                    if (picked.isBefore(widget.firstDate)) {
                      Navigator.pop(context, widget.firstDate);
                    } else if (picked.isAfter(widget.lastDate)) {
                      Navigator.pop(context, widget.lastDate);
                    } else {
                      Navigator.pop(context, picked);
                    }
                  },
                  scale: 0.95,
                  haptic: HapticStrength.medium,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: Text(
                      widget.okLabel,
                      style: AppText.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                height: 216,
                child: Stack(children: [
                  // Center highlight bar so the barber can see which
                  // row is currently selected at a glance — previously
                  // all rows rendered identically and the "which is
                  // picked?" answer required reading the header title.
                  IgnorePointer(
                    ignoring: true,
                    child: Center(
                      child: Container(
                        height: 40,
                        margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs),
                        // Cupertino-style soft grey center bar —
                        // matches the AppTimePicker's built-in
                        // highlight so both wheel pickers feel like
                        // the same widget.
                        decoration: BoxDecoration(
                          color: context.colors.surfaceElevated,
                          borderRadius: AppRadius.rMd,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _WheelColumn(
                          controller: _dayCtrl,
                          itemCount:
                              AppDatePicker._daysInMonth(_year, _month),
                          selectedIndex: _day - 1,
                          label: (i) => '${i + 1}',
                          onChanged: (i) => setState(() => _day = i + 1),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _WheelColumn(
                          controller: _monthCtrl,
                          itemCount: 12,
                          selectedIndex: _month - 1,
                          label: (i) => AppDatePicker._monthsUz[i],
                          onChanged: (i) {
                            setState(() {
                              _month = i + 1;
                              // Clamp day if new month has fewer days
                              // (e.g. Jan 31 → Feb).
                              final maxDay = AppDatePicker._daysInMonth(
                                  _year, _month);
                              if (_day > maxDay) {
                                _day = maxDay;
                                _dayCtrl.jumpToItem(_day - 1);
                              }
                            });
                          },
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _WheelColumn(
                          controller: _yearCtrl,
                          itemCount: _maxYear - _minYear + 1,
                          selectedIndex: _year - _minYear,
                          label: (i) => '${_minYear + i}',
                          onChanged: (i) {
                            setState(() {
                              _year = _minYear + i;
                              final maxDay = AppDatePicker._daysInMonth(
                                  _year, _month);
                              if (_day > maxDay) {
                                _day = maxDay;
                                _dayCtrl.jumpToItem(_day - 1);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      perspective: 0.005,
      diameterRatio: 1.4,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final selected = index == selectedIndex;
          return Center(
            child: Text(
              label(index),
              style: AppText.body.copyWith(
                fontSize: selected ? 22 : 20,
                fontWeight:
                    selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? colors.textBright
                    : colors.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }
}
