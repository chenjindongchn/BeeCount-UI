import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../custom_ui/widgets/origin_date_picker.dart';
import '../../../custom_ui/widgets/origin_date_time_picker.dart';

enum WheelDatePickerMode { y, ym, ymd }

/// App adapter: localized labels and result/cancellation stay here; wheels live in beecount_ui.
class WheelDatePicker extends StatefulWidget {
  const WheelDatePicker(
      {super.key,
      required this.initial,
      this.mode = WheelDatePickerMode.ymd,
      this.minDate,
      this.maxDate,
      this.confirmLabel});
  final DateTime initial;
  final WheelDatePickerMode mode;
  final DateTime? minDate, maxDate;
  final String? confirmLabel;
  @override
  State<WheelDatePicker> createState() => _WheelDatePickerState();
}

class _WheelDatePickerState extends State<WheelDatePicker> {
  late DateTime date = _clamp(widget.initial);
  DateTime _clamp(DateTime value) {
    final lo = widget.minDate ?? DateTime(2000);
    final hi = widget.maxDate ?? DateTime(2100, 12, 31);
    return value.isBefore(lo)
        ? lo
        : value.isAfter(hi)
            ? hi
            : value;
  }

  DateTime get result => _clamp(switch (widget.mode) {
        WheelDatePickerMode.y => DateTime(date.year),
        WheelDatePickerMode.ym => DateTime(date.year, date.month),
        WheelDatePickerMode.ymd => DateTime(date.year, date.month, date.day)
      });
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OriginDatePicker(
              initialDate: date,
              mode: switch (widget.mode) {
                WheelDatePickerMode.y => OriginDatePickerMode.y,
                WheelDatePickerMode.ym => OriginDatePickerMode.ym,
                WheelDatePickerMode.ymd => OriginDatePickerMode.ymd,
              },
              minDate: widget.minDate,
              maxDate: widget.maxDate,
              onChanged: (v) => setState(() => date = v),
            ),
            const SizedBox(height: 16),
            BeeButton(
                label: widget.confirmLabel ??
                    AppLocalizations.of(context).commonConfirm,
                onPressed: () => Navigator.pop(context, result)),
          ]);
}

Future<DateTime?> showWheelDatePicker(BuildContext context,
        {required DateTime initial,
        WheelDatePickerMode mode = WheelDatePickerMode.ymd,
        DateTime? minDate,
        DateTime? maxDate,
        String? confirmLabel}) =>
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

/// 使用 OriginOS 一体化记账时间抽屉替换原版两步弹窗
Future<DateTime?> showWheelDateTimePicker(BuildContext context,
    {required DateTime initial, DateTime? maxDate}) =>
    showOriginDateTimePicker(
      context,
      initial: initial,
      maxDate: maxDate,
    );
