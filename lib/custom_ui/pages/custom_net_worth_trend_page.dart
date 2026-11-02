import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/account/net_worth/bindings/net_worth_trend.dart';
import '../../providers.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../../utils/net_worth_trend_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_hero_card.dart';
import '../widgets/origin_report_period_sheets.dart';
import '../widgets/origin_scaffold.dart';
import '../providers/amount_format_provider.dart';

/// vivo OriginOS 风格净资产趋势页面 (CustomNetWorthTrendPage)
///
/// 严格还原洞察报表页面的设计语言与交互规范：
/// 1. 顶栏无小眼睛，清爽极简；
/// 2. 顶部第一行：3个月 / 6个月 / 12个月 / 自定义 切换 TabBar（带主题色下划线平滑圆角指示条）；
/// 3. 顶部第二行：
///    - 左侧：时间区间显示，支持点击呼出时间范围选择抽屉；
///    - 右侧：【净资产 / 总资产 / 总负债】独立药丸胶囊切换器（带轻量触感反馈）；
/// 4. 主体内容：
///    - 顶部沉浸式 OriginHeroCard 大看板卡片，高亮期末值，辅助展示期初、变动额、变动率；
///    - 下方嵌入 23dp 圆角卡片与 BeeLineChart 优雅曲线图；
/// 5. 完全复用原有数据层 (netWorthTrendSeriesProvider) 与实体逻辑，只聚焦 UI/UX 极致定制。
class CustomNetWorthTrendPage extends ConsumerStatefulWidget {
  const CustomNetWorthTrendPage({super.key});

  @override
  ConsumerState<CustomNetWorthTrendPage> createState() =>
      _CustomNetWorthTrendPageState();
}

class _CustomNetWorthTrendPageState
    extends ConsumerState<CustomNetWorthTrendPage> {
  // 当前指标视角：净资产、总资产、总负债
  NetWorthLine _line = NetWorthLine.net;

  // 当前周期维度：'m3', 'm6', 'm12', 'custom'
  String _rangeKey = 'm3';

  // 自定义时间范围
  late DateTime _customStart;
  late DateTime _customEnd;

  @override
  void initState() {
    super.initState();
    final now = trendTodayAnchor();
    // 默认自定义范围为近3个月
    _customStart = DateTime(now.year, now.month - 2, 1);
    _customEnd = now;
  }

  /// 获取当前生效的起止时间参数
  ({DateTime startDate, DateTime endDate}) _resolveDates(DateTime? earliest) {
    if (_rangeKey == 'custom') {
      return (
        startDate: DateTime(_customStart.year, _customStart.month, _customStart.day),
        endDate: DateTime(_customEnd.year, _customEnd.month, _customEnd.day),
      );
    }
    final range = switch (_rangeKey) {
      'm6' => NetWorthRange.m6,
      'm12' => NetWorthRange.m12,
      _ => NetWorthRange.m3,
    };
    return range.dates(earliest);
  }

  /// 获取当前周期的标题文本
  String _getRangeLabel(AppLocalizations l) {
    return switch (_rangeKey) {
      'm3' => l.netWorthTrend3M,
      'm6' => l.netWorthTrend6M,
      'm12' => l.netWorthTrend12M,
      'custom' => '自定义',
      _ => l.netWorthTrend3M,
    };
  }

  /// 唤起时间范围选择抽屉
  void _openCustomRangeSheet(Color primaryColor) {
    showOriginCustomRangeSheet(
      context,
      start: _customStart,
      end: _customEnd,
      primaryColor: primaryColor,
      onSelected: (start, end) {
        setState(() {
          _customStart = start;
          _customEnd = end;
          _rangeKey = 'custom';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = ref.watch(primaryColorProvider);
    final currency = ref.watch(baseCurrencyProvider).toUpperCase();
    final earliest = ref.watch(earliestTransactionDateProvider).valueOrNull;
    final isLocked = ref.watch(currencyLockedProvider);
    final multi = !isLocked && (ref.watch(usedCurrenciesProvider).valueOrNull?.length ?? 1) > 1;

    final dates = _resolveDates(earliest);
    final seriesAsync = ref.watch(netWorthTrendSeriesProvider(dates));

    final headerBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final navButtonBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    final periodLabel =
        '${dates.startDate.year}/${dates.startDate.month.toString().padLeft(2, '0')}/${dates.startDate.day.toString().padLeft(2, '0')} - '
        '${dates.endDate.year}/${dates.endDate.month.toString().padLeft(2, '0')}/${dates.endDate.day.toString().padLeft(2, '0')}';

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l.netWorthTrendTitle,
        backgroundColor: headerBg,
        leading: const BackButton(),
        // 彻底删除右侧小眼睛，保持顶栏清爽极简
        actions: const [],
      ),
      body: Column(
        children: [
          // 顶部筛选控制面板（纯白/夜间深色，带发丝线底边，与洞察页面规范保持一致）
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
                // 第一行：3个月 / 6个月 / 12个月 / 自定义 Tab 切换
                _buildTopTabBar(primaryColor),

                // 第二行：左侧时间区间显示 + 右侧【净资产 / 总资产 / 总负债】胶囊切换
                Padding(
                  padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 左侧时间范围选择器
                      Flexible(
                        child: _buildPeriodSelector(primaryColor, periodLabel),
                      ),
                      const SizedBox(width: 6.0),
                      // 右侧指标类型独立胶囊按钮 (净资产 / 总资产 / 总负债)
                      _buildLineSelector(navButtonBg, primaryColor),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 下方主体内容区
          Expanded(
            child: seriesAsync.when(
              data: (daily) => _buildContent(
                context,
                daily: daily,
                l: l,
                theme: theme,
                isDark: isDark,
                primaryColor: primaryColor,
                currency: currency,
                multiCurrency: multi,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: BeeEmptyState(
                  title: l.commonError,
                  message: '$err',
                  action: BeeButton(
                    label: l.v4RecordingRetry,
                    onPressed: () => ref.invalidate(netWorthTrendSeriesProvider(dates)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部第一行 Tab 切换
  Widget _buildTopTabBar(Color primaryColor) {
    const tabs = [
      ('m3', '3个月'),
      ('m6', '6个月'),
      ('m12', '12个月'),
      ('custom', '自定义'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      height: 44.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((tab) {
          final isSelected = _rangeKey == tab.$1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_rangeKey == tab.$1) return;
              setState(() => _rangeKey = tab.$1);
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

  /// 顶部第二行左侧时间选择器
  Widget _buildPeriodSelector(Color primaryColor, String periodLabel) {
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
                    fontSize: 12.5,
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

  /// 顶部第二行右侧独立胶囊按钮组 (净资产 / 总资产 / 总负债)
  Widget _buildLineSelector(Color unselectedBg, Color primaryColor) {
    final lines = [
      (NetWorthLine.net, '净资产'),
      (NetWorthLine.assets, '总资产'),
      (NetWorthLine.liabilities, '总负债'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: lines.map((item) {
        final isSelected = _line == item.$1;
        return Padding(
          padding: const EdgeInsets.only(left: 4.5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _line = item.$1);
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

  /// 页面主体内容：大看板卡片 + 趋势折线图
  Widget _buildContent(
    BuildContext context, {
    required List<({DateTime date, double assets, double liabilities, double net})> daily,
    required AppLocalizations l,
    required ThemeData theme,
    required bool isDark,
    required Color primaryColor,
    required String currency,
    required bool multiCurrency,
  }) {
    // 降采样逻辑：若天数较少（<=31天）直接使用每日序列，否则按月聚合成月末值
    final List<({DateTime date, double assets, double liabilities, double net})> chartPoints =
        daily.length <= 31 ? daily : downsampleMonthly(daily);

    final values = chartPoints.map(_line.pick).toList();
    final first = values.isEmpty ? 0.0 : values.first;
    final last = values.isEmpty ? 0.0 : values.last;
    final delta = last - first;
    final deltaRate = first != 0.0 ? (delta / first.abs() * 100) : 0.0;

    final xLabels = [
      for (final e in chartPoints)
        daily.length <= 31
            ? '${e.date.month}.${e.date.day}'
            : '${e.date.year % 100}/${e.date.month}'
    ];

    final rangeText = _getRangeLabel(l);
    final lineText = _line.label(l);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
      children: [
        // 1. 洞察风格主题色顶级大看板卡片 (OriginHeroCard)
        OriginHeroCard(
          margin: EdgeInsets.zero,
          title: rangeText,
          unit: ref.watch(currencyLockedProvider)
              ? ''
              : (currency == 'CNY' ? '元' : getCurrencySymbol(currency)),
          mainAmount: formatDisplayAmount(
            last,
            currencyCode: currency,
            showCurrency: false,
          ),
          metrics: [
            OriginHeroMetric(
              label: l.v4TrendOpening,
              value: formatDisplayAmount(
                first,
                currencyCode: currency,
                showCurrency: true,
              ),
            ),
            OriginHeroMetric(
              label: l.v4TrendChange,
              value: formatDisplayAmount(
                delta,
                currencyCode: currency,
                showCurrency: true,
                signed: true,
              ),
            ),
            if (first != 0.0)
              OriginHeroMetric(
                label: l.v4TrendChangeRate,
                value: '${delta >= 0 ? '+' : ''}${deltaRate.toStringAsFixed(1)}%',
              ),
          ],
        ),

        const SizedBox(height: 16.0),

        // 2. 趋势折线图卡片
        BeeSurface(
          padding: const EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 16.0),
          borderRadius: BorderRadius.circular(23.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$lineText趋势',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    currency,
                    style: TextStyle(
                      fontSize: 11.0,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              if (daily.length < 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: BeeEmptyState(
                    title: l.commonEmpty,
                    icon: const BeeLineIcon('ChartNoAxesCombined'),
                  ),
                )
              else
                SizedBox(
                  height: 220.0,
                  child: BeeLineChart(
                    values: values,
                    xLabels: xLabels,
                    highlightIndex: values.length - 1,
                    onSwipeLeft: () {},
                    onSwipeRight: () {},
                    hideAmounts: false,
                    themeColor: primaryColor,
                    whiteBg: false,
                    minimal: true,
                    isDark: isDark,
                  ),
                ),
            ],
          ),
        ),

        // 3. 多币种折算注记
        if (multiCurrency)
          Padding(
            padding: const EdgeInsets.only(top: 14.0, left: 4.0, right: 4.0),
            child: Text(
              l.netWorthTrendMultiCurrencyNote,
              style: TextStyle(
                fontSize: 11.0,
                height: 1.5,
                color: theme.hintColor,
              ),
            ),
          ),
      ],
    );
  }
}
