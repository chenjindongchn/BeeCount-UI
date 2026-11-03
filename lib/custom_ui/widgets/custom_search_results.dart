import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';
import '../../../providers.dart';
import '../../../utils/currencies.dart';
import '../../../utils/format_money.dart';
import '../providers/amount_format_provider.dart';
import '../styles/origin_tokens.dart';
import 'custom_transaction_tile.dart';
import 'origin_card.dart';
import 'origin_divider.dart';
import 'origin_search_bar.dart';

/// vivo OriginOS 风格搜索结果组件 (CustomSearchResults)
///
/// 遵循蓝河工具箱与 vivo 视觉规范：
/// 1. 结果按自然日使用 OriginCard（12dp 圆角、20dp 外侧边距）分组沉浸式包裹；
/// 2. 分组内条目之间使用 0.5dp 发丝分割线（OriginDivider）精确对齐文字首部；
/// 3. 搜索结果摘要卡片：对比醒目的支出赤红（#FF4D4F）与收入翡翠绿（#00B060），附带批量操作胶囊；
/// 4. 历史记录与批量选择条：全部适配 OriginFilterChip 胶囊交互；
/// 5. 保持与业务 Controller 完全解耦复用，下钻与长按操作均走 CustomTransactionTileBinding。
class CustomSearchResults extends ConsumerWidget {
  const CustomSearchResults({
    super.key,
    required this.data,
    required this.writing,
    required this.onScope,
    required this.onQuery,
    required this.onRetry,
  });

  final TransactionSearchController data;
  final bool writing;
  final VoidCallback onScope, onRetry;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context), c = data;
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final hidden = ref.watch(hideAmountsProvider);
    final accounts =
        ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;

    final isLocked = ref.watch(currencyLockedProvider);
    final symbol = isLocked ? '' : getDistinctCurrencySymbol(ledger?.currency ?? 'CNY');
    String money(double value) => hidden
        ? '••••'
        : '$symbol${formatMoneyCompact(value, trimZeros: false)}';

    if (c.loading) {
      return Center(
        child: SizedBox(
          width: 24.0,
          height: 24.0,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              OriginTokens.primary(context),
            ),
          ),
        ),
      );
    }

    if (c.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40.0,
                color: OriginTokens.expenseRed,
              ),
              const SizedBox(height: 12.0),
              Text(
                l.commonError,
                style: TextStyle(
                  fontSize: 14.0,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 16.0),
              FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(120.0, 36.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                ),
                child: Text(l.v4RecordingRetry),
              ),
            ],
          ),
        ),
      );
    }

    // 将结果按自然日分组
    final groupedResults = <DateTime, List<SearchTransaction>>{};
    for (final item in c.results) {
      final day = DateUtils.dateOnly(item.t.happenedAt);
      groupedResults.putIfAbsent(day, () => []).add(item);
    }
    final days = groupedResults.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        0,
        4.0,
        0,
        c.batch ? 84.0 : 24.0,
      ),
      itemCount: (days.isEmpty ? 1 : days.length) + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context, ref, l, c, ledger?.name, money);
        }

        if (days.isEmpty) {
          return const SizedBox.shrink();
        }

        final day = days[index - 1];
        final list = groupedResults[day]!;

        // 计算当天收支小计
        double dayExpense = 0.0, dayIncome = 0.0;
        for (final item in list) {
          if (item.t.type == 'expense') {
            dayExpense += item.t.amount;
          } else if (item.t.type == 'income') {
            dayIncome += item.t.amount;
          }
        }

        final dateTitle =
            MaterialLocalizations.of(context).formatMediumDate(day);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: OriginCard(
            margin: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
            ),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 自然日小节标题
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateTitle,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: OriginTokens.textSecondary(context),
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (!c.batch && (dayExpense > 0 || dayIncome > 0))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (dayExpense > 0)
                              Text(
                                '支 ${money(dayExpense)}',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: OriginTokens.textTertiary(context),
                                ),
                              ),
                            if (dayExpense > 0 && dayIncome > 0)
                              const SizedBox(width: 8.0),
                            if (dayIncome > 0)
                              Text(
                                '收 ${money(dayIncome)}',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: OriginTokens.textTertiary(context),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const OriginDivider(startIndent: 0),
                // 交易项列表
                for (int i = 0; i < list.length; i++) ...[
                  CustomTransactionTileBinding(
                    fullDate: true,
                    row: list[i],
                    tags: c.tags[list[i].t.id] ?? const [],
                    attachmentCount: c.attachments[list[i].t.id] ?? 0,
                    batch: c.batch,
                    selected: c.selected.contains(list[i].t.id),
                    accountsEnabled: accounts,
                    onSelect: writing ? null : () => c.toggle(list[i].t.id),
                    onReturned: () => unawaited(c.refresh()),
                  ),
                  if (i < list.length - 1)
                    const OriginDivider(startIndent: 52.0),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
    TransactionSearchController c,
    String? ledgerName,
    String Function(double) money,
  ) {
    if (c.batch) {
      // 批量模式统计与操作栏
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          OriginTokens.cardMargin,
          0,
          OriginTokens.cardMargin,
          10.0,
        ),
        child: OriginCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ledgerName ?? ''} · ${l.searchResultsCount(c.results.length)}',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                  ),
                  Text(
                    '已选 ${c.selected.length} 笔 · ${money(c.selectedTotal)}',
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.primary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  OriginFilterChip(
                    label: c.selected.length == c.results.length &&
                            c.results.isNotEmpty
                        ? l.searchDeselectAll
                        : l.searchSelectAll,
                    selected: c.selected.length == c.results.length &&
                        c.results.isNotEmpty,
                    leading: Icon(
                      c.selected.length == c.results.length &&
                              c.results.isNotEmpty
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14.0,
                    ),
                    onTap: writing ? null : () => c.selectAll(),
                  ),
                  OriginFilterChip(
                    label: l.v4SearchInvert,
                    leading: const Icon(Icons.swap_horiz_rounded, size: 14.0),
                    onTap: writing ? null : () => c.invert(),
                  ),
                  OriginFilterChip(
                    label: l.v4SearchScope,
                    leading:
                        const Icon(Icons.filter_alt_outlined, size: 14.0),
                    onTap: writing ? null : onScope,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (c.hasQuery) {
      if (c.results.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 48.0,
                  color: OriginTokens.textTertiary(context),
                ),
                const SizedBox(height: 12.0),
                Text(
                  l.searchNoResults,
                  style: TextStyle(
                    fontSize: 14.0,
                    color: OriginTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 搜索结果金额统计卡片
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          OriginTokens.cardMargin,
          0,
          OriginTokens.cardMargin,
          10.0,
        ),
        child: OriginCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.searchResultsCount(c.results.length),
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.textTertiary(context),
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.searchSummaryExpense,
                              style: TextStyle(
                                fontSize: 11.0,
                                color: OriginTokens.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              money(c.expense),
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: OriginTokens.resolveExpenseColor(context, ref),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.searchSummaryIncome,
                              style: TextStyle(
                                fontSize: 11.0,
                                color: OriginTokens.textSecondary(context),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              money(c.income),
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                                color: OriginTokens.resolveIncomeColor(context, ref),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: c.results.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        FocusManager.instance.primaryFocus?.unfocus();
                        unawaited(c.remember());
                        c.toggleBatch();
                      },
                borderRadius: BorderRadius.circular(15.0),
                child: Ink(
                  height: 30.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: OriginTokens.chipBackground(context),
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 14.0,
                        color: OriginTokens.textPrimary(context),
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        l.searchBatchMode,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 无输入时的初始状态：仅在有历史搜索记录时展示历史卡片，不再显示“输入关键词开始搜索”及图标
    if (c.history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OriginTokens.cardMargin,
        0,
        OriginTokens.cardMargin,
        12.0,
      ),
      child: OriginCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.v4SearchRecent,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    c.clearHistory();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    l.v4SearchClearHistory,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: c.history
                  .map(
                    (q) => OriginFilterChip(
                      label: q,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onQuery(q);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
