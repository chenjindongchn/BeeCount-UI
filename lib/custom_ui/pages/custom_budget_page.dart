import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/budget_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_hero_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_switch.dart';
import '../widgets/origin_budget_dialog.dart';
import '../widgets/origin_empty_state.dart';
import '../providers/amount_format_provider.dart';

/// vivo OriginOS 风格预算管理页面 (CustomBudgetPage)
///
/// 遵循全局定制与 OriginOS 设计规范：
/// 1. 没有预算时，“添加总预算”按钮固定在屏幕最底部，视觉居中展示空状态；
/// 2. 拥有预算时，纯色 12dp 卡片呈现月度预算进度、分类预算与首页展示开关；
/// 3. 支持深色浅色模式完全自适应。
class CustomBudgetPage extends ConsumerWidget {
  const CustomBudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(thousandSeparatorProvider);
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final overviewAsync = ref.watch(budgetOverviewProvider);
    // 提前预热总预算与分类预算缓存，避免用户点击编辑按钮时因等待异步查询而产生卡顿感
    ref.watch(totalBudgetProvider);
    ref.watch(allBudgetsProvider);
    final ledger = ref.watch(currentLedgerProvider).asData?.value;
    final isLocked = ref.watch(currencyLockedProvider);
    final showCurrency = !isLocked && ref.watch(currencySymbolVisibleProvider);
    final actualSymbol = isLocked ? '' : getCurrencySymbol(ledger?.currency ?? 'CNY');
    final currencySymbol = showCurrency ? actualSymbol : '';
    final canEdit =
        ledger == null || !ledger.isShared || ledger.myRole == 'owner';
    final showOnHome = ref.watch(homeBudgetCardEnabledProvider);

    return overviewAsync.when(
      loading: () => OriginScaffold(
        appBar: OriginSmallTopAppBar(
          title: l10n.budgetTitle,
          leading: const BackButton(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => OriginScaffold(
        appBar: OriginSmallTopAppBar(
          title: l10n.budgetTitle,
          leading: const BackButton(),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: OriginTokens.expenseRed,
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.commonError}: $error',
                style: TextStyle(
                  color: OriginTokens.textSecondary(context),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(budgetOverviewProvider),
                child: Text(l10n.v4RecordingRetry),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final totalBudget = data?.totalBudget;
        final hasBudget = data != null && totalBudget != null;

        return OriginScaffold(
          appBar: OriginSmallTopAppBar(
            title: l10n.budgetTitle,
            leading: const BackButton(),
          ),
          body: !hasBudget
              // 1. 无预算状态：空状态图文居中展示
              ? OriginEmptyState(
                  iconData: Icons.account_balance_wallet_outlined,
                  title: l10n.budgetEmptyHint,
                  message: l10n.budgetManagementDesc,
                  bottomSpacing: 12.0,
                )
              // 2. 有预算状态：月度总预算、分类预算与首页设置卡片
              : ListView(
                  padding: const EdgeInsets.only(
                    top: 8.0,
                    bottom: 24.0,
                  ),
                  children: [
                    // A. 月度总预算大看板卡片 (统一 OriginHeroCard，19.0dp 圆角，主题色沉浸感，无磨砂条)
                    OriginHeroCard(
                      title: l10n.budgetMonthlyBudget,
                      unit: ledger?.currency == 'CNY' ? '元' : currencySymbol,
                      mainAmount: formatMoneyCompact(totalBudget.budget, trimZeros: false),
                      action: canEdit
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () async {
                                final total = ref
                                        .read(totalBudgetProvider)
                                        .valueOrNull ??
                                    await ref.read(totalBudgetProvider.future);
                                if (context.mounted && total != null) {
                                  showOriginTotalBudgetDialog(
                                    context: context,
                                    ref: ref,
                                    budget: total,
                                    currencySymbol: currencySymbol,
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10.0,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  l10n.commonEdit,
                                  style: const TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : null,
                      middleChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${l10n.budgetUsed} ${(totalBudget.rate * 100).clamp(0, 999).toStringAsFixed(0)}% · 剩余 ${data.daysRemaining} 天',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                              Text(
                                '日均可用 $currencySymbol${formatMoneyCompact(data.dailyAvailable, trimZeros: false)}',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7.0),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3.0),
                            child: SizedBox(
                              height: 6.0,
                              child: LinearProgressIndicator(
                                value: totalBudget.rate.clamp(0.0, 1.0),
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.25),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  totalBudget.rate >= 1.0
                                      ? const Color(0xFFFF5252)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      metrics: [
                        OriginHeroMetric(
                          label: l10n.budgetUsed,
                          unit: ledger?.currency == 'CNY' ? '元' : currencySymbol,
                          value: formatMoneyCompact(totalBudget.used, trimZeros: false),
                        ),
                        OriginHeroMetric(
                          label: l10n.budgetRemaining,
                          unit: ledger?.currency == 'CNY' ? '元' : currencySymbol,
                          value: formatMoneyCompact(totalBudget.remaining, trimZeros: false),
                          valueColor: totalBudget.remaining < 0
                              ? const Color(0xFFFF5252)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    // B. 分类预算分组卡片（单卡片聚合，避免多入口冲突）
                    OriginCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.budgetCategoryBudgets,
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w600,
                                  color: OriginTokens.textPrimary(context),
                                ),
                              ),
                              if (canEdit)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    showOriginAddCategoryBudgetDialog(
                                      context: context,
                                      ref: ref,
                                      currencySymbol: actualSymbol,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2.0,
                                      horizontal: 4.0,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          size: 16.0,
                                          color: primaryColor,
                                        ),
                                        const SizedBox(width: 2.0),
                                        Text(
                                          l10n.commonAdd,
                                          style: TextStyle(
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w500,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10.0),
                          if (data.categoryBudgets.isNotEmpty) ...[
                            for (int i = 0;
                                i < data.categoryBudgets.length;
                                i++) ...[
                              if (i > 0) ...[
                                const SizedBox(height: 8.0),
                                const OriginDivider(startIndent: 0),
                                const SizedBox(height: 8.0),
                              ],
                              _CategoryBudgetTile(
                                item: data.categoryBudgets[i],
                                symbol: currencySymbol,
                                primaryColor: primaryColor,
                                canEdit: canEdit,
                              ),
                            ],
                          ] else ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: canEdit
                                  ? () {
                                      showOriginAddCategoryBudgetDialog(
                                        context: context,
                                        ref: ref,
                                        currencySymbol: actualSymbol,
                                      );
                                    }
                                  : null,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14.0,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  canEdit
                                      ? '点击右上角「+ 添加」，按分类精细化管理开支'
                                      : '暂未设置分类预算',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: OriginTokens.textTertiary(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // C. 设置卡片：在首页显示预算
                    OriginCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.budgetShowOnHome,
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                              color: OriginTokens.textPrimary(context),
                            ),
                          ),
                          OriginSwitch(
                            value: showOnHome,
                            activeColor: primaryColor,
                            onChanged: (val) {
                              ref
                                  .read(homeBudgetCardEnabledProvider.notifier)
                                  .toggle(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),
                  ],
                ),
          // 3. 严格遵循用户规范 2-a：没有预算时添加预算的按钮要在页面的最底下
          bottomNavigationBar: (!hasBudget && canEdit)
              ? SafeArea(
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
                        onPressed: () {
                          showOriginTotalBudgetDialog(
                            context: context,
                            ref: ref,
                            budget: null,
                            currencySymbol: actualSymbol,
                          );
                        },
                        child: Text(
                          l10n.budgetAddTotal,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _CategoryBudgetTile extends ConsumerWidget {
  final CategoryBudgetUsage item;
  final String symbol;
  final Color primaryColor;
  final bool canEdit;

  const _CategoryBudgetTile({
    required this.item,
    required this.symbol,
    required this.primaryColor,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final usage = item.usage;
    final categoryName = item.category != null
        ? CategoryUtils.getDisplayName(item.category!.name, context)
        : item.categoryName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canEdit
          ? () async {
              final budgets = ref.read(allBudgetsProvider).valueOrNull ??
                  await ref.read(allBudgetsProvider.future);
              final budget =
                  budgets?.where((b) => b.id == item.budgetId).firstOrNull;
              if (context.mounted && budget != null) {
                showOriginCategoryBudgetEditDialog(
                  context: context,
                  ref: ref,
                  budget: budget,
                  categoryName: categoryName,
                  category: item.category,
                  currencySymbol: symbol,
                );
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          children: [
            Row(
              children: [
                if (item.category != null)
                  RecordingCategoryIcon(category: item.category!, size: 24)
                else
                  const Icon(Icons.category_outlined, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    categoryName,
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                ),
                Text(
                  '${l10n.budgetRemaining} $symbol${formatMoneyCompact(usage.remaining, trimZeros: false)}',
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: usage.remaining < 0
                        ? OriginTokens.expenseRed
                        : OriginTokens.textSecondary(context),
                  ),
                ),
                if (canEdit)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: OriginTokens.textTertiary(context),
                  ),
              ],
            ),
            const SizedBox(height: 6.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.0),
              child: LinearProgressIndicator(
                value: usage.rate.clamp(0.0, 1.0),
                minHeight: 5.0,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  usage.rate >= 1.0
                      ? OriginTokens.expenseRed
                      : (usage.rate >= 0.8 ? Colors.orange : primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
