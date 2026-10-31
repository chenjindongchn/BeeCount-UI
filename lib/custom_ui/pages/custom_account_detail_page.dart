import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/account/account_edit_page.dart';
import '../../pages/account/detail/bindings/account_detail.dart';
import '../../pages/account/detail/controllers/account_detail_controller.dart';
import '../../pages/account/detail/widgets/account_detail_sections.dart';
import '../../pages/shared/transactions/bindings/transaction_tile.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/currency/rate_math.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/credit_card_amounts.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';
import 'custom_transaction_sheet.dart';
import '../providers/amount_format_provider.dart';

/// vivo OriginOS 风格自定义账户详情页面 (CustomAccountDetailPage)
///
/// 遵循全局定制规范与 OriginOS 交互体验：
/// 1. 顶部卡片采用左右排版布局：左侧余额标题，右侧数字金额，极简紧凑；
/// 2. 金额隐藏占位符严格与资产页面保持一致，使用 ****，不显示币种前缀；
/// 3. 删除卡片内部的眼睛按钮，由资产页面全局统一控制；
/// 4. 修复抽屉退出时背景页面闪烁：在抽屉打开及退场动画期间加锁防抖，退出平滑后再刷新数据；
/// 5. 底部常驻符合 OriginUI 规范的胶囊大按钮 (46dp高度 / 23dp圆角)；
/// 6. 顶部标题栏左上角直接展示当前资产名称（如“建设银行”）。
class CustomAccountDetailPage extends ConsumerStatefulWidget {
  final db.Account account;

  const CustomAccountDetailPage({
    super.key,
    required this.account,
  });

  @override
  ConsumerState<CustomAccountDetailPage> createState() =>
      _CustomAccountDetailPageState();
}

class _CustomAccountDetailPageState
    extends ConsumerState<CustomAccountDetailPage> {
  final _scroll = ScrollController();
  late final AccountDetailController c;
  bool _accountActionBusy = false;
  bool _isSheetOpen = false;

  @override
  void initState() {
    super.initState();
    c = AccountDetailController(
      repository: ref.read(repositoryProvider),
      account: widget.account,
    );
    // 默认展示全量周期的交易流水
    c.period = 'all';

    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
        unawaited(c.loadMore());
      }
    });

    unawaited(c.refresh());
  }

  @override
  void dispose() {
    _scroll.dispose();
    c.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_accountActionBusy) return;
    _accountActionBusy = true;
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showBeeToast(
          context,
          '${AppLocalizations.of(context).commonError}: $error',
          tone: BeeTone.error,
        );
      }
    } finally {
      _accountActionBusy = false;
    }
  }

  void _refresh() {
    ref.invalidate(accountStatsProvider(c.account.id));
    ref.invalidate(accountCategoryStatsProvider);
    ref.invalidate(accountPeriodCategoryStatsProvider);
    // 注意：不 invalidate accountDetailReferencesProvider，防止列表条目元数据闪空
    unawaited(c.refresh());
  }

  void _onDataChanged() {
    // 抽屉展开及退场动画期间，不触发底层页面刷新，避免背景重绘跳闪
    if (_isSheetOpen) return;
    unawaited(c.refresh());
  }

  Future<void> _edit() async {
    if (c.account.id < 0) return;
    final ledgerRow = ref.read(currentLedgerProvider).valueOrNull;
    if (ledgerRow == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        allowSnapshotting: false,
        builder: (_) =>
            AccountEditPage(account: c.account, ledgerId: ledgerRow.id),
      ),
    );
    if (changed == true && mounted) _refresh();
  }

  /// 唤起 OriginOS 记账抽屉，默认带入当前账户
  /// 修复退出时底层页面闪烁根因：
  /// 1. 只有真正保存了记录（saved == true）才需要刷新，用户取消/滑动退出时不执行任何刷新；
  /// 2. 必须等待退场动画（200ms）完全结束、抽屉彻底销毁出视野后（延时 280ms），再平滑静默刷新；
  /// 3. 不 invalidate 静态元数据字典，杜绝条目图标与文字闪白跳变。
  Future<void> _record() async {
    if (c.account.hidden || c.account.id < 0) return;
    _isSheetOpen = true;
    final saved = await showCustomTransactionSheet(
      context,
      initialKind: 'expense',
      initialAccountId: c.account.id,
    );

    // 抽屉退出动画（200ms）彻底完成后，再解锁并静默刷新
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _isSheetOpen = false;

    if (saved == true && mounted) {
      _refresh();
    }
  }

  Future<void> _value() async {
    final value = await showAccountValuationDialog(context, c.account);
    if (value == null || !mounted) return;
    try {
      await ref.read(repositoryProvider).updateAccountValuation(
            c.account.id,
            isLiabilityType(c.account.type) ? -value.abs() : value,
          );
      ref.read(statsRefreshProvider.notifier).state++;
      if (mounted) {
        showBeeToast(
          context,
          AppLocalizations.of(context).commonSave,
          tone: BeeTone.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(
          context,
          '${AppLocalizations.of(context).commonError}: $e',
          tone: BeeTone.error,
        );
      }
    }
  }

  Future<void> _search() async {
    final l = AppLocalizations.of(context);
    final result = await showBeeSheet<String>(
      context,
      title: l.searchTitle,
      child: BeeAccountTransactionSearch(
        initialQuery: c.query,
        hint: l.searchTitle,
        confirmLabel: l.commonConfirm,
        clearLabel: l.searchClearFilter,
        onConfirm: (value) => Navigator.pop(context, value),
      ),
    );
    if (result != null && mounted) {
      await c.filter(direction: c.flow, text: result.trim(), order: c.sort);
    }
  }

  Future<void> _ledgers() async {
    final id = await showBeeSheet<int>(
      context,
      title: AppLocalizations.of(context).v4AccountLinkedBooks,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final book
              in c.ledgers.where((book) => c.usage.containsKey(book.id)))
            BeeMenuRow(
              title: book.name,
              subtitle: '${c.usage[book.id]}',
              leading: const BeeLineIcon('BookOpen'),
              onTap: () => Navigator.pop(context, book.id),
            ),
          if (c.usage.isEmpty) Text(AppLocalizations.of(context).commonEmpty),
        ],
      ),
    );
    if (id != null && mounted) {
      final name = c.ledgers.firstWhere((book) => book.id == id).name;
      await c.filter(direction: null, text: name, order: c.sort);
    }
  }

  Future<void> _toggleHidden() async {
    final a = c.account,
        l = AppLocalizations.of(context),
        repo = ref.read(repositoryProvider);
    if (a.id < 0) return;
    if (!a.hidden) {
      final recurring = await repo.getActiveRecurringCountByAccount(a.id);
      if (!mounted) return;
      final ok = await showBeeConfirm(
        context,
        title: l.accountHideConfirmTitle,
        message: recurring > 0
            ? '${l.accountHideConfirmBody}\n${l.accountHideRecurringWarn(recurring)}'
            : l.accountHideConfirmBody,
        confirmLabel: l.accountHide,
        cancelLabel: l.commonCancel,
      );
      if (!ok || !mounted) return;
    }
    await repo.setAccountHidden(a.id, !a.hidden);
    if (!a.hidden) {
      final setter = ref.read(defaultAccountSetterProvider);
      if (await ref.read(defaultIncomeAccountIdProvider.future) == a.id) {
        await setter.setDefaultIncomeAccountId(null);
        ref.invalidate(defaultIncomeAccountIdProvider);
      }
      if (await ref.read(defaultExpenseAccountIdProvider.future) == a.id) {
        await setter.setDefaultExpenseAccountId(null);
        ref.invalidate(defaultExpenseAccountIdProvider);
      }
    }
    if (mounted) {
      PostProcessor.sync(ref, ledgerId: ref.read(currentLedgerIdProvider));
      ref.read(statsRefreshProvider.notifier).state++;
      _refresh();
    }
  }

  Future<void> _delete() async {
    if (c.account.id < 0) return;
    final l = AppLocalizations.of(context), repo = ref.read(repositoryProvider);
    final count = await repo.getTransactionCountByAccount(c.account.id);
    if (!mounted) return;
    final ok = await showBeeConfirm(
      context,
      title: count > 0 ? l.accountDeleteWarningTitle : l.commonConfirm,
      message: count > 0
          ? l.accountDeleteWarningMessage(count)
          : l.accountDeleteConfirm,
      confirmLabel: l.commonDelete,
      cancelLabel: l.commonCancel,
      danger: true,
    );
    if (ok && mounted) {
      await repo.deleteAccount(c.account.id);
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: ref.read(currentLedgerIdProvider));
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _menu() async {
    final l = AppLocalizations.of(context);
    final action = await showBeeSheet<String>(
      context,
      title: l.v4AccountActions,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.account.id >= 0)
            BeeMenuRow(
              title: l.accountEditTitle,
              leading: const BeeLineIcon('PencilLine'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
          if (!isValuationOnlyType(c.account.type))
            BeeMenuRow(
              title: l.searchTitle,
              leading: const BeeLineIcon('Search'),
              onTap: () => Navigator.pop(context, 'search'),
            ),
          BeeMenuRow(
            title: l.v4AccountLinkedBooks,
            leading: const BeeLineIcon('BookOpen'),
            onTap: () => Navigator.pop(context, 'ledgers'),
          ),
          if (c.account.id >= 0) ...[
            BeeMenuRow(
              title: c.account.hidden ? l.accountRestore : l.accountHide,
              leading: const BeeLineIcon('EyeOff'),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
            BeeMenuRow(
              title: l.commonDelete,
              leading: const BeeLineIcon('Trash2'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _edit();
      case 'search':
        await _search();
      case 'ledgers':
        await _ledgers();
      case 'hide':
        await _toggleHidden();
      case 'delete':
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    ref.watch(thousandSeparatorProvider);
    ref.listen(statsRefreshProvider, (_, __) => _onDataChanged());
    ref.listen(syncGenerationProvider, (_, __) => _onDataChanged());
    final refs = ref.watch(accountDetailReferencesProvider);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) => Consumer(
        builder: (context, ref, _) {
          final metadata = ref.watch(
            accountRowMetadataProvider(c.rows.map((t) => t.id).join(',')),
          );
          final valuation = isValuationOnlyType(c.account.type);
          final hidden = ref.watch(hideAmountsProvider);

          return OriginScaffold(
            appBar: _CustomAccountTopAppBar(
              title: c.account.name,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: OriginTokens.textPrimary(context),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                IconButton(
                  icon: OriginMoreIcon(
                    size: 20,
                    color: OriginTokens.textPrimary(context),
                  ),
                  tooltip: l.commonMore,
                  onPressed: () => _perform(_menu),
                ),
              ],
            ),
            // 底部常驻符合 OriginUI 规范的胶囊大按钮
            bottomNavigationBar: SafeArea(
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
                        borderRadius:
                            BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    onPressed: c.account.hidden || c.account.id < 0
                        ? null
                        : () => _perform(valuation ? _value : _record),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          valuation ? Icons.edit_outlined : Icons.add_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          valuation
                              ? (isLiabilityType(c.account.type)
                                  ? l.valuationUpdateDebt
                                  : l.valuationUpdateValue)
                              : l.widgetQuickAddLabel,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            body: c.error != null && c.rows.isEmpty
                ? Center(
                    child: BeeStatus(
                      label: l.commonError,
                      tone: BeeTone.error,
                      action: BeeButton(
                        label: l.v4RecordingRetry,
                        onPressed: _refresh,
                      ),
                    ),
                  )
                : c.loading && c.rows.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scroll,
                        // 列表水平边距设为 0，由各卡片统一由 OriginTokens.cardMargin 控制，与其他页面完全对齐
                        padding: const EdgeInsets.only(top: 4, bottom: 20),
                        itemCount: valuation ? 1 : c.rows.length + 2,
                        itemBuilder: (context, index) {
                          // 顶部资产卡片与交易记录小标题
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _CompactAccountSummaryCard(
                                  account: c.account,
                                  balance: c.stats.balance,
                                  hidden: hidden,
                                  valuation: valuation,
                                ),
                                if (!valuation) ...[
                                  // 交易记录标题，完全去掉了右侧搜索与筛选按钮，左右对齐 20dp
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 8,
                                      left: OriginTokens.cardMargin + 2,
                                      right: OriginTokens.cardMargin + 2,
                                    ),
                                    child: Text(
                                      l.accountTransactionHistory,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            OriginTokens.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          }

                          // 列表底部加载状态
                          if (index == c.rows.length + 1) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: c.error != null
                                  ? BeeStatus(
                                      label: l.commonError,
                                      tone: BeeTone.error,
                                      action: BeeButton(
                                        label: l.v4RecordingRetry,
                                        onPressed: _refresh,
                                      ),
                                    )
                                  : c.loadingMore
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : c.rows.isEmpty
                                          ? BeeEmptyState(
                                              title: l.accountNoTransactions,
                                            )
                                          : Text(
                                              l.accountNoMoreData,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: OriginTokens
                                                    .textTertiary(context),
                                              ),
                                            ),
                            );
                          }

                          // 交易记录条目卡片：外层左右边距严格保持为 OriginTokens.cardMargin (20dp)
                          final t = c.rows[index - 1];
                          final resources = refs.valueOrNull;
                          final direction = t.accountId == c.account.id &&
                                  t.toAccountId != c.account.id
                              ? -1
                              : t.toAccountId == c.account.id &&
                                      t.accountId != c.account.id
                                  ? 1
                                  : 0;

                          final isFirst = index == 1;
                          final isLast = index == c.rows.length;

                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: OriginTokens.cardMargin,
                            ),
                            decoration: BoxDecoration(
                              color: OriginTokens.cardBackground(context),
                              borderRadius: BorderRadius.vertical(
                                top: isFirst
                                    ? const Radius.circular(
                                        OriginTokens.cardRadius)
                                    : Radius.zero,
                                bottom: isLast
                                    ? const Radius.circular(
                                        OriginTokens.cardRadius)
                                    : Radius.zero,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              children: [
                                TransactionTileBinding(
                                  key: ValueKey('account-transaction-${t.id}'),
                                  row: (
                                    t: t,
                                    category: resources?.categoryFor(t),
                                    account: resources?.accounts[t.accountId],
                                    toAccount:
                                        resources?.accounts[t.toAccountId],
                                  ),
                                  tags: metadata.valueOrNull?.tags[t.id] ??
                                      const [],
                                  attachmentCount: metadata
                                          .valueOrNull?.attachments[t.id] ??
                                      0,
                                  fullDate: true,
                                  allLedgers: true,
                                  ledgerName:
                                      resources?.ledgers[t.ledgerId]?.name,
                                  baseCurrency:
                                      resources?.ledgers[t.ledgerId]?.currency,
                                  transferDirection: direction,
                                  onReturned: _refresh,
                                ),
                                if (!isLast)
                                  const OriginDivider(startIndent: 48),
                              ],
                            ),
                          );
                        },
                      ),
          );
        },
      ),
    ),
  );
}
}

/// 顶部紧凑导航栏：左侧返回箭头紧随卡片名称，右侧操作菜单
class _CustomAccountTopAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const _CustomAccountTopAppBar({
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(OriginTokens.smallTitleHeight);

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bg = OriginTokens.pageBackground(context);

    return Container(
      color: bg,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: SizedBox(
        height: OriginTokens.smallTitleHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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

/// 精简优雅的顶部资产卡片（左右排版，无眼睛按钮，统一使用 **** 占位）
///
/// 遵循需求：
/// 1. 左边余额标题，右边数字金额；
/// 2. 删除卡片内部的显隐眼睛按钮，由资产页面的显隐状态统一控制联动；
/// 3. 金额隐藏时统一呈现 ****，不显示货币前缀，与资产主页面 100% 对齐；
/// 4. 卡片左右边距与全局标准卡片保持一致 (OriginTokens.cardMargin = 20dp)。
class _CompactAccountSummaryCard extends ConsumerWidget {
  final db.Account account;
  final double balance;
  final bool hidden;
  final bool valuation;

  const _CompactAccountSummaryCard({
    required this.account,
    required this.balance,
    required this.hidden,
    required this.valuation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final credit = account.type == 'credit_card';
    final liability = isLiabilityType(account.type);
    final symbol = getDistinctCurrencySymbol(account.currency);
    final base = ref.watch(baseCurrencyProvider);
    final rates = ref.watch(effectiveRatesProvider).valueOrNull;

    final amounts = CreditCardAmounts(balance, limit: account.creditLimit);
    final debt = amounts.debt;
    final value = credit
        ? (amounts.overpayment > 0 ? amounts.overpayment : debt)
        : valuation && liability
            ? balance.abs()
            : balance;

    final balanceLabel = credit
        ? (amounts.overpayment > 0
            ? l.creditCardOverpayment
            : l.creditCardOwed)
        : valuation
            ? (liability ? l.valuationCurrentDebt : l.valuationCurrentValue)
            : l.accountBalance;

    // 严格与资产页面保持一致：隐藏状态下为 ****
    final amountText = hidden
        ? '****'
        : formatMoneyCompact(value, trimZeros: false);

    // 外币换算提示（未隐藏且币种不同于账本基准币时呈现）
    String? conversionText;
    if (!hidden && account.currency.toUpperCase() != base.toUpperCase()) {
      if (rates != null) {
        final converted = computeNativeAmount(
          amount: balance,
          accountCurrency: account.currency,
          ledgerBase: base,
          rates: rates,
        );
        if (converted != null) {
          conversionText =
              '≈ ${getDistinctCurrencySymbol(base)}${formatMoneyCompact(converted, trimZeros: false)}';
        }
      }
    }

    final due = daysUntilAccountPayment(account.paymentDueDay, DateTime.now());

    return OriginCard(
      // margin 默认即为 horizontal: OriginTokens.cardMargin (20dp), vertical: 6.0
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：余额标题及信用卡额度提醒（若有）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  balanceLabel,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: OriginTokens.textSecondary(context),
                  ),
                ),
                if (credit && (account.creditLimit != null || due != null)) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    [
                      if (account.creditLimit != null)
                        '${l.creditLimit} ${hidden ? '****' : '$symbol${formatMoneyCompact(account.creditLimit!, trimZeros: false)}'}',
                      if (due != null)
                        (due == 0
                            ? l.creditCardPaymentDueToday
                            : l.creditCardDaysUntilPayment(due)),
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 11.0,
                      color: due != null && due <= 3
                          ? Theme.of(context).colorScheme.error
                          : OriginTokens.textTertiary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 右侧：核心数字金额及外币换算（若有）
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (!hidden && symbol.isNotEmpty) ...[
                    Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
              if (!hidden && conversionText != null) ...[
                const SizedBox(height: 2.0),
                Text(
                  conversionText,
                  style: TextStyle(
                    fontSize: 11.0,
                    color: OriginTokens.textTertiary(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
