import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_tokens.dart';
import 'origin_wheel_picker.dart';

/// 日期选择器展示模式
enum OriginDatePickerMode {
  /// 仅年份
  y,

  /// 年与月
  ym,

  /// 年、月、日（默认，支持原厂日历网格与展开年月滚轮）
  ymd,
}

/// vivo OriginOS 风格日历网格选择核心组件 (OriginCalendarDatePicker)
///
/// 严格还原官方 vivo 钱包 `wallet_datepicker_popup.png` 与 `wallet_datepicker_year_select.png`：
/// 1. 顶部年月导航栏：左侧带下拉倒三角的当前年月（点击展开/收起年月双滚轮），右侧 `<` / `>` 切月按钮；
/// 2. 居中 7 列星期表头（日 一 二 三 四 五 六）；
/// 3. 日历单元格：选中的日期呈现直径 36dp 实心强调色圆盘（白字加粗）；
/// 4. 浏览态与选定态解耦：切月只切换浏览年月，不改变已选日期；在日历格点击具体某一天才联动更新。
class OriginCalendarDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const OriginCalendarDatePicker({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  State<OriginCalendarDatePicker> createState() => _OriginCalendarDatePickerState();
}

class _OriginCalendarDatePickerState extends State<OriginCalendarDatePicker> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  // 浏览态年月（与选定态解耦）
  late int _displayedYear;
  late int _displayedMonth;

  // 是否展开了年月双滚轮选择器
  bool _isYearMonthPickerExpanded = false;

  DateTime get _minDate => widget.minDate ?? DateTime(1970, 1, 1);
  DateTime get _maxDate => widget.maxDate ?? DateTime(2100, 12, 31);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;

    _displayedYear = _selectedYear;
    _displayedMonth = _selectedMonth;
  }

  @override
  void didUpdateWidget(covariant OriginCalendarDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDate != widget.initialDate) {
      _selectedYear = widget.initialDate.year;
      _selectedMonth = widget.initialDate.month;
      _selectedDay = widget.initialDate.day;
    }
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_displayedMonth == 1) {
        _displayedYear -= 1;
        _displayedMonth = 12;
      } else {
        _displayedMonth -= 1;
      }
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_displayedMonth == 12) {
        _displayedYear += 1;
        _displayedMonth = 1;
      } else {
        _displayedMonth += 1;
      }
    });
  }

  void _toggleYearMonthPicker() {
    HapticFeedback.selectionClick();
    setState(() {
      _isYearMonthPickerExpanded = !_isYearMonthPickerExpanded;
    });
  }

  void _onCellTapped(int year, int month, int day) {
    HapticFeedback.selectionClick();
    final newDate = DateTime(year, month, day);
    if (newDate.isBefore(_minDate) || newDate.isAfter(_maxDate)) {
      return;
    }
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
      _selectedDay = day;
      _displayedYear = year;
      _displayedMonth = month;
    });
    widget.onDateSelected(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = OriginTokens.primary(context);
    final textPrimary = OriginTokens.textPrimary(context);
    final textSecondary = OriginTokens.textSecondary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final minYear = _minDate.year;
    final maxYear = _maxDate.year;
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final selectedYearIdx = years.indexOf(_displayedYear).clamp(0, years.length - 1);
    final months = List.generate(12, (i) => i + 1);
    final selectedMonthIdx = (_displayedMonth - 1).clamp(0, 11);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 年月导航行：左侧【yyyy年M月 ▾】，右侧【<】和【>】
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 年月下拉展开触发区
              GestureDetector(
                onTap: _toggleYearMonthPicker,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_displayedYear年$_displayedMonth月',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: _isYearMonthPickerExpanded ? primaryColor : textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      Icon(
                        _isYearMonthPickerExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20.0,
                        color: _isYearMonthPickerExpanded ? primaryColor : textSecondary,
                      ),
                    ],
                  ),
                ),
              ),

              // 右侧左右切月按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 22.0,
                    color: textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _previousMonth,
                  ),
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 22.0,
                    color: textPrimary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8.0),

        // 内容区：若展开则显示年月双滚轮，否则显示日历表格
        AnimatedCrossFade(
          firstChild: _buildCalendarGrid(
            context,
            primaryColor,
            textPrimary,
            textSecondary,
            isDark,
          ),
          secondChild: SizedBox(
            height: 200.0,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: OriginWheelPicker<int>(
                    key: const ValueKey('origin_cal_expand_year'),
                    items: years,
                    selectedIndex: selectedYearIdx,
                    unit: '年',
                    labelBuilder: (y) => '$y',
                    onChanged: (idx) {
                      setState(() {
                        _displayedYear = years[idx];
                      });
                    },
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: OriginWheelPicker<int>(
                    key: const ValueKey('origin_cal_expand_month'),
                    items: months,
                    selectedIndex: selectedMonthIdx,
                    unit: '月',
                    labelBuilder: (m) => m.toString().padLeft(2, '0'),
                    onChanged: (idx) {
                      setState(() {
                        _displayedMonth = months[idx];
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _isYearMonthPickerExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    Color primaryColor,
    Color textPrimary,
    Color textSecondary,
    bool isDark,
  ) {
    const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

    final firstDayOfMonth = DateTime(_displayedYear, _displayedMonth, 1);
    final daysInCurrentMonth = DateUtils.getDaysInMonth(_displayedYear, _displayedMonth);

    // 星期天为 0，星期一为 1... 星期六为 6
    final startWeekday = firstDayOfMonth.weekday % 7;

    final totalGridCells = (startWeekday + daysInCurrentMonth <= 35) ? 35 : 42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 星期表头
        Row(
          children: weekDays.map((w) {
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w400,
                    color: textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 8.0),

        // 7 列日历网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalGridCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4.0,
            crossAxisSpacing: 0.0,
            childAspectRatio: 1.0,
          ),
          itemBuilder: (context, index) {
            final cellDay = index - startWeekday + 1;
            final isCurrentMonth = cellDay >= 1 && cellDay <= daysInCurrentMonth;

            if (!isCurrentMonth) {
              return const SizedBox.shrink();
            }

            final isSelected = _selectedYear == _displayedYear &&
                _selectedMonth == _displayedMonth &&
                _selectedDay == cellDay;

            final cellDate = DateTime(_displayedYear, _displayedMonth, cellDay);
            final isDisabled = cellDate.isBefore(_minDate) || cellDate.isAfter(_maxDate);

            return Center(
              child: GestureDetector(
                onTap: isDisabled ? null : () => _onCellTapped(_displayedYear, _displayedMonth, cellDay),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$cellDay',
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDisabled
                              ? (isDark ? Colors.white24 : Colors.black26)
                              : textPrimary),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// vivo OriginOS 风格多列滚轮日期组件 (OriginWheelDatePicker)
///
/// 用于纯滚轮模式（选择年、年月或纯年月日），支持固定单位
class OriginWheelDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;
  final OriginDatePickerMode mode;
  final DateTime? minDate;
  final DateTime? maxDate;

  const OriginWheelDatePicker({
    super.key,
    required this.initialDate,
    required this.onChanged,
    this.mode = OriginDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
  });

  @override
  State<OriginWheelDatePicker> createState() => _OriginWheelDatePickerState();
}

class _OriginWheelDatePickerState extends State<OriginWheelDatePicker> {
  late DateTime _currentDate;

  DateTime get _minDate => widget.minDate ?? DateTime(1970, 1, 1);
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
  void didUpdateWidget(covariant OriginWheelDatePicker oldWidget) {
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
    final selectedYearIndex = years.indexOf(_currentDate.year).clamp(0, years.length - 1);

    final isMinYear = _currentDate.year == _minDate.year;
    final isMaxYear = _currentDate.year == _maxDate.year;
    final firstMonth = isMinYear ? _minDate.month : 1;
    final lastMonth = isMaxYear ? _maxDate.month : 12;
    final monthsCount = (lastMonth - firstMonth + 1) < 0 ? 0 : (lastMonth - firstMonth + 1);
    final months = List.generate(monthsCount, (i) => firstMonth + i);
    final maxMonthIdx = months.isEmpty ? 0 : months.length - 1;
    final rawMonthIdx = months.indexOf(_currentDate.month);
    final selectedMonthIndex = (rawMonthIdx < 0 ? 0 : rawMonthIdx).clamp(0, maxMonthIdx);

    final isMinMonth = isMinYear && _currentDate.month == _minDate.month;
    final isMaxMonth = isMaxYear && _currentDate.month == _maxDate.month;
    final firstDay = isMinMonth ? _minDate.day : 1;
    final totalDaysInMonth = DateUtils.getDaysInMonth(_currentDate.year, _currentDate.month);
    final lastDay = isMaxMonth ? _maxDate.day : totalDaysInMonth;
    final daysCount = (lastDay - firstDay + 1) < 0 ? 0 : (lastDay - firstDay + 1);
    final days = List.generate(daysCount, (i) => firstDay + i);
    final maxDayIdx = days.isEmpty ? 0 : days.length - 1;
    final rawDayIdx = days.indexOf(_currentDate.day);
    final selectedDayIndex = (rawDayIdx < 0 ? 0 : rawDayIdx).clamp(0, maxDayIdx);

    return Row(
      children: [
        // 年滚轮
        Expanded(
          flex: 4,
          child: OriginWheelPicker<int>(
            key: const ValueKey('origin_wheel_year'),
            items: years,
            selectedIndex: selectedYearIndex,
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
              key: ValueKey('origin_wheel_month_${months.length}'),
              items: months,
              selectedIndex: selectedMonthIndex,
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
              key: ValueKey('origin_wheel_day_${days.length}'),
              items: days,
              selectedIndex: selectedDayIndex,
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

/// vivo OriginOS 风格日期弹窗 (OriginDatePickerDialog)
///
/// 严格还原官方 vivo 钱包 `wallet_datepicker_popup.png`：
/// 1. 顶部大标题：居中 20sp Bold，格式 `yyyy年M月d日 周X`（日历模式）或 `yyyy年M月`（年月模式）；
/// 2. 日历网格模式 / 滚轮模式；
/// 3. 底部竖排双胶囊按钮：上【确定】（蓝底白字），下【取消】（浅灰底深字）；
/// 4. 28~30dp 原厂大圆角悬浮卡片。
class OriginDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final OriginDatePickerMode mode;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String? title;
  final String? confirmLabel;
  final String? cancelLabel;

  const OriginDatePickerDialog({
    super.key,
    required this.initialDate,
    this.mode = OriginDatePickerMode.ymd,
    this.minDate,
    this.maxDate,
    this.title,
    this.confirmLabel,
    this.cancelLabel,
  });

  @override
  State<OriginDatePickerDialog> createState() => _OriginDatePickerDialogState();
}

class _OriginDatePickerDialogState extends State<OriginDatePickerDialog> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  String _formatWeekDay(int weekday) {
    switch (weekday) {
      case 1:
        return '周一';
      case 2:
        return '周二';
      case 3:
        return '周三';
      case 4:
        return '周四';
      case 5:
        return '周五';
      case 6:
        return '周六';
      case 7:
      default:
        return '周日';
    }
  }

  String _buildTitleText() {
    if (widget.title != null) return widget.title!;
    if (widget.mode == OriginDatePickerMode.y) {
      return '${_selectedDate.year}年';
    } else if (widget.mode == OriginDatePickerMode.ym) {
      return '${_selectedDate.year}年${_selectedDate.month}月';
    } else {
      return '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日 ${_formatWeekDay(_selectedDate.weekday)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final confirmText = widget.confirmLabel ?? l.commonConfirm;
    final cancelText = widget.cancelLabel ?? l.commonCancel;

    final primaryColor = OriginTokens.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom + 24.0;

    final titleText = _buildTitleText();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: bottomInset,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 350.0,
          ),
          child: Material(
            color: OriginTokens.dialogBackground(context),
            borderRadius: BorderRadius.circular(28.0),
            elevation: 16.0,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部大标题：20sp Bold 格式
                  Center(
                    child: Text(
                      titleText,
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        color: OriginTokens.textPrimary(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16.0),

                  // 核心区：根据模式决定展示日历网格还是滚轮
                  if (widget.mode == OriginDatePickerMode.ymd)
                    OriginCalendarDatePicker(
                      initialDate: _selectedDate,
                      minDate: widget.minDate,
                      maxDate: widget.maxDate,
                      onDateSelected: (newDate) {
                        setState(() => _selectedDate = newDate);
                      },
                    )
                  else
                    OriginWheelDatePicker(
                      initialDate: _selectedDate,
                      mode: widget.mode,
                      minDate: widget.minDate,
                      maxDate: widget.maxDate,
                      onChanged: (newDate) {
                        setState(() => _selectedDate = newDate);
                      },
                    ),

                  const SizedBox(height: 20.0),

                  // 底部操作区：主操作【确定】在上（蓝底白字）
                  SizedBox(
                    height: OriginTokens.buttonHeight,
                    child: ElevatedButton(
                      onPressed: () {
                        DateTime result = _selectedDate;
                        if (widget.mode == OriginDatePickerMode.y) {
                          result = DateTime(_selectedDate.year, 1, 1);
                        } else if (widget.mode == OriginDatePickerMode.ym) {
                          result = DateTime(_selectedDate.year, _selectedDate.month, 1);
                        }
                        Navigator.of(context).pop(result);
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
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10.0),

                  // 底部次操作【取消】在下（浅灰底深字）
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

/// 兼容原有别名 OriginDatePicker
typedef OriginDatePicker = OriginWheelDatePicker;

/// 以 vivo OriginOS 原厂规范唤起日期选择弹窗
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
  return showGeneralDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'DismissDatePicker',
    barrierColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, anim1, anim2) {
      return OriginDatePickerDialog(
        initialDate: initial,
        mode: mode,
        minDate: minDate,
        maxDate: maxDate,
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
