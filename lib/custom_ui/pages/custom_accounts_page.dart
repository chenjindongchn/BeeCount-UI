import 'dart:async';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../data/db.dart' as db;
import '../../utils/format_money.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../pages/account/account_edit_page.dart';
import 'custom_account_detail_page.dart';
import 'custom_hidden_accounts_page.dart';
import '../../pages/account/net_worth_trend_page.dart';
import '../../services/billing/post_processor.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../widgets/origin_menu.dart';
import '../providers/amount_format_provider.dart';
import '../providers/account_display_preferences_provider.dart';

/// vivo OriginOS 风格资产总览与账户管理页面 (CustomAccountsPage)
///
/// 遵循 `OriginUI/docs/` 规范：
/// 1. 大标题栏（84dp / 22sp SemiBold）；
/// 2. 资产总览采用 12dp 纯色卡片，清晰呈现净资产、总资产、总负债；
/// 3. 分类账户列表使用 12dp 卡片 + 0.5dp 发丝分割线；
/// 4. 支持右上角切换是否按类别分组展示；
/// 5. 支持长按触发拖拽排序（分组内及平铺全量排序）；
/// 6. 纯 Riverpod 驱动，不修改业务表与数据库逻辑。
class CustomAccountsPage extends ConsumerStatefulWidget {
  final bool asTab;
  const CustomAccountsPage({super.key, this.asTab = true});

  @override
  ConsumerState<CustomAccountsPage> createState() => _CustomAccountsPageState();
}

class _CustomAccountsPageState extends ConsumerState<CustomAccountsPage> {
  final ScrollController _scrollController = ScrollController();

  /// 分组模式拖拽乐观更新本地锁，防止 stream 刷新导致瞬时闪烁
  Map<String, List<db.Account>>? _reorderingGroups;

  /// 平铺模式拖拽乐观更新本地锁
  List<db.Account>? _reorderingFlatAccounts;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openAddAccount(BuildContext context, int ledgerId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountEditPage(ledgerId: ledgerId),
      ),
    );
  }

  void _openNetWorthTrend(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NetWorthTrendPage(),
      ),
    );
  }

  void _openHiddenAccounts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CustomHiddenAccountsPage(),
      ),
    );
  }

  void _openAccountDetail(BuildContext context, db.Account account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) => CustomAccountDetailPage(account: account),
      ),
    );
  }

  /// 拖拽浮起装饰器（vivo OriginOS 悬浮卡片微阴影动效）
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = (lerpDouble(0, 6, animValue) ?? 0);
        return Material(
          elevation: elevation,
          color: OriginTokens.cardBackground(context),
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(OriginTokens.cardRadius),
          child: child,
        );
      },
      child: child,
    );
  }

  /// 分组模式下的组内拖拽重排序
  void _onReorderGroup(
    String type,
    List<db.Account> currentGroupAccounts,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _reorderingGroups ??= {};
      final list = List<db.Account>.from(
        _reorderingGroups![type] ?? currentGroupAccounts,
      );
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _reorderingGroups![type] = list;
    });

    final list = _reorderingGroups![type]!;
    final updates = <({int id, int sortOrder})>[];
    for (int i = 0; i < list.length; i++) {
      updates.add((id: list[i].id, sortOrder: i));
    }

    ref.read(repositoryProvider).updateAccountSortOrders(updates).then((_) {
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _reorderingGroups = null);
      });
    });
  }

  /// 平铺模式下的全量拖拽重排序
  void _onReorderFlat(
    List<db.Account> currentFlatAccounts,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    HapticFeedback.mediumImpact();

    final list = List<db.Account>.from(currentFlatAccounts);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    setState(() {
      _reorderingFlatAccounts = list;
    });

    // 保存全局顺序 ID 列表到本地持久化
    final newOrderIds = list.map((a) => a.id).toList();
    ref.read(customAccountOrderProvider.notifier).updateOrder(newOrderIds);

    // 将全局顺序映射为每个类型内部的相对 sortOrder 并更新数据库
    final typeCounter = <String, int>{};
    final updates = <({int id, int sortOrder})>[];
    for (final acc in list) {
      final currentIdx = typeCounter[acc.type] ?? 0;
      updates.add((id: acc.id, sortOrder: currentIdx));
      typeCounter[acc.type] = currentIdx + 1;
    }

    ref.read(repositoryProvider).updateAccountSortOrders(updates).then((_) {
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _reorderingFlatAccounts = null);
      });
    });
  }

  /// 依据自定义全局 ID 顺序排布平铺账户
  List<db.Account> _sortFlatAccounts(
    List<db.Account> accounts,
    List<int> orderIds,
  ) {
    if (orderIds.isEmpty) return accounts;
    final map = {for (final a in accounts) a.id: a};
    final sorted = <db.Account>[];
    for (final id in orderIds) {
      final acc = map.remove(id);
      if (acc != null) sorted.add(acc);
    }
    sorted.addAll(map.values);
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final accountsAsync = ref.watch(allAccountsStreamProvider);
    final allStatsAsync = ref.watch(allAccountStatsProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final showGrouping = ref.watch(showAccountGroupingProvider);
    final globalOrderIds = ref.watch(customAccountOrderProvider);
    ref.watch(thousandSeparatorProvider);

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: widget.asTab ? l10n.tabAssets : l10n.accountsTitle,
        leading: widget.asTab ? null : const BackButton(),
        actions: [
          // vivo OriginOS 规范：右上角“竖排双圆点”展示更多功能
          OriginMoreButton(
            tooltip: '更多与设置',
            items: [
              OriginMenuItem(
                title: l10n.accountAddButton,
                icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor),
                onTap: () => _openAddAccount(context, ledgerId),
              ),
              OriginMenuItem(
                title: '净资产趋势',
                icon: const Icon(Icons.trending_up_rounded),
                onTap: () => _openNetWorthTrend(context),
              ),
              OriginMenuItem(
                title: '按类别分组',
                icon: Icon(
                  showGrouping ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                ),
                trailing: showGrouping
                    ? Icon(Icons.check_rounded, size: 18.0, color: primaryColor)
                    : null,
                onTap: () {
                  ref.read(showAccountGroupingProvider.notifier).toggle();
                },
              ),
              OriginMenuItem(
                title: '资产偏好设置',
                icon: const Icon(Icons.tune_rounded),
                onTap: () => showOriginAccountPreferencesSheet(context, ref),
              ),
              OriginMenuItem(
                title: l10n.accountHiddenSection,
                icon: const Icon(Icons.visibility_off_outlined),
                onTap: () => _openHiddenAccounts(context),
              ),
            ],
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: OriginTokens.textTertiary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.accountsEmptyMessage,
                    style: TextStyle(
                      color: OriginTokens.textSecondary(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    onPressed: () => _openAddAccount(context, ledgerId),
                    child: Text(l10n.accountAddButton),
                  ),
                ],
              ),
            );
          }

          // 计算资产汇总（净资产含隐藏账户，与官方核心统计口径一致）
          double totalAssets = 0.0;
          double totalLiabilities = 0.0;
          final statsMap = allStatsAsync.valueOrNull ?? {};

          for (final account in accounts) {
            final balance = statsMap[account.id]?.balance ?? account.initialBalance;
            if (isLiabilityType(account.type) || balance < 0) {
              totalLiabilities += balance.abs();
            } else {
              totalAssets += balance;
            }
          }
          final netAssets = totalAssets - totalLiabilities;

          // 核心分离：在用（未隐藏）账户与已隐藏账户
          final visibleAccounts = accounts.where((a) => !a.hidden).toList();
          final hiddenAccounts = accounts.where((a) => a.hidden).toList();

          final currencySymbol = getCurrencySymbol(baseCurrency);

          // 按账户类型分组
          final Map<String, List<db.Account>> grouped = {};
          for (final account in visibleAccounts) {
            grouped.putIfAbsent(account.type, () => []).add(account);
          }

          // 按照规范顺序对分类分组进行排序（优先标准账户分类，自定义在后）
          final sortedTypes = <String>[];
          for (final t in accountTypeOrder) {
            if (grouped.containsKey(t)) {
              sortedTypes.add(t);
            }
          }
          for (final t in grouped.keys) {
            if (!sortedTypes.contains(t)) {
              sortedTypes.add(t);
            }
          }

          // 平铺账户列表（优先读取拖拽乐观锁缓存，否则按照全局自定义顺序排序）
          final flatAccounts = _reorderingFlatAccounts ??
              _sortFlatAccounts(visibleAccounts, globalOrderIds);

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 0.0, bottom: 120.0),
            children: [
              // 1. 资产总览大卡片 (vivo 纯色 12dp 卡片，遵循 OriginUI 顶部间距规范)
              OriginCard(
                margin: const EdgeInsets.fromLTRB(
                  OriginTokens.cardMargin,
                  4.0,
                  OriginTokens.cardMargin,
                  6.0,
                ),
                padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
                onTap: () => _openNetWorthTrend(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l10n.netWorthTrendLineNet,
                          style: TextStyle(
                            fontSize: 13.0,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ref.read(hideAmountsProvider.notifier).state = !hideAmounts;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Icon(
                              hideAmounts
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18.0,
                              color: OriginTokens.textTertiary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      hideAmounts
                          ? '****'
                          : '$currencySymbol ${formatMoneyCompact(netAssets)}',
                      style: TextStyle(
                        fontSize: 26.0,
                        fontWeight: FontWeight.bold,
                        color: OriginTokens.textPrimary(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12.0),
                    const OriginDivider(startIndent: 0),
                    const SizedBox(height: 10.0),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.netWorthTrendLineAssets,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: OriginTokens.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                hideAmounts
                                    ? '****'
                                    : '$currencySymbol ${formatMoneyCompact(totalAssets)}',
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
                                l10n.netWorthTrendLineLiabilities,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: OriginTokens.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Text(
                                hideAmounts
                                    ? '****'
                                    : '$currencySymbol ${formatMoneyCompact(totalLiabilities)}',
                                style: const TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.w600,
                                  color: OriginTokens.expenseRed,
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

              // 2. 空隐藏账户提示
              if (visibleAccounts.isEmpty && hiddenAccounts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
                  child: Center(
                    child: Text(
                      '所有在用账户均已隐藏，可在右上角更多菜单中查看或恢复',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ),
                  ),
                ),

              // 3. 账户展示模式：按类别分组展示 VS 平铺全量展示
              if (showGrouping) ...[
                // === 模式 A：分组展示 ===
                for (final type in sortedTypes) ...[
                  Builder(
                    builder: (context) {
                      final items = _reorderingGroups?[type] ?? grouped[type]!;
                      double groupTotal = 0.0;
                      for (final acc in items) {
                        groupTotal += statsMap[acc.id]?.balance ?? acc.initialBalance;
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OriginSectionTitle(
                            title: getAccountTypeLabel(context, type),
                            trailing: Text(
                              hideAmounts
                                  ? '****'
                                  : '$currencySymbol ${formatMoneyCompact(groupTotal)}',
                              style: TextStyle(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                                color: OriginTokens.textTertiary(context),
                              ),
                            ),
                          ),
                          OriginCard(
                            padding: EdgeInsets.zero,
                            child: ReorderableListView.builder(
                              key: ValueKey('group-reorder-$type'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              proxyDecorator: _proxyDecorator,
                              itemCount: items.length,
                              onReorder: (oldIndex, newIndex) =>
                                  _onReorderGroup(type, items, oldIndex, newIndex),
                              itemBuilder: (context, index) {
                                final account = items[index];
                                final isFirst = index == 0;
                                final isLast = index == items.length - 1;
                                final rowRadius = BorderRadius.vertical(
                                  top: isFirst ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                                  bottom: isLast ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                                );

                                return ReorderableDelayedDragStartListener(
                                  key: ValueKey('grp-acc-${account.id}'),
                                  index: index,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _OriginAccountRow(
                                        account: account,
                                        balance: statsMap[account.id]?.balance ??
                                            account.initialBalance,
                                        currencySymbol: currencySymbol,
                                        hideAmounts: hideAmounts,
                                        borderRadius: rowRadius,
                                        onTap: () =>
                                            _openAccountDetail(context, account),
                                      ),
                                      if (index < items.length - 1)
                                        const OriginDivider(startIndent: 52.0),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ] else ...[
                // === 模式 B：平铺展示 ===
                if (flatAccounts.isNotEmpty) ...[
                  OriginSectionTitle(
                    title: '全部账户',
                    trailing: Text(
                      '长按可拖动排序',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w400,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ),
                  ),
                  OriginCard(
                    padding: EdgeInsets.zero,
                    child: ReorderableListView.builder(
                      key: const ValueKey('flat-accounts-reorderable-list'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      proxyDecorator: _proxyDecorator,
                      itemCount: flatAccounts.length,
                      onReorder: (oldIndex, newIndex) =>
                          _onReorderFlat(flatAccounts, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final account = flatAccounts[index];
                        final isFirst = index == 0;
                        final isLast = index == flatAccounts.length - 1;
                        final rowRadius = BorderRadius.vertical(
                          top: isFirst ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                          bottom: isLast ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                        );

                        return ReorderableDelayedDragStartListener(
                          key: ValueKey('flat-acc-${account.id}'),
                          index: index,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _OriginAccountRow(
                                account: account,
                                balance: statsMap[account.id]?.balance ??
                                    account.initialBalance,
                                currencySymbol: currencySymbol,
                                hideAmounts: hideAmounts,
                                typeLabel: getAccountTypeLabel(context, account.type),
                                borderRadius: rowRadius,
                                onTap: () => _openAccountDetail(context, account),
                              ),
                              if (index < flatAccounts.length - 1)
                                const OriginDivider(startIndent: 52.0),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

class _OriginAccountRow extends StatelessWidget {
  final db.Account account;
  final double balance;
  final String currencySymbol;
  final bool hideAmounts;
  final String? typeLabel;
  final BorderRadius? borderRadius;
  final VoidCallback onTap;

  const _OriginAccountRow({
    required this.account,
    required this.balance,
    required this.currencySymbol,
    required this.hideAmounts,
    this.typeLabel,
    this.borderRadius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 构造副标题文字：平铺模式下优先附带账户类别标签
    String? subtitleText;
    if (typeLabel != null && account.note != null && account.note!.isNotEmpty) {
      subtitleText = '$typeLabel · ${account.note}';
    } else if (typeLabel != null) {
      subtitleText = typeLabel;
    } else if (account.note != null && account.note!.isNotEmpty) {
      subtitleText = account.note;
    }

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  getIconForAccountType(account.type),
                  size: 20.0,
                  color: OriginTokens.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                  if (subtitleText != null && subtitleText.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              hideAmounts ? '****' : '$currencySymbol ${formatMoneyCompact(balance)}',
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: balance < 0
                    ? OriginTokens.expenseRed
                    : OriginTokens.textPrimary(context),
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.chevron_right_rounded,
              size: 20.0,
              color: OriginTokens.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}
