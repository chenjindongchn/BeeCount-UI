import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/shared/pickers/wheel_date_picker.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/calendar_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/format_money.dart';
import '../../utils/transaction_edit_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_transaction_item.dart';
import '../widgets/origin_empty_state.dart';
import 'custom_transaction_sheet.dart';

String _calendarDateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _calendarCompactAmount(double amount, String sign) => amount >= 10000
    ? '$sign${(amount / 10000).toStringAsFixed(1)}w'
    : amount >= 1000
        ? '$sign${(amount / 1000).toStringAsFixed(1)}k'
        : '$sign${amount.toInt()}';

/// vivo OriginOS 风格日历看板页面 (CustomCalendarPage)
///
/// 遵循 OriginUI 规范：
/// 1. 采用 [OriginScaffold] 与 [OriginSmallTopAppBar]，具备通透背景与沉浸式顶栏；
/// 2. 日历整体嵌入 [OriginCard]，视觉层级清晰；
/// 3. 日历单元格定制 OriginOS 规范 Squircle 圆角高亮与柔和金额微标；
/// 4. 移除原当日标头微小加号，页面核心记账操作统一置底为胶囊大按钮（46dp/23dp）；
/// 5. 点击置底记账按钮与单条交易条目，直接唤起定制记账抽屉 [showCustomTransactionSheet]，
///    自动带入选中日期，保存后平滑刷新日历与当日明细；
/// 6. 当日明细区展示选中日期的收支小计，强化“看板（Dashboard）”属性，支持长按删除与单击编辑。
class CustomCalendarPage extends ConsumerStatefulWidget {
  const CustomCalendarPage({super.key});

  @override
  ConsumerState<CustomCalendarPage> createState() => _CustomCalendarPageState();
}

class _CustomCalendarPageState extends ConsumerState<CustomCalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;
  final Map<String, (double, double)> _totalsCache = {};

  static final DateTime _calFirstDay = DateTime(2000, 1, 1);

  DateTime get _calLastDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(const Duration(days: 365));
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
      ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
    ref.read(calendarSelectedDateProvider.notifier).state = selectedDay;
  }

  void _onPageChanged(DateTime focusedMonth) {
    setState(() {
      _focusedMonth = focusedMonth;
      _selectedDay = null;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = null;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
  }

  Future<void> _showMonthJumpPicker() async {
    final picked = await showWheelDatePicker(
      context,
      initial: _focusedMonth,
      mode: WheelDatePickerMode.ym,
      minDate: _calFirstDay,
      maxDate: _calLastDay,
    );
    if (picked == null || !mounted) return;
    _jumpToMonth(picked);
  }

  void _jumpToMonth(DateTime target) {
    var month = DateTime(target.year, target.month, 1);
    if (month.isBefore(_calFirstDay)) {
      month = DateTime(_calFirstDay.year, _calFirstDay.month, 1);
    }
    final lastDay = _calLastDay;
    if (month.isAfter(lastDay)) {
      month = DateTime(lastDay.year, lastDay.month, 1);
    }

    setState(() {
      _focusedMonth = month;
      _selectedDay = null;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = month;
    ref.read(calendarSelectedDateProvider.notifier).state = null;
  }

  Future<void> _addTransactionForSelectedDate() async {
    final base = _selectedDay ??
        (_focusedMonth.year == DateTime.now().year &&
                _focusedMonth.month == DateTime.now().month
            ? DateTime.now()
            : _focusedMonth);
    final initialDate = DateTime(base.year, base.month, base.day, 12, 0, 0);

    final saved = await showCustomTransactionSheet(
      context,
      initialKind: 'expense',
      initialDate: initialDate,
    );

    if (saved == true && mounted) {
      ref.read(calendarRefreshProvider.notifier).state++;
    }
  }

  Future<void> _deleteTransaction(Transaction t) async {
    final confirmed = await showOriginConfirmDialog(
      context,
      title: '确定要删除该条账单吗？',
      message: '删除后将不可恢复。',
      confirmText: '删除',
      cancelText: '取消',
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(repositoryProvider);
        await repo.deleteTransaction(t.id);
        final curLedger = ref.read(currentLedgerIdProvider);
        ref.invalidate(countsForLedgerProvider(curLedger));
        ref.read(calendarRefreshProvider.notifier).state++;
        ref.read(statsRefreshProvider.notifier).state++;
        ref.read(budgetRefreshProvider.notifier).state++;
        PostProcessor.sync(ref, ledgerId: curLedger);
        if (mounted) {
          showBeeToast(context, '删除成功');
        }
      } catch (e) {
        if (mounted) {
          showBeeToast(context, '删除失败: $e', tone: BeeTone.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final key = (ledgerId: ledgerId, month: _focusedMonth);
    final totalsAsync = ref.watch(dailyTotalsByMonthProvider(key));
    final primaryColor = Theme.of(context).colorScheme.primary;
    // 监听全局记账刷新信号，刷新时重置缓存重新拉取
    ref.listen<int>(calendarRefreshProvider, (prev, next) {
      if (prev != next) {
        _totalsCache.clear();
      }
    });

    // 当异步数据就绪时，静默合并入月度缓存
    if (totalsAsync.hasValue && totalsAsync.value != null) {
      _totalsCache.addAll(totalsAsync.value!);
    }

    // 浅拷贝当前有效数据传递给日历
    final currentTotals = Map<String, (double, double)>.from(_totalsCache);

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        leading: const BackButton(),
        title: l.calendarTitle,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _jumpToToday,
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(l.calendarToday),
          ),
        ],
      ),
      // 日历与页面骨架永久常驻，数据静默更新，绝不卸载重绘产生整屏闪烁
      body: _buildContent(context, l, locale, ledgerId, currentTotals),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OriginTokens.cardMargin,
            vertical: 12.0,
          ),
          child: SizedBox(
            height: OriginTokens.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(OriginTokens.buttonRadius),
                ),
              ),
              onPressed: _addTransactionForSelectedDate,
              child: Text(
                l.widgetQuickAddLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l,
    String locale,
    int ledgerId,
    Map<String, (double, double)> totals,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // 1. 日历主卡片 (嵌入 OriginCard，采用紧凑高空间利用率排版)
          OriginCard(
            margin: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                _buildMonthHeader(context, locale),
                _buildTableCalendar(context, locale, totals),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 2. 当日明细 Section (若有选中日期)
          if (_selectedDay != null) ...[
            _buildDayHeading(context, locale, totals),
            const SizedBox(height: 6),
            _buildDayTransactionsCard(context, ledgerId, _selectedDay!),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context, String locale) {
    final previous = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    final canPrev =
        !previous.isBefore(DateTime(_calFirstDay.year, _calFirstDay.month));
    final canNext = !next.isAfter(_calLastDay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 2, 4),
      child: Row(
        children: [
          // 年月选择器触发按钮
          GestureDetector(
            onTap: _showMonthJumpPicker,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.yMMMM(locale).format(_focusedMonth),
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: OriginTokens.textPrimary(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 20,
                    color: OriginTokens.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // 上个月
          IconButton(
            onPressed: canPrev ? () => _jumpToMonth(previous) : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: OriginTokens.textPrimary(context),
              disabledForegroundColor:
                  OriginTokens.textTertiary(context).withValues(alpha: 0.3),
            ),
            tooltip: '上一月',
          ),
          const SizedBox(width: 6),
          // 下个月
          IconButton(
            onPressed: canNext ? () => _jumpToMonth(next) : null,
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: OriginTokens.textPrimary(context),
              disabledForegroundColor:
                  OriginTokens.textTertiary(context).withValues(alpha: 0.3),
            ),
            tooltip: '下一月',
          ),
        ],
      ),
    );
  }

  Widget _buildTableCalendar(
    BuildContext context,
    String locale,
    Map<String, (double, double)> totals,
  ) {
    final scaler = MediaQuery.textScalerOf(context);

    Widget cell(
      BuildContext context,
      DateTime day,
      DateTime month, {
      bool outside = false,
    }) {
      return _buildDayCell(context, day, totals, outside: outside);
    }

    return TableCalendar<void>(
      locale: locale,
      firstDay: _calFirstDay,
      lastDay: _calLastDay,
      focusedDay: _focusedMonth,
      headerVisible: false,
      pageAnimationEnabled: TickerMode.valuesOf(context).enabled &&
          !MediaQuery.disableAnimationsOf(context),
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
      rowHeight: 48 * scaler.scale(1).clamp(1.0, 1.25),
      daysOfWeekHeight: 22,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: OriginTokens.textTertiary(context),
        ),
        weekendStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: OriginTokens.textTertiary(context),
        ),
      ),
      calendarBuilders: CalendarBuilders<void>(
        defaultBuilder: cell,
        todayBuilder: cell,
        selectedBuilder: cell,
        outsideBuilder: (c, d, m) => cell(c, d, m, outside: true),
        disabledBuilder: (c, d, m) => cell(c, d, m, outside: true),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    Map<String, (double, double)> totals, {
    bool outside = false,
  }) {
    final (income, expense) = totals[_calendarDateKey(day)] ?? (0.0, 0.0);
    final isSelected = _selectedDay != null && isSameDay(day, _selectedDay);
    final isToday = isSameDay(day, DateTime.now());
    final primaryColor = Theme.of(context).colorScheme.primary;

    final incomeExpenseIsRed = ref.watch(incomeExpenseColorSchemeProvider);
    final expenseColor = beeTransactionColor(
      context,
      BeeTransactionKind.expense,
      incomeIsRed: incomeExpenseIsRed,
    );
    final incomeColor = beeTransactionColor(
      context,
      BeeTransactionKind.income,
      incomeIsRed: incomeExpenseIsRed,
    );

    final fg = isSelected
        ? Colors.white
        : (outside
            ? OriginTokens.textTertiary(context).withValues(alpha: 0.35)
            : OriginTokens.textPrimary(context));

    final hasExpense = !outside && expense > 0;
    final hasIncome = !outside && income > 0;
    final hasBoth = hasExpense && hasIncome;

    // 自适应字号，确保在 48dp 紧凑行高中优雅居中且不拥挤
    final double dayFontSize = hasBoth ? 12.0 : (hasExpense || hasIncome ? 13.0 : 14.5);
    final double amountFontSize = hasBoth ? 8.8 : 9.5;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isToday
                  ? primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10.0),
          border: isToday && !isSelected
              ? Border.all(
                  color: primaryColor.withValues(alpha: 0.55),
                  width: 1.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: dayFontSize,
                height: 1.1,
                fontWeight:
                    isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (hasExpense) ...[
              const SizedBox(height: 1),
              Text(
                _calendarCompactAmount(expense, '-'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: amountFontSize,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.95)
                      : expenseColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            if (hasIncome) ...[
              const SizedBox(height: 1),
              Text(
                _calendarCompactAmount(income, '+'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: amountFontSize,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.95)
                      : incomeColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeading(
    BuildContext context,
    String locale,
    Map<String, (double, double)> totals,
  ) {
    if (_selectedDay == null) return const SizedBox.shrink();
    final day = _selectedDay!;
    final (income, expense) = totals[_calendarDateKey(day)] ?? (0.0, 0.0);
    final isToday = isSameDay(day, DateTime.now());

    final incomeExpenseIsRed = ref.watch(incomeExpenseColorSchemeProvider);
    final expenseColor = beeTransactionColor(
      context,
      BeeTransactionKind.expense,
      incomeIsRed: incomeExpenseIsRed,
    );
    final incomeColor = beeTransactionColor(
      context,
      BeeTransactionKind.income,
      incomeIsRed: incomeExpenseIsRed,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OriginTokens.cardMargin,
        vertical: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            DateFormat.MMMMd(locale).format(day),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: OriginTokens.textPrimary(context),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat.E(locale).format(day),
            style: TextStyle(
              fontSize: 13,
              color: OriginTokens.textTertiary(context),
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '今天',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          // 当日看板收支统计概览
          if (expense > 0 || income > 0) ...[
            if (expense > 0)
              Text(
                '支 ${formatMoneyCompact(expense)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: expenseColor,
                ),
              ),
            if (expense > 0 && income > 0) const SizedBox(width: 10),
            if (income > 0)
              Text(
                '收 ${formatMoneyCompact(income)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: incomeColor,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTransactionsCard(
    BuildContext context,
    int ledgerId,
    DateTime date,
  ) {
    final key = (ledgerId: ledgerId, date: date);
    final rowsAsync = ref.watch(transactionsByDateProvider(key));

    return OriginCard(
      margin: const EdgeInsets.symmetric(
        horizontal: OriginTokens.cardMargin,
      ),
      padding: EdgeInsets.zero,
      child: rowsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              '加载交易失败: $error',
              style: TextStyle(color: OriginTokens.textSecondary(context)),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: OriginEmptyState(
                iconData: Icons.event_note_rounded,
                title: '当日暂无记账记录',
                circleSize: 64.0,
                iconSize: 32.0,
                visualOffset: 0,
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const OriginDivider(startIndent: 60),
            itemBuilder: (context, index) {
              final item = items[index];
              return OriginTransactionItem(
                transaction: item.t,
                category: item.category,
                account: item.account,
                tags: item.tags,
                onTap: () async {
                  await TransactionEditUtils.editTransaction(
                    context,
                    ref,
                    item.t,
                    item.category,
                  );
                  if (mounted) {
                    ref.read(calendarRefreshProvider.notifier).state++;
                  }
                },
                onLongPress: () => _deleteTransaction(item.t),
              );
            },
          );
        },
      ),
    );
  }
}
