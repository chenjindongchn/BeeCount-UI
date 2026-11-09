import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart' as db;
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/currencies.dart';
import '../../../utils/format_money.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../../pages/shared/resources/widgets/detail_period_controls.dart'
    show detailRangeLabel;
import '../../../pages/tag/detail/bindings/tag_detail.dart';
import '../../../pages/shared/currency/bindings/detail_currency_notice.dart';
import '../providers/amount_format_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_hero_card.dart';
import 'custom_transaction_tile.dart';

/// vivo OriginOS 风格标签详情子组件 (CustomTagDetailSections)
///
/// 遵循全局统一设计规范：
/// 1. 顶部使用高质感 OriginHeroCard（带标签专属色彩底、主金额、隐藏金额开关与收入/笔数/分类核心指标）；
/// 2. 分类分布使用标准 OriginCard 大圆角卡片；
/// 3. 交易记录按天分组渲染，使用 CustomTransactionTileBinding，无缝联动记账抽屉；
/// 4. 移除原先混在滚动列表内部的“记一笔”按钮，统一由外层置底显示。
class CustomTagDetailSections extends ConsumerWidget {
  const CustomTagDetailSections({
    super.key,
    required this.tag,
    required this.stats,
    required this.data,
    required this.allLedgers,
    required this.period,
    required this.anchor,
    required this.onCategory,
    required this.onDelete,
    required this.onReturned,
    required this.onRetry,
  });

  final db.Tag tag;
  final AsyncValue<TagDetailStats> stats;
  final AsyncValue<TagDetailRows> data;
  final bool allLedgers;
  final TagDetailPeriod period;
  final DateTime anchor;
  final ValueChanged<db.Category> onCategory;
  final VoidCallback onReturned, onRetry;
  final Future<void> Function(int id, int ledgerId) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context),
        book = ref.watch(currentLedgerProvider).valueOrNull;
    final hide = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
    final resource = data.valueOrNull, rows = resource?.rows ?? [];
    final totals = stats.valueOrNull;
    final color =
        tagDetailColor(tag.color, Theme.of(context).colorScheme.primary);
    final projection = resource?.currency;
    final complete =
        projection?.complete == true && !data.isLoading && !stats.isLoading;
    final isLocked = ref.watch(currencyLockedProvider);
    final symbol = isLocked
        ? ''
        : getDistinctCurrencySymbol(
            projection?.targetCurrency ?? book?.currency ?? '—');
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
    final categories = {
      for (final row in rows)
        if (row.category != null) row.category!.id: row.category!
    };
    final breakdown = <int, ({double amount, int count})>{};
    for (final row in rows) {
      if (row.category == null ||
          row.t.type != 'expense' ||
          row.t.excludeFromStats) {
        continue;
      }
      final id = row.category!.id, old = breakdown[row.category!.id];
      breakdown[id] = (
        amount: (old?.amount ?? 0) + (projection?.amounts[row.t.id] ?? 0),
        count: (old?.count ?? 0) + 1
      );
    }
    final sorted = breakdown.keys.toList()
      ..sort((a, b) => breakdown[b]!.amount.compareTo(breakdown[a]!.amount));
    final expense =
        breakdown.values.fold(0.0, (sum, part) => sum + part.amount);
    final days = <DateTime, ({double expense, double income})>{};
    for (final row in rows) {
      final day = DateUtils.dateOnly(row.t.happenedAt.toLocal()),
          old = days[DateUtils.dateOnly(row.t.happenedAt.toLocal())] ??
              (expense: 0.0, income: 0.0);
      final amount = projection?.amounts[row.t.id] ?? 0;
      days[day] = (
        expense: old.expense + (row.t.type == 'expense' ? amount : 0),
        income: old.income + (row.t.type == 'income' ? amount : 0)
      );
    }

    final hasMultipleLedgers =
        (ref.watch(ledgersStreamProvider).valueOrNull?.length ?? 0) > 1;
    final scope = hasMultipleLedgers
        ? (allLedgers ? l.syncHealthGroupAll : book?.name)
        : null;
    final periodText = switch (period) {
      TagDetailPeriod.month => detailRangeLabel(context, 'month', anchor),
      TagDetailPeriod.year => detailRangeLabel(context, 'year', anchor),
      TagDetailPeriod.all => l.v4DetailCumulative,
    };
    final titleParts = [
      tag.name,
      if (scope != null && scope.trim().isNotEmpty) scope.trim(),
      periodText,
    ];

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部高质感色彩底卡片 (OriginHeroCard)
        OriginHeroCard(
          margin: EdgeInsets.zero,
          title: titleParts.join(' · '),
          unit: hide || !complete ? '' : symbol,
          mainAmount: totals == null ? '—' : number(totals.expense),
          hideAmounts: hide,
          onToggleHideAmounts: () {
            ref.read(hideAmountsProvider.notifier).state = !hide;
          },
          color: color,
          metrics: [
            OriginHeroMetric(
              label: l.tagDetailTotalIncome,
              unit: hide || !complete ? '' : symbol,
              value: totals == null ? '—' : number(totals.income),
            ),
            OriginHeroMetric(
              label: l.tagDetailTotalCount,
              value: totals == null ? '—' : l.tagTransactionCount(totals.count),
            ),
            OriginHeroMetric(
              label: l.v4TagCategories,
              value: resource == null ? '—' : '${categories.length}',
            ),
          ],
        ),
        if (!isLocked &&
            projection != null &&
            (allLedgers || !complete || projection.hasForeignSources))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: detailCurrencyNotice(context, projection),
          ),
        if (stats.hasError || data.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action: BeeButton(label: l.v4RecordingRetry, onPressed: onRetry),
            ),
          ),
        if (sorted.isNotEmpty) ...[
          OriginCard(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.v4TagDistribution,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                BeeResourceBreakdown(
                  items: [
                    for (final id in sorted)
                      BeeResourceBreakdownItem(
                        id: '$id',
                        label: CategoryUtils.getDisplayName(
                          categories[id]!.name,
                          context,
                          kind: categories[id]!.kind,
                        ),
                        amount: money(breakdown[id]!.amount),
                        detail: l.tagTransactionCount(breakdown[id]!.count),
                        fraction: hide || !complete || expense == 0
                            ? 0
                            : breakdown[id]!.amount / expense,
                        icon: RecordingCategoryIcon(
                          category: categories[id]!,
                          size: 18,
                        ),
                      ),
                  ],
                  onSelected: (id) => onCategory(categories[int.parse(id)]!),
                ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4, right: 4),
          child: Row(
            children: [
              Text(
                l.tagDetailTransactionList,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OriginTokens.textPrimary(context),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                totals == null ? '—' : l.tagTransactionCount(totals.count),
                style: TextStyle(
                  fontSize: 12,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        if (data.isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!data.isLoading && !data.hasError && rows.isEmpty)
          BeeEmptyState(
            title: l.tagDetailNoTransactions,
            message: l.tagDetailNoTransactionsHint,
          ),
      ],
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        OriginTokens.cardMargin,
        4,
        OriginTokens.cardMargin,
        16,
      ),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        final i = index - 1,
            row = rows[i],
            date = DateUtils.dateOnly(row.t.happenedAt.toLocal());
        final first = i == 0 ||
            DateUtils.dateOnly(rows[i - 1].t.happenedAt.toLocal()) != date;
        final total = days[date]!;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: OriginTokens.cardBackground(context),
            borderRadius: BorderRadius.vertical(
              top: i == 0 ? const Radius.circular(20) : Radius.zero,
              bottom:
                  i == rows.length - 1 ? const Radius.circular(20) : Radius.zero,
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
                    if (!complete || total.expense != 0)
                      '${l.searchSummaryExpense} ${money(total.expense)}',
                    if (!complete || total.income != 0)
                      '${l.searchSummaryIncome} ${money(total.income)}'
                  ],
                ),
              CustomTransactionTileBinding(
                key: ValueKey('tag-transaction-${row.t.id}'),
                row: row,
                tags: resource!.tags[row.t.id] ?? const [],
                attachmentCount: resource.attachments[row.t.id] ?? 0,
                accountsEnabled: accounts,
                allLedgers: allLedgers,
                allowCategoryNavigation: true,
                ledgerName: (allLedgers && hasMultipleLedgers)
                    ? resource.ledgers[row.t.ledgerId]?.name
                    : null,
                baseCurrency: resource.ledgers[row.t.ledgerId]?.currency,
                onDelete: () => onDelete(row.t.id, row.t.ledgerId),
                onReturned: onReturned,
              ),
              if (i < rows.length - 1) const Divider(height: 1, indent: 46),
            ],
          ),
        );
      },
    );
  }
}
