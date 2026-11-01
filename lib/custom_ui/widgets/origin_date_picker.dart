import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_wheel_picker.dart';

/// 日期选择器展示模式
enum OriginDatePickerMode {
  /// 仅年份
  y,

  /// 年与月
  ym,

  /// 年、月、日
  ymd,
}

/// vivo OriginOS 风格日期滚轮选择器组件
class OriginDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  final OriginDatePickerMode mode;
  final DateTime? minDate;
  final DateTime? maxDate;

  const OriginDatePicker({
    super.key,
    required this.initialDate,
    required this.onChanged,
    this.mode = OriginDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
  });

  @override
  State<OriginDatePicker> createState() => _OriginDatePickerState();
}

class _OriginDatePickerState extends State<OriginDatePicker> {
  late DateTime _currentDate;

  DateTime get _minDate => widget.minDate ?? DateTime(2000, 1, 1);
  DateTime get _maxDate => widget.maxDate ?? DateTime(2100, 12, 31);

  DateTime _clampDate(DateTime date) {
    switch (widget.mode) {
      case OriginDatePickerMode.y:
        if (date.year < _minDate.year) return DateTime(_minDate.year);
        if (date.year > _maxDate.year) return DateTime(_maxDate.year);
        return date;
      case OriginDatePickerMode.ym:
        final dateYm = date.year * 100 + date.month;
        final minYm = _minDate.year * 100 + _minDate.month;
        final maxYm = _maxDate.year * 100 + _maxDate.month;
        if (dateYm < minYm) return DateTime(_minDate.year, _minDate.month);
        if (dateYm > maxYm) return DateTime(_maxDate.year, _maxDate.month);
        return date;
      case OriginDatePickerMode.ymd:
        if (date.isBefore(_minDate)) return _minDate;
        if (date.isAfter(_maxDate)) return _maxDate;
        return date;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDate = _clampDate(widget.initialDate);
  }

  @override
  void didUpdateWidget(covariant OriginDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) {
      _currentDate = _clampDate(widget.initialDate);
    }
  }

  void _onYearChanged(int year) {
    final maxDays = DateUtils.getDaysInMonth(year, _currentDate.month);
    final clampedDay = _currentDate.day.clamp(1, maxDays);
    final newDate = _clampDate(DateTime(year, _currentDate.month, clampedDay));
    setState(() => _currentDate = newDate);
    widget.onChanged(newDate);
  }

  void _onMonthChanged(int month) {
    final maxDays = DateUtils.getDaysInMonth(_currentDate.year, month);
    final clampedDay = _currentDate.day.clamp(1, maxDays);
    final newDate = _clampDate(DateTime(_currentDate.year, month, clampedDay));
    setState(() => _currentDate = newDate);
    widget.onChanged(newDate);
  }

  void _onDayChanged(int day) {
    final newDate = _clampDate(DateTime(_currentDate.year, _currentDate.month, day));
    setState(() => _currentDate = newDate);
    widget.onChanged(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final minYear = _minDate.year;
    final maxYear = _maxDate.year;
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final selectedYearIndex = years.indexOf(_currentDate.year);

    final isMinYear = _currentDate.year == _minDate.year;
    final isMaxYear = _currentDate.year == _maxDate.year;
    final firstMonth = isMinYear ? _minDate.month : 1;
    final lastMonth = isMaxYear ? _maxDate.month : 12;
    final months = List.generate(lastMonth - firstMonth + 1, (i) => firstMonth + i);
    final selectedMonthIndex = months.indexOf(_currentDate.month);

    final isMinMonth = isMinYear && _currentDate.month == _minDate.month;
    final isMaxMonth = isMaxYear && _currentDate.month == _maxDate.month;
    final firstDay = isMinMonth ? _minDate.day : 1;
    final totalDaysInMonth = DateUtils.getDaysInMonth(_currentDate.year, _currentDate.month);
    final lastDay = isMaxMonth ? _maxDate.day : totalDaysInMonth;
    final days = List.generate(lastDay - firstDay + 1, (i) => firstDay + i);
    final selectedDayIndex = days.indexOf(_currentDate.day);

    return Row(
      children: [
        // 年滚轮
        Expanded(
          flex: 4,
          child: OriginWheelPicker<int>(
            key: ValueKey('year_${years.length}_$minYear'),
            items: years,
            selectedIndex: selectedYearIndex < 0 ? 0 : selectedYearIndex,
            unit: '年',
            labelBuilder: (y) => '$y',
            onChanged: (idx) {
              if (idx >= 0 && idx < years.length) {
                _onYearChanged(years[idx]);
              }
            },
          ),
        ),

        // 月滚轮
        if (widget.mode != OriginDatePickerMode.y)
          Expanded(
            flex: 3,
            child: OriginWheelPicker<int>(
              key: ValueKey('month_${_currentDate.year}_${months.length}_$firstMonth'),
              items: months,
              selectedIndex: selectedMonthIndex < 0 ? 0 : selectedMonthIndex,
              unit: '月',
              labelBuilder: (m) => m.toString().padLeft(2, '0'),
              onChanged: (idx) {
                if (idx >= 0 && idx < months.length) {
                  _onMonthChanged(months[idx]);
                }
              },
            ),
          ),

        // 日滚轮
        if (widget.mode == OriginDatePickerMode.ymd)
          Expanded(
            flex: 3,
            child: OriginWheelPicker<int>(
              key: ValueKey('day_${_currentDate.year}_${_currentDate.month}_${days.length}_$firstDay'),
              items: days,
              selectedIndex: selectedDayIndex < 0 ? 0 : selectedDayIndex,
              unit: '日',
              labelBuilder: (d) => d.toString().padLeft(2, '0'),
              onChanged: (idx) {
                if (idx >= 0 && idx < days.length) {
                  _onDayChanged(days[idx]);
                }
              },
            ),
          ),
      ],
    );
  }
}

/// 以 OriginOS 规范拉起底部日期选择抽屉
Future<DateTime?> showOriginDatePicker(
  BuildContext context, {
  required DateTime initial,
  OriginDatePickerMode mode = OriginDatePickerMode.ymd,
  DateTime? minDate,
  DateTime? maxDate,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) {
  final l = AppLocalizations.of(context);
  final sheetTitle = title ?? l.homeSelectDate;
  final confirmText = confirmLabel ?? l.commonConfirm;
  final cancelText = cancelLabel ?? l.commonCancel;

  DateTime selected = initial;

  return showOriginBottomSheet<DateTime>(
    context,
    builder: (ctx) {
      final primaryColor = Theme.of(ctx).colorScheme.primary;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部标题
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      sheetTitle,
                      style: TextStyle(
                        fontSize: OriginSheetTokens.titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: OriginTokens.textPrimary(ctx),
                      ),
                    ),
                  ),
                ),

                // 核心滚轮区
                OriginDatePicker(
                  initialDate: selected,
                  mode: mode,
                  minDate: minDate,
                  maxDate: maxDate,
                  onChanged: (newDate) {
                    selected = newDate;
                  },
                ),

                const SizedBox(height: 20),

                // 底部双胶囊操作区（确认在上，取消在下，遵循规范）
                SizedBox(
                  height: OriginTokens.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      DateTime result = selected;
                      if (mode == OriginDatePickerMode.y) {
                        result = DateTime(selected.year, 1, 1);
                      } else if (mode == OriginDatePickerMode.ym) {
                        result = DateTime(selected.year, selected.month, 1);
                      } else {
                        result = DateTime(selected.year, selected.month, selected.day);
                      }
                      Navigator.of(ctx).pop(result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: OriginTokens.buttonHeight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    style: TextButton.styleFrom(
                      backgroundColor: OriginSheetTokens.cancelBackground(ctx),
                      foregroundColor: OriginTokens.textSecondary(ctx),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
              ],
            ),
          );
        },
      );
    },
  );
}
