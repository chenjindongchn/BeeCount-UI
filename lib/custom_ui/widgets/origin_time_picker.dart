import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_wheel_picker.dart';

/// vivo OriginOS 风格时间滚轮选择器组件
class OriginTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;
  final bool showSeconds;
  final int initialSecond;
  final ValueChanged<int>? onSecondChanged;

  const OriginTimePicker({
    super.key,
    required this.initialTime,
    required this.onChanged,
    this.showSeconds = false,
    this.initialSecond = 0,
    this.onSecondChanged,
  });

  @override
  State<OriginTimePicker> createState() => _OriginTimePickerState();
}

class _OriginTimePickerState extends State<OriginTimePicker> {
  late int _hour;
  late int _minute;
  late int _second;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _second = widget.initialSecond.clamp(0, 59);
  }

  @override
  void didUpdateWidget(covariant OriginTimePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _hour = widget.initialTime.hour;
      _minute = widget.initialTime.minute;
    }
    if (oldWidget.initialSecond != widget.initialSecond) {
      _second = widget.initialSecond.clamp(0, 59);
    }
  }

  void _onHourChanged(int hour) {
    setState(() => _hour = hour);
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  void _onMinuteChanged(int minute) {
    setState(() => _minute = minute);
    widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
  }

  void _onSecondChanged(int second) {
    setState(() => _second = second);
    widget.onSecondChanged?.call(second);
  }

  @override
  Widget build(BuildContext context) {
    final hours = List.generate(24, (i) => i);
    final minutes = List.generate(60, (i) => i);
    final seconds = List.generate(60, (i) => i);

    return Row(
      children: [
        // 时滚轮
        Expanded(
          child: OriginWheelPicker<int>(
            items: hours,
            selectedIndex: _hour,
            unit: '时',
            labelBuilder: (h) => h.toString().padLeft(2, '0'),
            onChanged: (idx) => _onHourChanged(hours[idx]),
          ),
        ),

        // 分滚轮
        Expanded(
          child: OriginWheelPicker<int>(
            items: minutes,
            selectedIndex: _minute,
            unit: '分',
            labelBuilder: (m) => m.toString().padLeft(2, '0'),
            onChanged: (idx) => _onMinuteChanged(minutes[idx]),
          ),
        ),

        // 秒滚轮（可选）
        if (widget.showSeconds)
          Expanded(
            child: OriginWheelPicker<int>(
              items: seconds,
              selectedIndex: _second,
              unit: '秒',
              labelBuilder: (s) => s.toString().padLeft(2, '0'),
              onChanged: (idx) => _onSecondChanged(seconds[idx]),
            ),
          ),
      ],
    );
  }
}

/// 以 OriginOS 规范拉起底部时间选择抽屉
Future<TimeOfDay?> showOriginTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) {
  final l = AppLocalizations.of(context);
  final sheetTitle = title ?? l.commonSelectTime;
  final confirmText = confirmLabel ?? l.commonConfirm;
  final cancelText = cancelLabel ?? l.commonCancel;

  TimeOfDay selected = initial;

  return showOriginBottomSheet<TimeOfDay>(
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
                OriginTimePicker(
                  initialTime: selected,
                  onChanged: (newTime) {
                    selected = newTime;
                  },
                ),

                const SizedBox(height: 20),

                // 底部双胶囊操作区
                SizedBox(
                  height: OriginTokens.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(selected),
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
