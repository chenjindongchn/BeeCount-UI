import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/category/category_manage_page.dart';
import '../../providers.dart';
import '../../utils/format_money.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../../pages/main/analytics/widgets/analytics_ranking.dart';
import '../../pages/main/analytics/widgets/analytics_trend.dart';

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
    this.onPeriod,
    this.onPrevious,
    this.onNext,
  });

  final AnalyticsResult data;
  final String scope;
  final String type;
  final DateTime month;
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
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final unconverted =
        ref.watch(ledgerUnconvertedForeignTxCountProvider).valueOrNull ?? 0;
    final foreign = ref.watch(ledgerForeignTxCountProvider).valueOrNull ?? 0;

    final period = scope == 'all'
        ? l.analyticsAllYears
        : scope == 'year'
            ? l.homeYear(month.year)
            : DateFormat.yMMM(l.localeName).format(month);

    final label = type == 'expense'
        ? l.homeExpense
        : type == 'income'
            ? l.homeIncome
            : l.homeBalance;

    String money(double v) => hide
        ? '****'
        : formatDisplayAmount(
            v,
            signed: false,
            showCurrency: true,
            currencyCode: base,
          );

    final averageLabel = scope == 'year'
        ? l.analyticsMonthlyAvg
        : scope == 'all'
            ? l.analyticsOverallAvg
            : l.analyticsDailyAvg;

    void average() => showDialog<void>(
          context: context,
          builder: (ctx) => BeeDialog(
            title: Text(l.v4InsightsAverageTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BeeSurface(
                  child: Text(
                    '${money(data.values.fold<double>(0, (sum, value) => sum + value))} ÷ ${data.values.length} '
                    '${scope == 'month' ? l.v4InsightsDaysUnit : scope == 'year' ? l.v4InsightsMonthsUnit : l.v4InsightsYearsUnit}'
                    ' = ${money(data.average)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  scope == 'month'
                      ? l.v4InsightsAverageDays
                      : scope == 'year'
                          ? l.v4InsightsAverageMonths
                          : l.v4InsightsAverageYears,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.commonKnow),
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
      BeeAnalyticsSummary(
        period: period,
        viewLabel: label,
        onPeriod: onPeriod,
        views: [
          BeeSegment('expense', l.homeExpense),
          BeeSegment('income', l.homeIncome),
          BeeSegment('balance', l.homeBalance),
        ],
        selectedView: type,
        onViewChanged: onTypeChanged,
        totalLabel: l
            .analyticsTotal(label)
            .trim()
            .replaceAll(RegExp(r'[:：]\s*$'), ''),
        ledgerLabel: ledger?.name,
        total: money(data.total),
        countLabel: l.sharePosterRecordCount,
        count: '${data.count}',
        averageLabel: '$averageLabel$label',
        average: money(data.average),
        onAverage: average,
      ),
      if (foreign > 0)
        Text(
          l.statsConvertedFootnote(base),
          style: TextStyle(fontSize: 10, color: theme.hintColor),
        ),
      if (data.empty)
        BeeSurface(
          child: BeeEmptyState(
            title: l.commonEmpty,
            message: l.v4InsightsNoData,
            action: BeeButton(
              label: l.analyticsSwitchTo(
                type == 'expense'
                    ? l.homeIncome
                    : type == 'income'
                        ? l.homeBalance
                        : l.homeExpense,
              ),
              onPressed: () => onTypeChanged(
                type == 'expense'
                    ? 'income'
                    : type == 'income'
                        ? 'balance'
                        : 'expense',
              ),
            ),
          ),
        )
      else ...[
        AnalyticsTrend(
          key: ValueKey((scope, month, type, data)),
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
                key: ValueKey((scope, month, type, data)),
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
                      builder: (_) => CategoryManagePage(
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
          card(
            l.analyticsCategoryRanking,
            AnalyticsRanking(
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
      ],
      // 注：此处根据定制需求已移除底部的“年度账单”和“生成分享海报”卡片
    ];

    return LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          bounds.maxWidth < 350 ? 12 : 16,
          1,
          bounds.maxWidth < 350 ? 12 : 16,
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
