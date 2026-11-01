import 'package:flutter/material.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_date_picker.dart';

/// vivo OriginOS 规范标准周序号计算 (ISO-8601)
int getIsoWeekOfYear(DateTime date) {
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstDayOfYear = DateTime(thursday.year, 1, 1);
  final dayOfYear = thursday.difference(firstDayOfYear).inDays;
  return (dayOfYear / 7).floor() + 1;
}

/// 获取某个日期所在周的周一
DateTime getMondayOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// 1. 【选择周】底部弹窗 (showOriginWeekPickerSheet)
Future<void> showOriginWeekPickerSheet(
  BuildContext context, {
  required DateTime selectedMonday,
  required ValueChanged<DateTime> onSelected,
  required Color primaryColor,
}) {
  return showOriginBottomSheet(
    context,
    builder: (ctx) {
      return _WeekPickerSheetContent(
        selectedMonday: selectedMonday,
        onSelected: onSelected,
        primaryColor: primaryColor,
      );
    },
  );
}

class _WeekPickerSheetContent extends StatefulWidget {
  final DateTime selectedMonday;
  final ValueChanged<DateTime> onSelected;
  final Color primaryColor;

  const _WeekPickerSheetContent({
    required this.selectedMonday,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  State<_WeekPickerSheetContent> createState() => _WeekPickerSheetContentState();
}

class _WeekPickerSheetContentState extends State<_WeekPickerSheetContent> {
  late DateTime _browsingMonth;

  @override
  void initState() {
    super.initState();
    _browsingMonth = DateTime(widget.selectedMonday.year, widget.selectedMonday.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _browsingMonth = DateTime(_browsingMonth.year, _browsingMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _browsingMonth = DateTime(_browsingMonth.year, _browsingMonth.month + 1, 1);
    });
  }

  List<({DateTime monday, DateTime sunday, int weekNum, bool isCurrentWeek})> _getWeeks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    final year = _browsingMonth.year;
    final month = _browsingMonth.month;
    final lastDay = DateTime(year, month + 1, 0).day;
    final weeks = <({DateTime monday, DateTime sunday, int weekNum, bool isCurrentWeek})>[];

    for (int d = 1; d <= lastDay; d++) {
      final dt = DateTime(year, month, d);
      if (dt.weekday == DateTime.monday) {
        final sunday = dt.add(const Duration(days: 6));
        final weekNum = getIsoWeekOfYear(dt);
        final isCur = dt.year == currentMonday.year &&
            dt.month == currentMonday.month &&
            dt.day == currentMonday.day;
        weeks.add((
          monday: dt,
          sunday: sunday,
          weekNum: weekNum,
          isCurrentWeek: isCur,
        ));
      }
    }
    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeks = _getWeeks();
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部居中标题与右上角关闭
            _SheetHeader(
              title: '选择周',
              onClose: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 12),

            // 年月导航条
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleNavButton(
                  icon: Icons.chevron_left_rounded,
                  bgColor: navButtonBg,
                  onTap: _prevMonth,
                ),
                Text(
                  '${_browsingMonth.year}年${_browsingMonth.month}月',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                _CircleNavButton(
                  icon: Icons.chevron_right_rounded,
                  bgColor: navButtonBg,
                  onTap: _nextMonth,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 周网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: weeks.length,
              itemBuilder: (context, index) {
                final item = weeks[index];
                final isSelected = widget.selectedMonday.year == item.monday.year &&
                    widget.selectedMonday.month == item.monday.month &&
                    widget.selectedMonday.day == item.monday.day;

                final itemBg = isSelected
                    ? widget.primaryColor.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F8));

                final titleColor = isSelected
                    ? widget.primaryColor
                    : OriginTokens.textPrimary(context);

                final subtitleColor = isSelected
                    ? widget.primaryColor.withValues(alpha: 0.8)
                    : OriginTokens.textSecondary(context);

                return Material(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      widget.onSelected(item.monday);
                      Navigator.of(context).pop();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.isCurrentWeek ? '本周' : '第${item.weekNum}周',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.monday.month}/${item.monday.day}—${item.sunday.month}/${item.sunday.day}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// 2. 【选择月】底部弹窗 (showOriginMonthPickerSheet)
Future<void> showOriginMonthPickerSheet(
  BuildContext context, {
  required DateTime selectedMonth,
  required ValueChanged<DateTime> onSelected,
  required Color primaryColor,
}) {
  return showOriginBottomSheet(
    context,
    builder: (ctx) {
      return _MonthPickerSheetContent(
        selectedMonth: selectedMonth,
        onSelected: onSelected,
        primaryColor: primaryColor,
      );
    },
  );
}

class _MonthPickerSheetContent extends StatefulWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelected;
  final Color primaryColor;

  const _MonthPickerSheetContent({
    required this.selectedMonth,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  State<_MonthPickerSheetContent> createState() => _MonthPickerSheetContentState();
}

class _MonthPickerSheetContentState extends State<_MonthPickerSheetContent> {
  late int _browsingYear;

  @override
  void initState() {
    super.initState();
    _browsingYear = widget.selectedMonth.year;
  }

  void _prevYear() => setState(() => _browsingYear--);
  void _nextYear() => setState(() => _browsingYear++);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: '选择月',
              onClose: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleNavButton(
                  icon: Icons.chevron_left_rounded,
                  bgColor: navButtonBg,
                  onTap: _prevYear,
                ),
                Text(
                  '$_browsingYear年',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                _CircleNavButton(
                  icon: Icons.chevron_right_rounded,
                  bgColor: navButtonBg,
                  onTap: _nextYear,
                ),
              ],
            ),

            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected = widget.selectedMonth.year == _browsingYear &&
                    widget.selectedMonth.month == month;

                final itemBg = isSelected
                    ? widget.primaryColor.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F8));

                final textColor = isSelected
                    ? widget.primaryColor
                    : OriginTokens.textPrimary(context);

                return Material(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      widget.onSelected(DateTime(_browsingYear, month, 1));
                      Navigator.of(context).pop();
                    },
                    child: Center(
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// 3. 【选择年】底部弹窗 (showOriginYearPickerSheet)
Future<void> showOriginYearPickerSheet(
  BuildContext context, {
  required int selectedYear,
  required ValueChanged<int> onSelected,
  required Color primaryColor,
}) {
  return showOriginBottomSheet(
    context,
    builder: (ctx) {
      return _YearPickerSheetContent(
        selectedYear: selectedYear,
        onSelected: onSelected,
        primaryColor: primaryColor,
      );
    },
  );
}

class _YearPickerSheetContent extends StatefulWidget {
  final int selectedYear;
  final ValueChanged<int> onSelected;
  final Color primaryColor;

  const _YearPickerSheetContent({
    required this.selectedYear,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  State<_YearPickerSheetContent> createState() => _YearPickerSheetContentState();
}

class _YearPickerSheetContentState extends State<_YearPickerSheetContent> {
  late int _baseDecade;

  @override
  void initState() {
    super.initState();
    _baseDecade = (widget.selectedYear ~/ 10) * 10;
  }

  void _prevDecade() => setState(() => _baseDecade -= 10);
  void _nextDecade() => setState(() => _baseDecade += 10);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: '选择年',
              onClose: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleNavButton(
                  icon: Icons.chevron_left_rounded,
                  bgColor: navButtonBg,
                  onTap: _prevDecade,
                ),
                Text(
                  '$_baseDecade年—${_baseDecade + 9}年',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                _CircleNavButton(
                  icon: Icons.chevron_right_rounded,
                  bgColor: navButtonBg,
                  onTap: _nextDecade,
                ),
              ],
            ),

            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
              ),
              itemCount: 10,
              itemBuilder: (context, index) {
                final year = _baseDecade + index;
                final isSelected = widget.selectedYear == year;

                final itemBg = isSelected
                    ? widget.primaryColor.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F8));

                final textColor = isSelected
                    ? widget.primaryColor
                    : OriginTokens.textPrimary(context);

                return Material(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      widget.onSelected(year);
                      Navigator.of(context).pop();
                    },
                    child: Center(
                      child: Text(
                        '$year',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// 4. 【自定义时间】底部弹窗 (showOriginCustomRangeSheet)
Future<void> showOriginCustomRangeSheet(
  BuildContext context, {
  required DateTime start,
  required DateTime end,
  required void Function(DateTime start, DateTime end) onSelected,
  required Color primaryColor,
}) {
  return showOriginBottomSheet(
    context,
    builder: (ctx) {
      return _CustomRangeSheetContent(
        start: start,
        end: end,
        onSelected: onSelected,
        primaryColor: primaryColor,
      );
    },
  );
}

class _CustomRangeSheetContent extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  final void Function(DateTime start, DateTime end) onSelected;
  final Color primaryColor;

  const _CustomRangeSheetContent({
    required this.start,
    required this.end,
    required this.onSelected,
    required this.primaryColor,
  });

  @override
  State<_CustomRangeSheetContent> createState() => _CustomRangeSheetContentState();
}

class _CustomRangeSheetContentState extends State<_CustomRangeSheetContent> {
  late DateTime _start;
  late DateTime _end;
  String? _selectedShortcut;

  @override
  void initState() {
    super.initState();
    _start = DateTime(widget.start.year, widget.start.month, widget.start.day);
    _end = DateTime(widget.end.year, widget.end.month, widget.end.day);
  }

  void _applyShortcut(String key) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime newStart;
    DateTime newEnd = today;

    switch (key) {
      case 'all':
        newStart = DateTime(1970, 1, 1);
        break;
      case '1year':
        newStart = today.subtract(const Duration(days: 365));
        break;
      case '30days':
        newStart = today.subtract(const Duration(days: 30));
        break;
      case '7days':
        newStart = today.subtract(const Duration(days: 7));
        break;
      default:
        return;
    }

    setState(() {
      _selectedShortcut = key;
      _start = newStart;
      _end = newEnd;
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showOriginDatePicker(
      context,
      initial: _start,
      mode: OriginDatePickerMode.ymd,
      maxDate: _end,
    );
    if (picked != null) {
      setState(() {
        _selectedShortcut = null;
        _start = picked;
        if (_start.isAfter(_end)) {
          _end = _start;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showOriginDatePicker(
      context,
      initial: _end,
      mode: OriginDatePickerMode.ymd,
      minDate: _start,
      maxDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _selectedShortcut = null;
        _end = picked;
        if (_end.isBefore(_start)) {
          _start = _end;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF242424) : const Color(0xFFF7F7F8);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              title: '自定义时间',
              onClose: () => Navigator.of(context).pop(),
            ),

            const SizedBox(height: 14),

            // 快捷选择
            Text(
              '快捷选择',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OriginTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildShortcutButton('全部', 'all', cardBg),
                const SizedBox(width: 8),
                _buildShortcutButton('近一年', '1year', cardBg),
                const SizedBox(width: 8),
                _buildShortcutButton('近30天', '30days', cardBg),
                const SizedBox(width: 8),
                _buildShortcutButton('近7天', '7days', cardBg),
              ],
            ),

            const SizedBox(height: 20),

            // 自定义范围
            Text(
              '自定义',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OriginTokens.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _formatDate(_start),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    '—',
                    style: TextStyle(
                      fontSize: 16,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndDate,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _formatDate(_end),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            // 确定按钮
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSelected(_start, _end);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '确定',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutButton(String label, String key, Color defaultBg) {
    final isSelected = _selectedShortcut == key;
    final bg = isSelected
        ? widget.primaryColor.withValues(alpha: 0.12)
        : defaultBg;
    final textColor = isSelected
        ? widget.primaryColor
        : OriginTokens.textPrimary(context);

    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _applyShortcut(key),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部抽屉统一居中标题栏与右上角关闭
class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: OriginSheetTokens.titleFontSize,
              fontWeight: FontWeight.w600,
              color: OriginTokens.textPrimary(context),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 22),
              color: OriginTokens.textSecondary(context),
              tooltip: '关闭',
            ),
          ),
        ],
      ),
    );
  }
}

/// 圆形导航切换箭头按钮
class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;

  const _CircleNavButton({
    required this.icon,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 20,
            color: OriginTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
