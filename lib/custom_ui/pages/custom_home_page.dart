import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/avatar_providers.dart';
import '../../utils/month_range.dart';
import '../../utils/format_money.dart';
import '../../utils/currencies.dart';
import '../widgets/origin_transaction_feed.dart';
import '../../pages/main/home/widgets/home_reminders.dart';
import '../../pages/main/ledgers_page_new.dart';
import '../../pages/shared/selectors/ledger_picker_sheet.dart';
import '../../pages/shared/pickers/wheel_date_picker.dart';
import '../../pages/shared/widgets/feature_dot.dart';
import '../../pages/transaction/search_page.dart';
import '../../pages/report/annual_report_page.dart';
import '../../pages/ai/ai_chat_page.dart';
import '../../services/export/share_poster_service.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../providers/home_startup_preview_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import 'custom_mine_page.dart';

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
      MaterialPageRoute(builder: (_) => const AIChatPage()),
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

  Future<void> _handleDateSelection() async {
    final month = ref.read(selectedMonthProvider);
    final res = await showWheelDatePicker(
      context,
      initial: month,
      mode: WheelDatePickerMode.ym,
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
          builder: (_) => const LedgersPageNew(autoOpenCreateDialog: true),
        ),
      );
    } else {
      showLedgerPicker(context);
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

    final params = (ledgerId: ledgerId, month: month);
    ref.watch(monthlyTotalsProvider(params));
    final (income, expense) =
        ref.watch(lastMonthlyTotalsProvider(params)) ?? (0.0, 0.0);
    final balance = income - expense;
    final currency = ledger?.currency ?? 'CNY';
    final currencySymbol = getCurrencySymbol(currency);

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
        title: ledger?.name ?? '日常账本',
        actions: [
          // 账本切换按钮
          IconButton(
            icon: const Icon(Icons.book_outlined),
            tooltip: '切换账本',
            onPressed: _openLedgerPicker,
          ),
          // 我的 / 个人中心入口按钮（支持头像与新功能红点）
          IconButton(
            tooltip: l10n.tabMine,
            onPressed: _openMinePage,
            icon: FeatureDot(
              anchor: 'tab_mine',
              offset: const Offset(-2, 0),
              child: avatarPath != null
                  ? Container(
                      width: 24.0,
                      height: 24.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        image: DecorationImage(
                          image: FileImage(File(avatarPath)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : const Icon(Icons.person_outline_rounded),
            ),
          ),
          // AI 按钮（居最右侧）
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, color: primaryColor),
            tooltip: l10n.aiChatTitle,
            onPressed: _openAIChat,
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
                  // 1. 月度收支看板卡片（彻底移除“支出”字样，大金额与小眼睛同行，收缩卡片高度）
                  OriginCard(
                    onTap: _handleDateSelection,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              hideAmounts
                                  ? '****'
                                  : '$currencySymbol ${formatMoneyCompact(expense)}',
                              style: TextStyle(
                                fontSize: 26.0,
                                fontWeight: FontWeight.bold,
                                color: OriginTokens.textPrimary(context),
                                letterSpacing: -0.5,
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                hideAmounts
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20.0,
                                color: OriginTokens.textTertiary(context),
                              ),
                              onPressed: () {
                                ref.read(hideAmountsProvider.notifier).state =
                                    !hideAmounts;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10.0),
                        const OriginDivider(startIndent: 0),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '本月收入',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: OriginTokens.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 3.0),
                                  Text(
                                    hideAmounts
                                        ? '****'
                                        : '$currencySymbol ${formatMoneyCompact(income)}',
                                    style: const TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w600,
                                      color: OriginTokens.incomeGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '月度结余',
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: OriginTokens.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 3.0),
                                  Text(
                                    hideAmounts
                                        ? '****'
                                        : '$currencySymbol ${formatMoneyCompact(balance)}',
                                    style: TextStyle(
                                      fontSize: 15.0,
                                      fontWeight: FontWeight.w600,
                                      color: balance < 0
                                          ? OriginTokens.expenseRed
                                          : OriginTokens.textPrimary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. 提醒模块 (月度报告、年度账单、预算提醒)
                  HomeReminders(
                    onMonthly: (m) =>
                        SharePosterService.showPosterCarouselPreview(
                      context,
                      year: m.year,
                      month: m.month,
                    ),
                    onAnnual: (y) => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AnnualReportPage(initialYear: y),
                      ),
                    ),
                    onBudget: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AnnualReportPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
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
