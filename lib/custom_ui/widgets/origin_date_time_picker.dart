import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_date_picker.dart';
import 'origin_segmented_control.dart';
import 'origin_time_picker.dart';

/// vivo OriginOS 风格一体化日期时间选择抽屉 (OriginDateTimePicker)
///
/// 专为记账面板设计：
/// 1. 顶部提供【日期】与【时间】分段滑动切换器；
/// 2. 实时预览当前完整时间（如：2026-11-01 15:30）；
/// 3. 提供“设为此刻”快捷按钮；
/// 4. 底部常驻强调色确认大胶囊与取消胶囊。
class OriginDateTimePicker extends StatefulWidget {
  final DateTime initialDateTime;
  final ValueChanged<DateTime> onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;

  const OriginDateTimePicker({
    super.key,
    required this.initialDateTime,
    required this.onChanged,
    this.minDate,
    this.maxDate,
  });

  @override
  State<OriginDateTimePicker> createState() => _OriginDateTimePickerState();
}

class _OriginDateTimePickerState extends State<OriginDateTimePicker> {
  late DateTime _selected;
  String _activeTab = 'date'; // 'date' | 'time'

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDateTime;
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selected = DateTime(
        newDate.year,
        newDate.month,
        newDate.day,
        _selected.hour,
        _selected.minute,
        _selected.second,
      );
    });
    widget.onChanged(_selected);
  }

  void _onTimeChanged(TimeOfDay newTime) {
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        newTime.hour,
        newTime.minute,
        _selected.second,
      );
    });
    widget.onChanged(_selected);
  }

  void _resetToNow() {
    final now = DateTime.now();
    setState(() => _selected = now);
    widget.onChanged(now);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final dateStr =
        '${_selected.year}-${_selected.month.toString().padLeft(2, '0')}-${_selected.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selected.hour.toString().padLeft(2, '0')}:${_selected.minute.toString().padLeft(2, '0')}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部信息条：完整时间预览与“设为此刻”快捷按钮
        Row(
          children: [
            Expanded(
              child: Text(
                '$dateStr  $timeStr',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: OriginTokens.textPrimary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            GestureDetector(
              onTap: _resetToNow,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  '此刻',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 分段切换器（日期 vs 时间）
        OriginSegmentedControl<String>(
          items: const ['date', 'time'],
          selectedItem: _activeTab,
          labelBuilder: (item) => item == 'date' ? '选择日期' : '选择时间',
          onSelected: (tab) => setState(() => _activeTab = tab),
        ),

        const SizedBox(height: 12),

        // 滚轮展示区域
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _activeTab == 'date'
              ? OriginDatePicker(
                  key: const ValueKey('date_picker'),
                  initialDate: _selected,
                  mode: OriginDatePickerMode.ymd,
                  minDate: widget.minDate,
                  maxDate: widget.maxDate,
                  onChanged: _onDateChanged,
                )
              : OriginTimePicker(
                  key: const ValueKey('time_picker'),
                  initialTime: TimeOfDay.fromDateTime(_selected),
                  onChanged: _onTimeChanged,
                ),
        ),
      ],
    );
  }
}

/// 以 OriginOS 规范拉起完整日期与时间选择抽屉
Future<DateTime?> showOriginDateTimePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? minDate,
  DateTime? maxDate,
  String? title,
  String? confirmLabel,
  String? cancelLabel,
}) {
  final l = AppLocalizations.of(context);
  final sheetTitle = title ?? '记账时间';
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

                // 核心组件
                OriginDateTimePicker(
                  initialDateTime: selected,
                  minDate: minDate,
                  maxDate: maxDate,
                  onChanged: (newDateTime) {
                    selected = newDateTime;
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
