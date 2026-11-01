import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../pages/custom_category_manage_page.dart';
import '../../providers.dart';
import '../../utils/format_money.dart';
import '../../utils/currencies.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../../pages/main/analytics/widgets/analytics_ranking.dart' show AnalyticsPie;
import '../../pages/main/analytics/widgets/analytics_trend.dart';
import '../styles/origin_tokens.dart';
import '../providers/amount_format_provider.dart';
import 'origin_analytics_ranking.dart';
import 'origin_dialog.dart';
import 'origin_hero_card.dart';

/// vivo OriginOS 风格数据洞察统计内容视图 (OriginAnalyticsContent)
///
/// 复用上游核心图表组件（趋势图、分类占比、收支排行榜等），
/// 定制移除底部的年度账单和分享海报模块。
class OriginAnalyticsContent extends ConsumerWidget {
  const OriginAnalyticsContent({
    super.key,
    required this.data,
    required this.scope,
    required this.type,
    required this.month,
    required this.onTypeChanged,
    required this.onRecalculate,
    this.periodLabel,
    this.onPeriod,
    this.onPrevious,
    this.onNext,
  });

  final AnalyticsResult data;
  final String scope;
  final String type;
  final DateTime month;
  final String? periodLabel;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<int> onRecalculate;
  final VoidCallback? onPeriod;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final base = ref.watch(currentLedgerCurrencyProvider);
    final unconverted =
        ref.watch(ledgerUnconvertedForeignTxCountProvider).valueOrNull ?? 0;
    final foreign = ref.watch(ledgerForeignTxCountProvider).valueOrNull ?? 0;

    final period = periodLabel ??
        (scope == 'all'
            ? l.analyticsAllYears
            : scope == 'year'
                ? l.homeYear(month.year)
                : DateFormat.yMMM(l.localeName).format(month));

    final label = type == 'expense'
        ? l.homeExpense
        : type == 'income'
            ? l.homeIncome
            : l.homeBalance;

    final showCurrency = ref.watch(currencySymbolVisibleProvider);
    String money(double v) => hide
        ? '****'
        : formatDisplayAmount(
            v,
            signed: false,
            showCurrency: showCurrency,
            currencyCode: base,
          );

    final averageLabel = scope == 'year'
        ? l.analyticsMonthlyAvg
        : scope == 'all'
            ? l.analyticsOverallAvg
            : l.analyticsDailyAvg;

    void average() => showOriginAlertDialog(
          context,
          title: l.v4InsightsAverageTitle,
          okText: l.commonKnow,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: OriginTokens.cardSecondary(context),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  '${money(data.values.fold<double>(0, (sum, value) => sum + value))} ÷ ${data.values.length} '
                  '${scope == 'month' ? l.v4InsightsDaysUnit : scope == 'year' ? l.v4InsightsMonthsUnit : l.v4InsightsYearsUnit}'
                  ' = ${money(data.average)}',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                scope == 'month'
                    ? l.v4InsightsAverageDays
                    : scope == 'year'
                        ? l.v4InsightsAverageMonths
                        : l.v4InsightsAverageYears,
                style: TextStyle(
                  fontSize: 13.0,
                  height: 1.5,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
            ],
          ),
        );

    Widget card(String title, Widget child, {Widget? action}) => BeeSurface(
          padding: const EdgeInsets.all(18),
          borderRadius: BorderRadius.circular(23),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (action != null)
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: action,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        );

    final children = <Widget>[
      if (unconverted > 0)
        BeeSurface(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const BeeLineIcon('ArrowLeftRight', size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.recalcForeignTxBanner,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () => onRecalculate(unconverted),
                child: Text(l.v4AnalyticsRecalculate),
              ),
            ],
          ),
        ),
      // 洞察数据总览大看板卡片 (统一 OriginHeroCard，19.0dp 圆角，主题色沉浸感，无磨砂条)
      OriginHeroCard(
        margin: EdgeInsets.zero,
        title: period,
        unit: base == 'CNY' ? '元' : getCurrencySymbol(base),
        mainAmount: formatMoneyCompact(data.total, trimZeros: false),
        hideAmounts: hide,
        onTap: onPeriod,
        action: null,
        metrics: [
          OriginHeroMetric(
            label: averageLabel,
            unit: base == 'CNY' ? '元' : getCurrencySymbol(base),
            value: formatMoneyCompact(data.average, trimZeros: false),
            onTap: average,
          ),
          OriginHeroMetric(
            label: l.sharePosterRecordCount,
            value: '${data.count} 笔',
          ),
        ],
      ),
      if (foreign > 0)
        Text(
          l.statsConvertedFootnote(base),
          style: TextStyle(fontSize: 10, color: theme.hintColor),
        ),
      AnalyticsTrend(
        key: ValueKey((scope, month, type, data.total, data.count)),
        data: data,
        scope: scope,
        title: l.v4InsightsTrendTitle(label),
        unit: l.v4InsightsAmountUnit(base),
        averageLabel: '$averageLabel ${money(data.average)}',
        formatValue: money,
        onAverage: average,
        onPrevious: onPrevious,
        onNext: onNext,
      ),
      if (type == 'balance')
        card(
          l.v4InsightsBalanceComposition,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeeAnalyticsComposition(
                incomeLabel: l.homeIncome,
                expenseLabel: l.homeExpense,
                income: money(data.incomeTotal),
                expense: money(data.expenseTotal),
                onIncome: () => onTypeChanged('income'),
                onExpense: () => onTypeChanged('expense'),
              ),
              const SizedBox(height: 11),
              Text(
                l.v4InsightsBalanceEquation,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: theme.hintColor),
              ),
            ],
          ),
        )
      else ...[
        if (data.total > 0)
          card(
            l.v4InsightsCategoryShare,
            AnalyticsPie(
              key: ValueKey((scope, month, type, data.total)),
              data: data,
            ),
            action: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: theme.hintColor,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CustomCategoryManagePage(
                      initialTabIndex: type == 'income' ? 1 : 0,
                    ),
                  ),
                );
                if (context.mounted) {
                  ref.read(statsRefreshProvider.notifier).state++;
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      l.categoryTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const BeeLineIcon('ChevronRight', size: 12),
                ],
              ),
            ),
          ),
        if (data.total > 0)
          card(
            l.analyticsCategoryRanking,
            OriginAnalyticsRanking(
              key: ValueKey((scope, month, type, data.total)),
              data: data,
              scope: scope,
              month: month,
            ),
            action: Text(
              l.v4InsightsSortedByAmount,
              style: TextStyle(fontSize: 10, color: theme.hintColor),
            ),
          ),
      ],
      // 注：此处根据定制需求已移除底部的“年度账单”和“生成分享海报”卡片
    ];

    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          OriginTokens.cardMargin,
          4.0,
          OriginTokens.cardMargin,
          84 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
