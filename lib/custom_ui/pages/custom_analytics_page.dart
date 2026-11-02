import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import 'custom_ai_chat_page.dart';
import 'custom_search_page.dart';
import '../../pages/calendar/calendar_page.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../data/custom_analytics_loader.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_analytics_content.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_report_period_sheets.dart';

/// vivo 钱包风格数据洞察与报表分析页面 (CustomAnalyticsPage)
///
/// 严格还原 vivo 钱包“收支报表”设计与交互逻辑：
/// 1. 顶部第一行：周报、月报、年报、自定义 四项 Tab 切换，支持主题色下划线指示条；
/// 2. 顶部第二行：
///    - 左侧：时间周期步进与切换（周、月、年带圆钮左右切换与点击弹窗，自定义带下拉三角展开时间抽屉）；
///    - 右侧：收支胶囊切换器（支出 / 收入 / 结余），选中态接入主题色；
/// 3. 四种周期专属抽屉：
///    - 【选择周】：按月翻页 + 该月包含的所有自然周网格（大字周序号/本周 + 小字起止日期）；
///    - 【选择月】：按年翻页 + 12个月网格（胶囊选中高亮）；
///    - 【选择年】：10年年代区间翻页 + 10个年份网格；
///    - 【自定义时间】：快捷选择（全部、近一年、近30天、近7天）+ 自定义起止时间选择框 + 确定按钮；
/// 4. 接入软件设置的主题色 (primaryColorProvider)；
/// 5. 纯 Riverpod 驱动，核心数据层零修改，100% 隔离不影响上游。
class CustomAnalyticsPage extends ConsumerStatefulWidget {
  final bool showBack;
  const CustomAnalyticsPage({super.key, this.showBack = false});

  @override
  ConsumerState<CustomAnalyticsPage> createState() => _CustomAnalyticsPageState();
}

class _CustomAnalyticsPageState extends ConsumerState<CustomAnalyticsPage> {
  // 当前周期维度：'week', 'month', 'year', 'custom'
  String _scope = 'month';

  // 当前收支视角：'expense', 'income', 'balance'
  String _type = 'expense';

  // 周期锚点状态
  late DateTime _selectedMonday;
  late DateTime _selectedMonth;
  late int _selectedYear;
  late DateTime _customStart;
  late DateTime _customEnd;

  Object? _queryKey;
  Future<Map<String, AnalyticsResult>>? _query;
  Map<String, AnalyticsResult>? _lastData;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _selectedMonday = getMondayOfWeek(today);
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedYear = now.year;
    _customStart = today.subtract(const Duration(days: 30));
    _customEnd = today;
  }

  void _selectType(String value) => setState(() => _type = value);

  void _selectScope(String scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
      _queryKey = null;
    });
  }

  // 周期左右步进
  void _movePeriod(int delta) {
    setState(() {
      if (_scope == 'week') {
        _selectedMonday = _selectedMonday.add(Duration(days: 7 * delta));
      } else if (_scope == 'month') {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      } else if (_scope == 'year') {
        _selectedYear += delta;
      }
      _queryKey = null;
    });
  }

  // 唤起对应弹窗
  void _openPeriodSheet(Color primaryColor) {
    if (_scope == 'week') {
      showOriginWeekPickerSheet(
        context,
        selectedMonday: _selectedMonday,
        primaryColor: primaryColor,
        onSelected: (monday) {
          setState(() {
            _selectedMonday = monday;
            _queryKey = null;
          });
        },
      );
    } else if (_scope == 'month') {
      showOriginMonthPickerSheet(
        context,
        selectedMonth: _selectedMonth,
        primaryColor: primaryColor,
        onSelected: (month) {
          setState(() {
            _selectedMonth = month;
            _queryKey = null;
          });
        },
      );
    } else if (_scope == 'year') {
      showOriginYearPickerSheet(
        context,
        selectedYear: _selectedYear,
        primaryColor: primaryColor,
        onSelected: (year) {
          setState(() {
            _selectedYear = year;
            _queryKey = null;
          });
        },
      );
    } else if (_scope == 'custom') {
      showOriginCustomRangeSheet(
        context,
        start: _customStart,
        end: _customEnd,
        primaryColor: primaryColor,
        onSelected: (start, end) {
          setState(() {
            _customStart = start;
            _customEnd = end;
            _queryKey = null;
          });
        },
      );
    }
  }

  // 计算第二行左侧时间文案
  String _getPeriodDisplayLabel() {
    if (_scope == 'week') {
      final sunday = _selectedMonday.add(const Duration(days: 6));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentMonday = getMondayOfWeek(today);
      final isCurrentWeek = _selectedMonday.year == currentMonday.year &&
          _selectedMonday.month == currentMonday.month &&
          _selectedMonday.day == currentMonday.day;

      final range = '${_selectedMonday.month}/${_selectedMonday.day}-${sunday.month}/${sunday.day}';
      return isCurrentWeek ? '$range(本周)' : range;
    } else if (_scope == 'month') {
      return '${_selectedMonth.year}年${_selectedMonth.month}月';
    } else if (_scope == 'year') {
      return '$_selectedYear年';
    } else {
      return '${_customStart.year}/${_customStart.month}/${_customStart.day}-${_customEnd.year}/${_customEnd.month}/${_customEnd.day}';
    }
  }

  void _openAI() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomAIChatPage()),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomSearchPage()),
    );
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarPage()),
    );
  }

  Future<void> _runRecalcForeignTx(int count) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l.recalcForeignTxAction,
      message: l.recalcSyncCountHint(count),
      confirmText: l.commonConfirm,
      cancelText: l.commonCancel,
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(repositoryProvider);
    final id = ref.read(currentLedgerIdProvider);
    final foreign = await repo.getLedgerForeignCurrencies(id);
    await refreshExchangeRatesFromUi(ref, force: true, extraQuotes: foreign);
    await repo.recomputeForeignTxForLedger(id);
    if (mounted) setState(() => _queryKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(repositoryProvider);
    final id = ref.watch(currentLedgerIdProvider);
    final sd = ref.watch(currentMonthStartDayProvider);
    final tick = ref.watch(statsRefreshProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    final key = (
      repo,
      id,
      _scope,
      _selectedMonday,
      _selectedMonth,
      _selectedYear,
      _customStart,
      _customEnd,
      sd,
      tick,
      DateUtils.dateOnly(DateTime.now()),
    );

    if (_queryKey != key) {
      _queryKey = key;
      _query = loadCustomAnalyticsViews(
        repo,
        ledgerId: id,
        scope: _scope,
        weekMonday: _selectedMonday,
        selMonth: _selectedMonth,
        selYear: _selectedYear,
        customStart: _customStart,
        customEnd: _customEnd,
        startDay: sd,
      );
    }

    final periodLabel = _getPeriodDisplayLabel();
    final headerBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l10n.tabInsights,
        backgroundColor: headerBg,
        leading: widget.showBack ? const BackButton() : null,
        actions: [
          OriginMoreButton(
            tooltip: '更多与设置',
            items: [
              OriginMenuItem(
                title: '日历看板',
                icon: const Icon(Icons.calendar_month_outlined),
                onTap: _openCalendar,
              ),
              OriginMenuItem(
                title: l10n.homeSearch,
                icon: const Icon(Icons.search_rounded),
                onTap: _openSearch,
              ),
              OriginMenuItem(
                title: l10n.aiChatTitle,
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  color: primaryColor,
                ),
                onTap: _openAI,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部筛选控制面板（纯白/夜间深色，带精致发丝线底边，与下方浅灰画布卡片区分，vivo 钱包规范）
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
                // 第一行：周报 / 月报 / 年报 / 自定义 Tab 切换
                _buildTopTabBar(primaryColor),

                // 第二行：时间切换（左） + 独立收支结余胶囊按钮（右，与 vivo 钱包一致）
                Padding(
                  padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 左侧时间周期切换
                      Flexible(
                        child: _buildPeriodSelector(navButtonBg, primaryColor, periodLabel),
                      ),
                      const SizedBox(width: 6.0),
                      // 右侧收支类型独立胶囊按钮 (支出 / 收入 / 结余)
                      _buildTypeSelector(navButtonBg, primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 下方主体统计图表与数据明细（平滑数据过渡，消除切屏白菊花闪烁）
          Expanded(
            child: FutureBuilder<Map<String, AnalyticsResult>>(
              future: _query,
              builder: (context, snapshot) {
                if (snapshot.hasError && _lastData == null) {
                  return BeeEmptyState(
                    title: l10n.commonError,
                    message: '${snapshot.error}',
                    action: BeeButton(
                      label: l10n.v4RecordingRetry,
                      onPressed: () => setState(() => _queryKey = null),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  _lastData = snapshot.data;
                }

                final displayData = snapshot.data ?? _lastData;

                if (displayData == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentResult = displayData[_type] ?? displayData.values.first;

                return OriginAnalyticsContent(
                  data: currentResult,
                  scope: _scope,
                  type: _type,
                  month: _selectedMonth,
                  periodLabel: periodLabel,
                  onTypeChanged: _selectType,
                  onPeriod: () => _openPeriodSheet(primaryColor),
                  onRecalculate: _runRecalcForeignTx,
                  onPrevious: _scope == 'custom' ? null : () => _movePeriod(-1),
                  onNext: _scope == 'custom' ? null : () => _movePeriod(1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部第一行 Tab 切换
  Widget _buildTopTabBar(Color primaryColor) {
    const tabs = [
      ('week', '周报'),
      ('month', '月报'),
      ('year', '年报'),
      ('custom', '自定义'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 44.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) {
          final isSelected = _scope == tab.$1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectScope(tab.$1),
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

  /// 顶部第二行左侧时间选择器
  Widget _buildPeriodSelector(Color navButtonBg, Color primaryColor, String periodLabel) {
    if (_scope == 'custom') {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: () => _openPeriodSheet(primaryColor),
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
              onTap: () => _openPeriodSheet(primaryColor),
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

  /// 顶部第二行右侧独立胶囊按钮组 (支出 / 收入 / 结余，对齐 vivo 钱包样式，独立按钮不合并)
  Widget _buildTypeSelector(Color unselectedBg, Color primaryColor) {
    const types = [
      ('expense', '支出'),
      ('income', '收入'),
      ('balance', '结余'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: types.map((item) {
        final isSelected = _type == item.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                _selectType(item.$1);
              },
              borderRadius: BorderRadius.circular(14.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 28.0,
                padding: const EdgeInsets.symmetric(horizontal: 8.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.12)
                      : unselectedBg,
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? primaryColor
                        : OriginTokens.textPrimary(context).withValues(alpha: 0.78),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

