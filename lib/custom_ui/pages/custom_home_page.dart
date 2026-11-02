import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/avatar_providers.dart';
import '../../utils/month_range.dart';
import '../../utils/format_money.dart';
import '../../utils/format_utils.dart';
import '../../utils/currencies.dart';
import '../widgets/origin_transaction_feed.dart';
import 'custom_ledgers_page.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_date_picker.dart';
import '../../pages/shared/widgets/feature_dot.dart';
import '../../pages/transaction/search_page.dart';
import '../../providers/budget_providers.dart';
import 'custom_budget_page.dart';
import 'custom_ai_chat_page.dart';

import '../../providers/shared_ledger_providers.dart';
import '../../providers/home_startup_preview_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../providers/amount_format_provider.dart';
import '../widgets/origin_hero_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_menu.dart';
import 'custom_mine_page.dart';

/// 今日支出缓存值（避免刷新闪烁）
final lastTodayExpenseProvider =
    StateProvider.family<double?, int>((ref, ledgerId) => null);

/// 今日支出 Provider（响应统计刷新 tick 与当前账本）
final todayExpenseProvider =
    FutureProvider.family.autoDispose<double, int>((ref, ledgerId) async {
  ref.watch(statsRefreshProvider);
  if (ledgerId <= 0) return 0.0;
  final repo = ref.watch(repositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final categories = await repo.totalsByCategory(
    ledgerId: ledgerId,
    type: 'expense',
    start: today,
    end: tomorrow,
  );
  var sum = 0.0;
  for (final c in categories) {
    sum += c.total;
  }
  ref.read(lastTodayExpenseProvider(ledgerId).notifier).state = sum;
  return sum;
});

/// vivo OriginOS 风格流水看板首页 (CustomHomePage)
///
/// 遵循 `OriginUI/docs/` 规范：
/// 1. 大标题栏（84dp / 22sp SemiBold）展示账本与月份切换；
/// 2. 纯色 12dp 卡片呈现月度收支与预算；
/// 3. 日间 #F4F4F6，夜间 #000000 纯正黑底；
/// 4. 纯 Riverpod 驱动，不修改原有流水数据查询与数据库逻辑。
class CustomHomePage extends ConsumerStatefulWidget {
  const CustomHomePage({super.key});

  @override
  ConsumerState<CustomHomePage> createState() => _CustomHomePageState();
}

class _CustomHomePageState extends ConsumerState<CustomHomePage> {
  late FlutterListViewController _listController;
  HomeStartupPreview? _startupPreview;
  final GlobalKey<OriginTransactionListState> _transactionListKey =
      GlobalKey<OriginTransactionListState>();
  final Set<String> _visibleHeaders = {};
  Timer? _debounceTimer;
  bool _showStickyMonthBar = false;

  @override
  void initState() {
    super.initState();
    _listController = FlutterListViewController();
    _startupPreview = ref
        .read(homeStartupPreviewHandoffProvider)
        .take(ref.read(repositoryProvider), ref.read(currentLedgerIdProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupPreview = null;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _listController.dispose();
    super.dispose();
  }

  void _openAIChat() {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomAIChatPage()),
    );
  }

  void _openSearch({bool batch = false, bool filters = false}) {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPage(
          initialBatchMode: batch,
          initialOpenFilter: filters,
        ),
      ),
    );
  }

  void _openMinePage() {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomMinePage()),
    );
  }

  void _openBudgetPage() {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomBudgetPage()),
    );
  }

  Future<void> _handleDateSelection() async {
    final month = ref.read(selectedMonthProvider);
    final res = await showOriginDatePicker(
      context,
      initial: month,
      mode: OriginDatePickerMode.ym,
      maxDate: DateTime.now(),
    );
    if (res != null && mounted) {
      final targetMonth = DateTime(res.year, res.month, 1);
      ref.read(selectedMonthProvider.notifier).state = targetMonth;
      _transactionListKey.currentState?.jumpToMonth(
        targetMonth,
        startDay: ref.read(currentMonthStartDayProvider),
      );
    }
  }

  void _openLedgerPicker() {
    final ledger = ref.read(currentLedgerProvider).valueOrNull;
    if (ledger == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CustomLedgersPage(autoOpenCreateDialog: true),
        ),
      );
    } else {
      showOriginLedgerPickerDialog(context);
    }
  }

  void _onHeaderVisibilityChanged(String dateKey, bool visible) {
    if (visible) {
      _visibleHeaders.add(dateKey);
    } else {
      _visibleHeaders.remove(dateKey);
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), _updateCurrentMonth);
  }

  void _updateCurrentMonth() {
    if (!mounted || _visibleHeaders.isEmpty) return;
    try {
      final sortedDates = _visibleHeaders.toList()..sort((a, b) => b.compareTo(a));
      final topDateKey = sortedDates.first;
      final parts = topDateKey.split('-');
      if (parts.length != 3) return;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final sd = ref.read(currentMonthStartDayProvider);
      final detectedMonth = labelForDate(DateTime(year, month, day), sd);
      final currentSelected = ref.read(selectedMonthProvider);
      if (currentSelected.year != detectedMonth.year ||
          currentSelected.month != detectedMonth.month) {
        ref.read(selectedMonthProvider.notifier).state = detectedMonth;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final month = ref.watch(selectedMonthProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final avatarPath = ref.watch(avatarPathProvider).asData?.value;
    ref.watch(thousandSeparatorProvider);

    final params = (ledgerId: ledgerId, month: month);
    ref.watch(monthlyTotalsProvider(params));
    final (income, expense) =
        ref.watch(lastMonthlyTotalsProvider(params)) ?? (0.0, 0.0);
    final currency = ledger?.currency ?? 'CNY';
    final currencySymbol = getCurrencySymbol(currency);
    final isPrimaryLight =
        ThemeData.estimateBrightnessForColor(primaryColor) == Brightness.light;
    final cardMainTextColor =
        isPrimaryLight ? const Color(0xFF1D1D1F) : Colors.white;
    final cardUnitText = currency == 'CNY' ? '元' : currencySymbol;
    final showCurrency = ref.watch(currencySymbolVisibleProvider);
    final symbolPrefix = showCurrency ? '$currencySymbol ' : '';

    // 今日支出与预算数据
    final todayExpenseAsync = ref.watch(todayExpenseProvider(ledgerId));
    final todayExpense = todayExpenseAsync.valueOrNull ??
        ref.watch(lastTodayExpenseProvider(ledgerId)) ??
        0.0;
    final showBudgetOnHome = ref.watch(homeBudgetCardEnabledProvider);
    final budgetOverview = showBudgetOnHome
        ? ref.watch(budgetOverviewProvider).valueOrNull
        : null;
    final budgetUsage = budgetOverview?.totalBudget;

    final initialPreview =
        _startupPreview?.matches(ref.watch(repositoryProvider), ledgerId) == true
            ? _startupPreview
            : null;

    // 监听外部滚动到顶部与切换流信号
    ref.listen<int>(homeScrollToTopProvider, (prev, next) {
      if (prev != next) {
        _transactionListKey.currentState?.jumpToTop();
        if (_showStickyMonthBar) {
          setState(() {
            _showStickyMonthBar = false;
          });
        }
      }
    });

    ref.listen<int>(homeSwitchToStreamProvider, (prev, next) {
      if (prev != next) {
        _transactionListKey.currentState?.switchToStreamMode();
      }
    });

    ref.listen<int>(sharedResourceRefreshProvider, (prev, next) {
      if (prev != next) {
        _transactionListKey.currentState?.forceStreamModeImmediate();
      }
    });

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: ledger != null
            ? translateLedgerName(context, ledger.name)
            : '日常账本',
        showDropdown: true,
        onTitleTap: _openLedgerPicker,
        actions: [
          // vivo OriginOS 规范：右上角“竖排双圆点”展示更多设置与功能入口
          FeatureDot(
            anchor: 'tab_mine',
            offset: const Offset(-2, 0),
            child: OriginMoreButton(
              tooltip: '设置与功能',
              items: [
                OriginMenuItem(
                  title: '多选',
                  icon: const Icon(Icons.check_box_outlined),
                  onTap: () => _openSearch(batch: true),
                ),
                OriginMenuItem(
                  title: l10n.budgetTitle,
                  icon: const Icon(Icons.pie_chart_outline_rounded),
                  onTap: _openBudgetPage,
                ),
                OriginMenuItem(
                  title: l10n.aiChatTitle,
                  icon: Icon(
                    Icons.auto_awesome_rounded,
                    color: primaryColor,
                  ),
                  onTap: _openAIChat,
                ),
                OriginMenuItem(
                  title: l10n.tabMine,
                  icon: avatarPath != null
                      ? Container(
                          width: 20.0,
                          height: 20.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: FileImage(File(avatarPath)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : const Icon(Icons.person_outline_rounded),
                  onTap: _openMinePage,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. 流水列表（外层包裹滚动通知监听，感知上滑进入明细区域）
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis == Axis.vertical) {
                final show = notification.metrics.pixels > 65.0;
                if (show != _showStickyMonthBar) {
                  setState(() {
                    _showStickyMonthBar = show;
                  });
                }
              }
              return false;
            },
            child: OriginTransactionFeed(
              header: Column(
                children: [
                  // 1. 收支与预算看板卡片 (采用统一 OriginHeroCard，统一 19.0dp 圆角)
                  OriginHeroCard(
                    title: l10n.todayExpense,
                    unit: cardUnitText,
                    mainAmount:
                        '$symbolPrefix${formatMoneyCompact(todayExpense, trimZeros: false)}',
                    hideAmounts: hideAmounts,
                    metrics: [
                      OriginHeroMetric(
                        label: l10n.monthExpense,
                        unit: cardUnitText,
                        value:
                            '$symbolPrefix${formatMoneyCompact(expense, trimZeros: false)}',
                      ),
                      OriginHeroMetric(
                        label: l10n.monthIncome,
                        unit: cardUnitText,
                        value:
                            '$symbolPrefix${formatMoneyCompact(income, trimZeros: false)}',
                      ),
                    ],
                    bottomChild: budgetUsage == null
                        ? null
                        : ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(OriginTokens.heroCardRadius),
                              bottomRight: Radius.circular(OriginTokens.heroCardRadius),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openBudgetPage,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18.0,
                                    vertical: 10.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            '月预算剩余 ${hideAmounts ? '****' : '$symbolPrefix${formatMoneyCompact(budgetUsage.remaining, trimZeros: false)}'}',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w600,
                                              color: cardMainTextColor.withValues(alpha: 0.85),
                                            ),
                                          ),
                                          Text(
                                            '${l10n.budgetUsed} ${(budgetUsage.rate * 100).clamp(0, 999).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w600,
                                              color: budgetUsage.rate >= 1.0
                                                  ? OriginTokens.expenseRed
                                                  : cardMainTextColor.withValues(alpha: 0.75),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8.0),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4.0),
                                        child: SizedBox(
                                          height: 5.5,
                                          child: LinearProgressIndicator(
                                            value: budgetUsage.rate.clamp(0.0, 1.0),
                                            backgroundColor: Colors.white.withValues(alpha: 0.65),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              budgetUsage.rate >= 1.0
                                                  ? OriginTokens.expenseRed
                                                  : primaryColor,
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
                  ),

                  // 预算卡片与明细列表之间的间距（隐藏提醒模块）
                  const SizedBox(height: 8.0),
                ],
              ),
              startupPreview: initialPreview,
              ledgerId: ledgerId,
              hideAmounts: hideAmounts,
              listKey: _transactionListKey,
              controller: _listController,
              onDateVisibilityChanged: _onHeaderVisibilityChanged,
              onBatch: () => _openSearch(batch: true),
              emptyWidget: BeeEmptyState(
                title: l10n.homeNoRecords,
                message: l10n.homeNoRecordsSubtext,
              ),
            ),
          ),

          // 2. 吸顶月份与收支悬浮条（明细上滑到页面上方时显现，支持快速调节月份，右侧呈现收支）
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              offset: _showStickyMonthBar ? Offset.zero : const Offset(0, -0.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                opacity: _showStickyMonthBar ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showStickyMonthBar,
                  child: _buildStickyMonthBar(
                    context,
                    month: month,
                    expense: expense,
                    income: income,
                    hideAmounts: hideAmounts,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 吸顶月份与收支统计条（上滑悬浮固定，参考 OriginOS 与图片设计）
  Widget _buildStickyMonthBar(
    BuildContext context, {
    required DateTime month,
    required double expense,
    required double income,
    required bool hideAmounts,
  }) {
    final expenseStr = hideAmounts
        ? '****'
        : formatMoneyCompact(expense, maxDecimals: 2, trimZeros: false);
    final incomeStr = hideAmounts
        ? '****'
        : formatMoneyCompact(income, maxDecimals: 2, trimZeros: false);

    return Container(
      height: 44.0,
      color: OriginTokens.pageBackground(context),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OriginTokens.cardMargin,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 左侧：当前月份（点击可快速调节）
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleDateSelection,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${month.year}年${month.month}月',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            color: OriginTokens.textPrimary(context),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 2.0),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20.0,
                          color: OriginTokens.textTertiary(context),
                        ),
                      ],
                    ),
                  ),

                  // 右侧：支出与收入统计 (支 228.43  收 0.00)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '支 ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                      Text(
                        expenseStr,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Text(
                        '收 ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                      Text(
                        incomeStr,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const OriginDivider(startIndent: 0),
        ],
      ),
    );
  }
}
