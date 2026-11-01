import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_tokens.dart';
import 'origin_wheel_picker.dart';

/// vivo OriginOS 风格时间滚轮选择核心组件 (OriginTimePicker)
///
/// 遵循 vivo 钱包原厂规范（25-date-and-time-picker.md）：
/// 1. 纯数字滚动，右侧固定“时”、“分”单位；
/// 2. 滚轮高度 200dp，单项高度 40dp；
/// 3. 选中项 22sp~24sp Bold。
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 时滚轮
        Expanded(
          child: OriginWheelPicker<int>(
            key: const ValueKey('origin_time_hour'),
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
            key: const ValueKey('origin_time_minute'),
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
              key: const ValueKey('origin_time_second'),
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

/// vivo OriginOS 风格时间弹窗 (OriginTimePickerDialog)
///
/// 严格还原官方 vivo 钱包 `wallet_timepicker_popup.png`：
/// 1. 顶部居中大字号（22sp Bold）实时显示当前选定时间（如 17:05）；
/// 2. 时/分双滚轮（单位静止固定在居中行）；
/// 3. 底部竖排双胶囊按钮：主操作【确定】在上（蓝底白字），次操作【取消】在下（浅灰底深字）；
/// 4. 28~30dp 原厂大圆角悬浮卡片。
class OriginTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String? title;
  final String? confirmLabel;
  final String? cancelLabel;

  const OriginTimePickerDialog({
    super.key,
    required this.initialTime,
    this.title,
    this.confirmLabel,
    this.cancelLabel,
  });

  @override
  State<OriginTimePickerDialog> createState() => _OriginTimePickerDialogState();
}

class _OriginTimePickerDialogState extends State<OriginTimePickerDialog> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final confirmText = widget.confirmLabel ?? l.commonConfirm;
    final cancelText = widget.cancelLabel ?? l.commonCancel;

    final primaryColor = OriginTokens.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom + 24.0;

    final timeTitle = widget.title ??
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.0,
          right: 20.0,
          bottom: bottomInset,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 340.0,
          ),
          child: Material(
            color: OriginTokens.dialogBackground(context),
            borderRadius: BorderRadius.circular(28.0),
            elevation: 16.0,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部大标题：原厂居中 22sp Bold 时间显示
                  Center(
                    child: Text(
                      timeTitle,
                      style: TextStyle(
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        color: OriginTokens.textPrimary(context),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16.0),

                  // 核心滚轮区
                  OriginTimePicker(
                    initialTime: _selectedTime,
                    onChanged: (newTime) {
                      setState(() => _selectedTime = newTime);
                    },
                  ),

                  const SizedBox(height: 24.0),

                  // 底部主操作【确定】（蓝底白字胶囊）
                  SizedBox(
                    height: OriginTokens.buttonHeight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_selectedTime),
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
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10.0),

                  // 底部次操作【取消】（浅灰底胶囊）
                  SizedBox(
                    height: OriginTokens.buttonHeight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF4F4F6),
                        foregroundColor: isDark
                            ? Colors.white70
                            : const Color(0xFF424242),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 以 vivo OriginOS 原厂规范唤起时间选择弹窗
Future<TimeOfDay?> showOriginTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) {
  return showGeneralDialog<TimeOfDay>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DismissTimePicker',
    barrierColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return OriginTimePickerDialog(
        initialTime: initial,
        title: title,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curve = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.28, 0.85, 0.36, 1.0),
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}
