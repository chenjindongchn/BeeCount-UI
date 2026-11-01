import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../custom_ui/widgets/origin_date_picker.dart';
import '../../../custom_ui/widgets/origin_time_picker.dart';

enum WheelDatePickerMode { y, ym, ymd }

/// 兼容上游 Bridge: 桥接至 vivo OriginOS 原厂日期选择器
class WheelDatePicker extends StatelessWidget {
  const WheelDatePicker({
    super.key,
    required this.initial,
    this.mode = WheelDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
    this.confirmLabel,
  });

  final DateTime initial;
  final WheelDatePickerMode mode;
  final DateTime? minDate, maxDate;
  final String? confirmLabel;

  @override
  Widget build(BuildContext context) {
    return OriginDatePickerDialog(
      initialDate: initial,
      mode: switch (mode) {
        WheelDatePickerMode.y => OriginDatePickerMode.y,
        WheelDatePickerMode.ym => OriginDatePickerMode.ym,
        WheelDatePickerMode.ymd => OriginDatePickerMode.ymd,
      },
      minDate: minDate,
      maxDate: maxDate,
      confirmLabel: confirmLabel,
    );
  }
}

Future<DateTime?> showWheelDatePicker(
  BuildContext context, {
  required DateTime initial,
  WheelDatePickerMode mode = WheelDatePickerMode.ymd,
  DateTime? minDate,
  DateTime? maxDate,
  String? confirmLabel,
}) =>
    showOriginDatePicker(
      context,
      initial: initial,
      mode: switch (mode) {
        WheelDatePickerMode.y => OriginDatePickerMode.y,
        WheelDatePickerMode.ym => OriginDatePickerMode.ym,
        WheelDatePickerMode.ymd => OriginDatePickerMode.ymd,
      },
      minDate: minDate,
      maxDate: maxDate,
      confirmLabel: confirmLabel,
    );

/// 遵循原版两步流程（选日期 -> 选时间），全部采用 OriginOS 原厂悬浮弹窗标准
Future<DateTime?> showWheelDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? maxDate,
}) async {
  final l = AppLocalizations.of(context);
  final date = await showOriginDatePicker(
    context,
    initial: initial,
    maxDate: maxDate,
    confirmLabel: l.commonNext,
  );
  if (date == null || !context.mounted) return null;

  final time = await showOriginTimePicker(
    context,
    initial: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
    initial.second,
  );
}
