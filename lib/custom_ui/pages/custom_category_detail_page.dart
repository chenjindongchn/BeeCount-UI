import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' show Category;
import '../../l10n/app_localizations.dart';
import 'custom_category_edit_page.dart';
import 'custom_category_manage_page.dart';
import '../../pages/category/category_migration_page.dart';
import '../../pages/shared/currency/bindings/detail_currency_notice.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import 'package:flutter/services.dart';
import '../widgets/origin_report_period_sheets.dart';
import '../widgets/custom_transaction_tile.dart';
import '../../pages/transaction/category_detail/bindings/category_detail.dart';
import '../../pages/transaction/category_detail_page.dart'
    show categoryDetailSortProvider;
import '../../pages/transaction/search/bindings/transaction_search.dart';
import 'custom_search_page.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../providers/category_display_preferences_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_hero_card.dart';
import '../providers/amount_format_provider.dart';
import 'custom_transaction_sheet.dart';

/// vivo OriginOS 风格分类详情页面 (CustomCategoryDetailPage)
///
/// 1. 右上角采用 OriginOS 规范双圆点入口 (OriginMoreButton)，点击呼出高质感气泡菜单；
/// 2. 气泡菜单保留原分类功能（搜索、编辑、迁移、分类管理），并新增“累计金额趋势”勾选项；
/// 3. “累计金额趋势”默认关闭（不显示趋势图），点击切换打勾并实时控制页面内趋势卡片的展开/收起；
/// 4. 底部常驻 OriginUI 规范胶囊大按钮（“记一笔”），无缝联动 OriginOS 记账抽屉，保持设计语言高度一致。
class CustomCategoryDetailPage extends ConsumerStatefulWidget {
  const CustomCategoryDetailPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.startDate,
    this.endDate,
    this.periodLabel,
    this.allLedgers = false,
  });

  final int categoryId;
  final String categoryName;
  final DateTime? startDate, endDate;
  final String? periodLabel;
  final bool allLedgers;

  @override
  ConsumerState<CustomCategoryDetailPage> createState() =>
      _CustomCategoryDetailPageState();
}

class _CustomCategoryDetailPageState
    extends ConsumerState<CustomCategoryDetailPage> {
  CategoryDetailController? _data;
  bool _showAll = false;
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _customLabel;

  @override
  void initState() {
    super.initState();
    _customStart = widget.startDate;
    _customEnd = widget.endDate;
    _customLabel = widget.periodLabel;
  }

  @override
  void dispose() {
    _data?.dispose();
    super.dispose();
  }

  void _ensure(int? ledgerId, int summaryLedgerId) {
    if (_data != null &&
        _data!.ledgerId == ledgerId &&
        _data!.categoryId == widget.categoryId &&
        _data!.initialStart == _customStart &&
        _data!.initialEnd == _customEnd) {
      unawaited(_data!.setSummaryLedger(summaryLedgerId));
      return;
    }
    _data?.dispose();
    _data = CategoryDetailController(
      repository: ref.read(repositoryProvider),
      categoryId: widget.categoryId,
      ledgerId: ledgerId,
      summaryLedgerId: summaryLedgerId,
      initialStart: _customStart,
      initialEnd: _customEnd,
    )..sort = ref.read(categoryDetailSortProvider(widget.categoryId));
    unawaited(_data!.start());
  }

  void _setCustomRange(DateTime start, DateTime end) {
    setState(() {
      _showAll = false;
      _customStart = start;
      _customEnd = end;
      _customLabel = '${start.month}/${start.day}-${end.month}/${end.day}';
      final ledgerId = ref.read(currentLedgerIdProvider);
      _data?.dispose();
      _data = CategoryDetailController(
        repository: ref.read(repositoryProvider),
        categoryId: widget.categoryId,
        ledgerId: widget.allLedgers ? null : ledgerId,
        summaryLedgerId: ledgerId,
        initialStart: start,
        initialEnd: end,
      )..sort = ref.read(categoryDetailSortProvider(widget.categoryId));
      unawaited(_data!.start());
    });
  }

  Future<void> _openSearch() async {
    final c = _data!;
    final category = c.category;
    if (category == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomSearchPage(
          initialFilter: TransactionSearchFilter(
            category: category,
            start: c.range.start,
            end: c.range.end == null
                ? null
                : DateTime(
                    c.range.end!.year,
                    c.range.end!.month,
                    c.range.end!.day - 1,
                  ),
          ),
        ),
      ),
    );
    if (mounted) await c.refreshResources();
  }

  Future<void> _openEdit() async {
    final c = _data!;
    final category = c.category;
    if (category == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomCategoryEditPage(
          category: category,
          kind: category.kind,
        ),
      ),
    );
    if (mounted) await c.refreshResources();
  }

  Future<void> _openMigration() async {
    final c = _data!;
    final category = c.category;
    if (category == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            CategoryMigrationPage(preselectedFromCategory: category),
      ),
    );
    if (mounted) await c.refreshResources();
  }

  Future<void> _openManage() async {
    final c = _data!;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const CustomCategoryManagePage(),
      ),
    );
    if (mounted) await c.refreshResources();
  }

  Future<void> _record() async {
    final c = _data!, category = _data!.category;
    if (category == null) return;
    final saved = await showCustomTransactionSheet(
      context,
      initialKind: category.kind,
      initialCategoryId: category.id,
    );
    if (saved == true && mounted) {
      await c.refreshResources();
    }
  }

  Future<void> _child(Category child) async {
    final c = _data!, range = _data!.range;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomCategoryDetailPage(
          categoryId: child.id,
          categoryName: CategoryUtils.getDisplayName(
            child.name,
            context,
            kind: child.kind,
          ),
          allLedgers: widget.allLedgers,
          startDate: range.start,
          endDate: range.end,
          periodLabel: widget.periodLabel,
        ),
      ),
    );
    if (mounted) await c.refreshResources();
  }

  void _openMonthSheet(Color primaryColor) {
    final c = _data;
    if (c == null) return;
    showOriginMonthPickerSheet(
      context,
      selectedMonth: c.anchor,
      primaryColor: primaryColor,
      onSelected: (month) {
        setState(() => _showAll = false);
        c.chooseAnchor(month);
      },
    );
  }

  void _openYearSheet(Color primaryColor) {
    final c = _data;
    if (c == null) return;
    showOriginYearPickerSheet(
      context,
      selectedYear: c.anchor.year,
      primaryColor: primaryColor,
      onSelected: (year) {
        setState(() => _showAll = false);
        c.chooseAnchor(DateTime(year, 1));
      },
    );
  }

  void _openCustomRangeSheet(Color primaryColor) {
    final c = _data;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialS = _customStart ?? c?.range.start ?? today.subtract(const Duration(days: 30));
    final initialE = _customEnd ?? c?.range.end ?? today;

    showOriginCustomRangeSheet(
      context,
      start: initialS,
      end: initialE,
      primaryColor: primaryColor,
      onSelected: (start, end) {
        _setCustomRange(start, end);
      },
    );
  }

  void _movePeriod(int delta) {
    final c = _data;
    if (c == null) return;
    HapticFeedback.lightImpact();
    setState(() => _showAll = false);
    if (c.period == CategoryDetailPeriod.month) {
      c.chooseAnchor(DateTime(c.anchor.year, c.anchor.month + delta, 1));
    } else if (c.period == CategoryDetailPeriod.year) {
      c.chooseAnchor(DateTime(c.anchor.year + delta, c.anchor.month, 1));
    }
  }

  String _getPeriodDisplayLabel(CategoryDetailController c) {
    if (c.period == CategoryDetailPeriod.month) {
      return '${c.anchor.year}年${c.anchor.month}月';
    } else if (c.period == CategoryDetailPeriod.year) {
      return '${c.anchor.year}年';
    } else if (c.period == CategoryDetailPeriod.all) {
      return '全部时间';
    } else {
      if (_customLabel != null && _customLabel!.isNotEmpty) {
        return _customLabel!;
      }
      final s = c.range.start;
      final e = c.range.end;
      if (s != null && e != null) {
        return '${s.month}/${s.day}-${e.month}/${e.day}';
      }
      return '指定周期';
    }
  }

  void _changeSort(CategoryDetailSort newSort) {
    HapticFeedback.lightImpact();
    ref.read(categoryDetailSortProvider(widget.categoryId).notifier).state = newSort;
    _data?.chooseSort(newSort);
  }

  void _toggleTimeSort(CategoryDetailController c) {
    final isTimeActive =
        c.sort == CategoryDetailSort.timeDesc || c.sort == CategoryDetailSort.timeAsc;
    final isTimeDesc = c.sort == CategoryDetailSort.timeDesc;
    if (!isTimeActive) {
      _changeSort(CategoryDetailSort.timeDesc);
    } else {
      _changeSort(isTimeDesc ? CategoryDetailSort.timeAsc : CategoryDetailSort.timeDesc);
    }
  }

  void _toggleAmountSort(CategoryDetailController c) {
    final isAmountActive =
        c.sort == CategoryDetailSort.amountDesc || c.sort == CategoryDetailSort.amountAsc;
    final isAmountDesc = c.sort == CategoryDetailSort.amountDesc;
    if (!isAmountActive) {
      _changeSort(CategoryDetailSort.amountDesc);
    } else {
      _changeSort(isAmountDesc ? CategoryDetailSort.amountAsc : CategoryDetailSort.amountDesc);
    }
  }

  Future<void> _delete(int id, int ledgerId) async {
    final l = AppLocalizations.of(context);
    try {
      final repo = ref.read(repositoryProvider);
      final row = await repo.getTransactionById(id);
      if (row == null || row.ledgerId != ledgerId) {
        throw StateError('Transaction scope changed');
      }
      await repo.deleteTransaction(id);
      ref.invalidate(countsForLedgerProvider(ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      PostProcessor.sync(ref, ledgerId: ledgerId);
    } catch (e) {
      if (mounted) {
        showBeeToast(
          context,
          '${l.categoryDetailDeleteFailed}: $e',
          tone: BeeTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final showTrend = ref.watch(categoryDetailShowTrendProvider);

    _ensure(widget.allLedgers ? null : ledgerId, ledgerId);

    ref.listen(
      rateRefreshTickProvider,
      (_, __) => unawaited(_data?.refreshResources()),
    );
    ref.listen(
      statsRefreshProvider,
      (_, __) => unawaited(_data?.refreshResources()),
    );
    ref.listen(
      syncGenerationProvider,
      (_, __) => unawaited(_data?.refreshResources()),
    );
    ref.listen(currentLedgerProvider, (previous, next) {
      if (previous?.valueOrNull?.currency != next.valueOrNull?.currency) {
        unawaited(_data?.refreshResources());
      }
    });

    final c = _data!;
    final periodLabel = _getPeriodDisplayLabel(c);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final category = c.category;
        final displayName = category != null
            ? CategoryUtils.getDisplayName(
                category.name,
                context,
                kind: category.kind,
              )
            : widget.categoryName;

        return OriginScaffold(
          appBar: _CustomCategoryTopAppBar(
            backgroundColor: headerBg,
            title: displayName.isNotEmpty ? displayName : l.categoryDetailTooltip,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: OriginTokens.textPrimary(context),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // vivo OriginOS 规范：右上角“竖排双圆点”展示更多功能入口
              OriginMoreButton(
                tooltip: l.commonMore,
                items: [
                  // 1. 累计金额趋势开关选项（默认关闭，点击打勾开启）
                  OriginMenuItem(
                    title: l.v4DetailTrend,
                    icon: const Icon(Icons.show_chart_rounded),
                    trailing: showTrend
                        ? Icon(
                            Icons.check_rounded,
                            size: 18.0,
                            color: primaryColor,
                          )
                        : null,
                    onTap: () {
                      ref
                          .read(categoryDetailShowTrendProvider.notifier)
                          .toggle();
                    },
                  ),
                  if (!widget.allLedgers && category != null && category.id >= 0)
                    OriginMenuItem(
                      title: l.searchTitle,
                      icon: const Icon(Icons.search_rounded),
                      onTap: _openSearch,
                    ),
                  if (category != null && category.id >= 0) ...[
                    OriginMenuItem(
                      title: l.commonEdit,
                      icon: const Icon(Icons.edit_outlined),
                      onTap: _openEdit,
                    ),
                    OriginMenuItem(
                      title: l.categoryMigrationTooltip,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      onTap: _openMigration,
                    ),
                    OriginMenuItem(
                      title: l.mineCategoryManagement,
                      icon: const Icon(Icons.category_outlined),
                      onTap: _openManage,
                    ),
                  ],
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 顶部筛选控制面板（纯白/夜间深色，带发丝线底边，与洞察页面规范保持一致）
              if (c.category != null)
                Container(
                  decoration: BoxDecoration(
                    color: headerBg,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 第一行：本月 / 本年 / 全部 / 指定周期 Tab 切换
                      _buildTopTabBar(c, primaryColor),

                      // 第二行：时间调节（左） + 独立排序胶囊按钮（右，与洞察页面一致）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 左侧时间周期调节
                            Flexible(
                              child: _buildPeriodSelector(c, navButtonBg, primaryColor, periodLabel),
                            ),
                            const SizedBox(width: 8.0),
                            // 右侧时间/金额排序双胶囊按钮
                            _buildSortSelector(c, navButtonBg, primaryColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: c.loading
                    ? const Center(child: CircularProgressIndicator())
                    : c.error != null
                        ? Center(
                            child: BeeStatus(
                              label: l.commonError,
                              tone: BeeTone.error,
                              action: BeeButton(
                                label: l.v4RecordingRetry,
                                onPressed: () => setState(() {
                                  c.dispose();
                                  _data = null;
                                }),
                              ),
                            ),
                          )
                        : c.category == null
                            ? Center(
                                child: BeeEmptyState(
                                  title: l.v4DetailMissingCategory,
                                ),
                              )
                            : _CustomCategoryDetailBody(
                                data: c,
                                allLedgers: widget.allLedgers,
                                periodLabel: widget.periodLabel,
                                showAll: _showAll,
                                showTrend: showTrend,
                                onShowAll: () =>
                                    setState(() => _showAll = !_showAll),
                                onChild: _child,
                                onRecord: _record,
                                onSort: (value) {
                                  ref
                                      .read(
                                        categoryDetailSortProvider(
                                          widget.categoryId,
                                        ).notifier,
                                      )
                                      .state = value;
                                  c.chooseSort(value);
                                },
                                onDelete: _delete,
                              ),
              ),
            ],
          ),
          // 底部常驻符合 OriginUI 规范的胶囊大按钮（“记一笔”）
          bottomNavigationBar: (category == null || category.id < 0)
              ? null
              : SafeArea(
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
                            borderRadius: BorderRadius.circular(
                              OriginTokens.buttonRadius,
                            ),
                          ),
                        ),
                        onPressed: _record,
                        child: Text(
                          l.widgetQuickAddLabel,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  /// 第一行 Tab 切换栏（与洞察报表页风格一致）
  Widget _buildTopTabBar(CategoryDetailController c, Color primaryColor) {
    final tabs = [
      (CategoryDetailPeriod.month, '本月'),
      (CategoryDetailPeriod.year, '本年'),
      (CategoryDetailPeriod.all, '全部'),
      (CategoryDetailPeriod.custom, '指定周期'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 44.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) {
          final isSelected = c.period == tab.$1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              if (tab.$1 == CategoryDetailPeriod.custom) {
                _openCustomRangeSheet(primaryColor);
              } else {
                setState(() => _showAll = false);
                c.choosePeriod(tab.$1);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tab.$2,
                  style: TextStyle(
                    fontSize: isSelected ? 17.0 : 15.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? OriginTokens.textPrimary(context)
                        : OriginTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 4.0),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 26.0 : 0.0,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 顶部第二行左侧时间调节器（与洞察报表页风格一致）
  Widget _buildPeriodSelector(
    CategoryDetailController c,
    Color navButtonBg,
    Color primaryColor,
    String periodLabel,
  ) {
    if (c.period == CategoryDetailPeriod.all) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Text(
          periodLabel,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: OriginTokens.textPrimary(context),
          ),
        ),
      );
    }

    if (c.period == CategoryDetailPeriod.custom) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => _openCustomRangeSheet(primaryColor),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    periodLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 2.0),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18.0,
                  color: OriginTokens.textSecondary(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // month or year
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNavButton(
          icon: Icons.chevron_left_rounded,
          bgColor: navButtonBg,
          onTap: () => _movePeriod(-1),
        ),
        const SizedBox(width: 2.0),
        Flexible(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(8.0),
              onTap: () {
                if (c.period == CategoryDetailPeriod.month) {
                  _openMonthSheet(primaryColor);
                } else if (c.period == CategoryDetailPeriod.year) {
                  _openYearSheet(primaryColor);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                child: Text(
                  periodLabel,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 2.0),
        _buildNavButton(
          icon: Icons.chevron_right_rounded,
          bgColor: navButtonBg,
          onTap: () => _movePeriod(1),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 26.0,
          height: 26.0,
          child: Icon(
            icon,
            size: 16.0,
            color: OriginTokens.textPrimary(context),
          ),
        ),
      ),
    );
  }

  /// 顶部第二行右侧独立胶囊排序开关 (时间排序 / 金额排序)
  Widget _buildSortSelector(
    CategoryDetailController c,
    Color unselectedBg,
    Color primaryColor,
  ) {
    final isTimeActive =
        c.sort == CategoryDetailSort.timeDesc || c.sort == CategoryDetailSort.timeAsc;
    final isTimeDesc = c.sort == CategoryDetailSort.timeDesc;

    final isAmountActive =
        c.sort == CategoryDetailSort.amountDesc || c.sort == CategoryDetailSort.amountAsc;
    final isAmountDesc = c.sort == CategoryDetailSort.amountDesc;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时间排序独立胶囊
        _buildSortChip(
          label: '时间',
          isActive: isTimeActive,
          isDesc: isTimeDesc,
          primaryColor: primaryColor,
          unselectedBg: unselectedBg,
          onTap: () => _toggleTimeSort(c),
        ),
        const SizedBox(width: 5.0),
        // 金额排序独立胶囊
        _buildSortChip(
          label: '金额',
          isActive: isAmountActive,
          isDesc: isAmountDesc,
          primaryColor: primaryColor,
          unselectedBg: unselectedBg,
          onTap: () => _toggleAmountSort(c),
        ),
      ],
    );
  }

  Widget _buildSortChip({
    required String label,
    required bool isActive,
    required bool isDesc,
    required Color primaryColor,
    required Color unselectedBg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 28.0,
          padding: const EdgeInsets.symmetric(horizontal: 8.5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? primaryColor.withValues(alpha: 0.12) : unselectedBg,
            borderRadius: BorderRadius.circular(14.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? primaryColor
                      : OriginTokens.textPrimary(context).withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 2.0),
              Icon(
                isActive
                    ? (isDesc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded)
                    : Icons.swap_vert_rounded,
                size: 13.0,
                color: isActive
                    ? primaryColor
                    : OriginTokens.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部紧凑导航栏：左侧返回箭头紧随分类名称，右侧操作菜单
class _CustomCategoryTopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;

  const _CustomCategoryTopAppBar({
    required this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(OriginTokens.smallTitleHeight);

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bg = backgroundColor ?? OriginTokens.pageBackground(context);

    return Container(
      color: bg,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: SizedBox(
        height: OriginTokens.smallTitleHeight,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 8.0,
            right: OriginTokens.cardMargin,
          ),
          child: Row(
            children: [
              if (leading != null) leading!,
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

/// 分类详情列表主体（精准响应 showTrend 控制累计金额趋势的显隐）
class _CustomCategoryDetailBody extends ConsumerWidget {
  const _CustomCategoryDetailBody({
    required this.data,
    required this.allLedgers,
    required this.showAll,
    required this.showTrend,
    required this.onShowAll,
    required this.onChild,
    required this.onSort,
    required this.onRecord,
    required this.onDelete,
    this.periodLabel,
  });

  final CategoryDetailController data;
  final bool allLedgers, showAll, showTrend;
  final String? periodLabel;
  final VoidCallback onShowAll, onRecord;
  final ValueChanged<Category> onChild;
  final ValueChanged<CategoryDetailSort> onSort;
  final Future<void> Function(int transactionId, int ledgerId) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = data, l = AppLocalizations.of(context), category = c.category!;
    final current = ref.watch(currentLedgerProvider).valueOrNull;
    final hide = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final currency = c.summaryCurrency ?? current?.currency ?? '—';
    final isLocked = ref.watch(currencyLockedProvider);
    final symbol = isLocked ? '' : getDistinctCurrencySymbol(currency);
    final complete = c.summaryComplete;

    String number(double value) => hide
        ? '••••'
        : complete
            ? formatMoneyCompact(value, trimZeros: false)
            : '—';

    String money(double value) => hide
        ? '••••'
        : complete
            ? '$symbol${number(value)}'
            : '—';

    String name(Category cat) =>
        CategoryUtils.getDisplayName(cat.name, context, kind: cat.kind);

    final hasMultipleLedgers =
        (ref.watch(ledgersStreamProvider).valueOrNull?.length ?? 0) > 1;
    final scope = hasMultipleLedgers
        ? (allLedgers ? l.syncHealthGroupAll : current?.name)
        : null;
    final period = switch (c.period) {
      CategoryDetailPeriod.month => l.v4DetailMonth,
      CategoryDetailPeriod.year => l.v4DetailYear,
      CategoryDetailPeriod.all => l.v4DetailCumulative,
      CategoryDetailPeriod.custom => periodLabel ?? l.v4DetailCustom,
    };
    final titleParts = [
      name(category),
      if (scope != null && scope.trim().isNotEmpty) scope.trim(),
      period,
    ];

    final metricLabel = isLocked ? '' : currency;
    final rows = showAll ? c.rows : c.rows.take(4).toList();

    final days = <DateTime, ({double expense, double income})>{};
    for (final row in c.rows) {
      final date = DateUtils.dateOnly(row.t.happenedAt);
      final old = days[date] ?? (expense: 0.0, income: 0.0);
      final value = c.currencyProjection?.amounts[row.t.id] ?? 0;
      days[date] = (
        expense: old.expense + (row.t.type == 'expense' ? value : 0),
        income: old.income + (row.t.type == 'income' ? value : 0),
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 分类详情大看板卡片 (统一 OriginHeroCard，19.0dp 圆角，主题色沉浸感，无磨砂条)
        OriginHeroCard(
          margin: EdgeInsets.zero,
          title: titleParts.join(' · '),
          unit: hide || !complete ? '' : symbol,
          mainAmount: number(c.amount),
          hideAmounts: hide,
          action: c.parent != null
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChild(c.parent!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      '${l.v4ResourceParent}: ${name(c.parent!)}',
                      style: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
          metrics: [
            OriginHeroMetric(
              label: l.categoryDetailTotalCount,
              value: l.tagTransactionCount(c.count),
            ),
            OriginHeroMetric(
              label: l.categoryDetailAverageAmount,
              unit: hide || !complete ? '' : symbol,
              value: formatMoneyCompact(c.average, trimZeros: false),
            ),
            OriginHeroMetric(
              label: l.v4DetailShare,
              value: hide
                  ? '••••'
                  : c.shareComplete
                      ? '${(c.share * 100).toStringAsFixed(1)}%'
                      : '—',
            ),
          ],
        ),
        if (!isLocked &&
            c.currencyProjection != null &&
            (allLedgers ||
                !complete ||
                c.currencyProjection!.hasForeignSources)) ...[
          const SizedBox(height: 12),
          detailCurrencyNotice(context, c.currencyProjection!),
        ],
        const SizedBox(height: 12),
        if (c.children.isNotEmpty) ...[
          BeeSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.categorySubCategoryTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                BeeResourceBreakdown(
                  items: c.children.map((child) {
                    final value = c.childAmounts[child.id] ?? 0;
                    final count = c.rows
                        .where((row) => row.category?.id == child.id)
                        .length;
                    final fraction = hide || !complete || c.amount == 0
                        ? 0.0
                        : value / c.amount;
                    return BeeResourceBreakdownItem(
                      id: '${child.id}',
                      label: name(child),
                      amount: money(value),
                      detail:
                          '${l.tagTransactionCount(count)} · ${hide ? '••••' : complete ? '${(fraction * 100).toStringAsFixed(1)}%' : '—'}',
                      fraction: fraction,
                      icon: RecordingCategoryIcon(category: child, size: 18),
                    );
                  }).toList(),
                  onSelected: (id) => onChild(
                    c.children.singleWhere((child) => '${child.id}' == id),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 核心改造点：根据 showTrend 开关状态决定是否展示“累计金额趋势”
        if (showTrend) ...[
          BeeSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.v4DetailTrend,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      metricLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BeeResourceTrend(
                  values: hide || !complete ? const [] : c.trend,
                  label: l.v4DetailTrend,
                  axisLabels: hide || !complete || c.trendDates.isEmpty
                      ? const []
                      : [
                          c.trendDates.first,
                          c.trendDates[c.trendDates.length ~/ 2],
                          c.trendDates.last,
                        ]
                          .map((d) => c.period == CategoryDetailPeriod.month
                              ? '${d.month}.${d.day.toString().padLeft(2, "0")}'
                              : '${d.year}.${d.month.toString().padLeft(2, "0")}')
                          .toList(),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],


        BeeTransactionStreamHeader(
          title: l.v4DetailRecent,
          count: l.tagTransactionCount(c.count),
          actions: const [],
        ),
        if (rows.isEmpty)
          BeeEmptyState(
            title: l.categoryDetailNoTransactions,
            message: l.categoryDetailNoTransactionsSubtext,
          ),
      ],
    );

    final hasExpandButton = c.rows.length > 4;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(17, 4, 17, 16),
      itemCount: rows.length + 1 + (hasExpandButton ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) return header;
        if (hasExpandButton && index == rows.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Center(
              child: TextButton(
                onPressed: onShowAll,
                child: Text(
                  showAll
                      ? l.v4DetailCollapse
                      : l.v4DetailAllTransactions(c.rows.length),
                ),
              ),
            ),
          );
        }
        final i = index - 1;
        final row = rows[i];
        final date = DateUtils.dateOnly(rows[index - 1].t.happenedAt);
        final first =
            i == 0 || DateUtils.dateOnly(rows[i - 1].t.happenedAt) != date;
        final totals = days[date]!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: BeeCardTheme.of(context).surface,
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(22) : Radius.zero,
              bottom: i == rows.length - 1 ? const Radius.circular(22) : Radius.zero,
            ),
          ),
          child: Column(
            children: [
              if (first)
                BeeTransactionDayHeader(
                  title:
                      MaterialLocalizations.of(context).formatMediumDate(date),
                  date: '',
                  totals: [
                    if (!complete || totals.expense != 0)
                      '${l.searchSummaryExpense} ${money(totals.expense)}',
                    if (!complete || totals.income != 0)
                      '${l.searchSummaryIncome} ${money(totals.income)}',
                  ],
                ),
              CustomTransactionTileBinding(
                key: ValueKey('category-transaction-${row.t.id}'),
                row: row,
                tags: c.tags[row.t.id] ?? const [],
                attachmentCount: c.attachments[row.t.id] ?? 0,
                accountsEnabled: accounts,
                allLedgers: allLedgers,
                allowCategoryNavigation: row.category?.id != c.categoryId,
                ledgerName: (allLedgers && hasMultipleLedgers)
                    ? c.ledgers[row.t.ledgerId]?.name
                    : null,
                baseCurrency: c.ledgers[row.t.ledgerId]?.currency,
                onDelete: () => onDelete(row.t.id, row.t.ledgerId),
                onReturned: () => unawaited(c.refreshResources()),
              ),
              if (i < rows.length - 1) const Divider(height: 1, indent: 46),
            ],
          ),
        );
      },
    );
  }
}
