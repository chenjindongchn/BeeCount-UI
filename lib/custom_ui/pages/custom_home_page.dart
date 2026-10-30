import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../utils/month_range.dart';
import '../../utils/format_money.dart';
import '../../utils/currencies.dart';
import '../../pages/main/home/widgets/home_reminders.dart';
import '../../pages/main/home/widgets/home_journal.dart';
import '../../pages/main/home/bindings/home_transaction_feed.dart';
import '../../pages/main/home/bindings/transaction_list.dart';
import '../../pages/main/ledgers_page_new.dart';
import '../../pages/shared/selectors/ledger_picker_sheet.dart';
import '../../pages/shared/pickers/wheel_date_picker.dart';
import '../../pages/transaction/search_page.dart';
import '../../pages/calendar/calendar_page.dart';
import '../../pages/report/annual_report_page.dart';
import '../../pages/ai/ai_chat_page.dart';
import '../../services/export/share_poster_service.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../providers/home_startup_preview_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';

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
  final _pageScrollController = ScrollController();
  final _journalFrameKey = GlobalKey();
  final GlobalKey<TransactionListState> _transactionListKey =
      GlobalKey<TransactionListState>();
  final Set<String> _visibleHeaders = {};
  Timer? _debounceTimer;

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
    _pageScrollController.dispose();
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

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarPage()),
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
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
        _transactionListKey.currentState?.jumpToTop();
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

    final monthStr = '${month.year}年${month.month}月';

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: ledger?.name ?? '日常账本',
        subtitle: monthStr,
        actions: [
          // 账本切换按钮
          IconButton(
            icon: const Icon(Icons.book_outlined),
            tooltip: '切换账本',
            onPressed: _openLedgerPicker,
          ),
          // AI 按钮
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, color: primaryColor),
            tooltip: l10n.aiChatTitle,
            onPressed: _openAIChat,
          ),
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: l10n.homeSearch,
            onPressed: () => _openSearch(),
          ),
          // 日历按钮
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '日历看板',
            onPressed: _openCalendar,
          ),
        ],
      ),
      body: NestedScrollView(
        controller: _pageScrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 1. 月度收支看板大卡片 (vivo OriginOS 12dp 卡片)
                OriginCard(
                  onTap: _handleDateSelection,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$monthStr 支出',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: OriginTokens.textSecondary(context),
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16.0,
                                color: OriginTokens.textTertiary(context),
                              ),
                            ],
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              hideAmounts
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18.0,
                              color: OriginTokens.textTertiary(context),
                            ),
                            onPressed: () {
                              ref.read(hideAmountsProvider.notifier).state =
                                  !hideAmounts;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        hideAmounts
                            ? '****'
                            : '$currencySymbol ${formatMoneyCompact(expense)}',
                        style: TextStyle(
                          fontSize: 28.0,
                          fontWeight: FontWeight.bold,
                          color: OriginTokens.textPrimary(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14.0),
                      const OriginDivider(startIndent: 0),
                      const SizedBox(height: 12.0),
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
          ),
        ],
        body: HomeJournalFrame(
          key: _journalFrameKey,
          initialPreview: initialPreview?.preview,
          onCalendar: _openCalendar,
          onFilter: () => _openSearch(filters: true),
          onBatch: () => _openSearch(batch: true),
          childBuilder: (onPreviewReady) => HomeTransactionFeed(
            startupPreview: initialPreview,
            onPreviewReady: onPreviewReady,
            ledgerId: ledgerId,
            hideAmounts: hideAmounts,
            listKey: _transactionListKey,
            controller: _listController,
            onDateVisibilityChanged: _onHeaderVisibilityChanged,
            emptyWidget: BeeEmptyState(
              title: l10n.homeNoRecords,
              message: l10n.homeNoRecordsSubtext,
            ),
          ),
        ),
      ),
    );
  }
}
