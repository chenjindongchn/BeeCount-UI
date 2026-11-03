import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import 'custom_account_edit_page.dart';
import '../../pages/account/detail/bindings/account_detail.dart';
import '../../pages/account/detail/controllers/account_detail_controller.dart';
import '../../pages/account/detail/widgets/account_detail_sections.dart';
import '../widgets/custom_transaction_tile.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/currency/rate_math.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/credit_card_amounts.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_hero_card.dart';
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

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final weekday = weekdays[date.weekday - 1];

    final prefix = date.year == now.year
        ? '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日'
        : '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';

    if (isToday) {
      return '$prefix 今天 · $weekday';
    } else if (isYesterday) {
      return '$prefix 昨天 · $weekday';
    }
    return '$prefix $weekday';
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
            CustomAccountEditPage(account: c.account, ledgerId: ledgerRow.id),
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
          final hasMultipleLedgers =
              (ref.watch(localLedgersProvider).valueOrNull?.length ?? 0) > 1;

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
                OriginMoreButton(
                  tooltip: l.commonMore,
                  items: [
                    if (c.account.id >= 0)
                      OriginMenuItem(
                        title: l.accountEditTitle,
                        icon: const Icon(Icons.edit_outlined),
                        onTap: () => _perform(_edit),
                      ),
                    if (!valuation)
                      OriginMenuItem(
                        title: l.searchTitle,
                        icon: const Icon(Icons.search_rounded),
                        onTap: () => _perform(_search),
                      ),
                    if (hasMultipleLedgers)
                      OriginMenuItem(
                        title: l.v4AccountLinkedBooks,
                        icon: const Icon(Icons.auto_stories_outlined),
                        onTap: () => _perform(_ledgers),
                      ),
                    if (c.account.id >= 0) ...[
                      OriginMenuItem(
                        title: c.account.hidden ? l.accountRestore : l.accountHide,
                        icon: Icon(
                          c.account.hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onTap: () => _perform(_toggleHidden),
                      ),
                      OriginMenuItem(
                        title: l.commonDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        isDestructive: true,
                        onTap: () => _perform(_delete),
                      ),
                    ],
                  ],
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
                    child: Text(
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

                          final prevT = index > 1 ? c.rows[index - 2] : null;
                          final isNewDay = prevT == null ||
                              prevT.happenedAt.year != t.happenedAt.year ||
                              prevT.happenedAt.month != t.happenedAt.month ||
                              prevT.happenedAt.day != t.happenedAt.day;

                          final nextT = index < c.rows.length ? c.rows[index] : null;
                          final nextIsNewDay = nextT != null &&
                              (nextT.happenedAt.year != t.happenedAt.year ||
                               nextT.happenedAt.month != t.happenedAt.month ||
                               nextT.happenedAt.day != t.happenedAt.day);

                          final isFirst = index == 1;
                          final isLast = index == c.rows.length;

                          final cardBorderRadius = BorderRadius.vertical(
                            top: isFirst
                                ? const Radius.circular(
                                    OriginTokens.cardRadius)
                                : Radius.zero,
                            bottom: isLast
                                ? const Radius.circular(
                                    OriginTokens.cardRadius)
                                : Radius.zero,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: OriginTokens.cardMargin,
                            ),
                            child: Material(
                              color: OriginTokens.cardBackground(context),
                              borderRadius: cardBorderRadius,
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 跨天轻量日期小标题栏
                                  if (isNewDay) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 10.0),
                                      child: Text(
                                        _formatDateHeader(t.happenedAt),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: OriginTokens.textPrimary(context),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const OriginDivider(startIndent: 0),
                                  ],
                                  CustomTransactionTileBinding(
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
                                    allLedgers: hasMultipleLedgers,
                                    allowCategoryNavigation: false,
                                    ledgerName: hasMultipleLedgers
                                        ? resources?.ledgers[t.ledgerId]?.name
                                        : null,
                                    baseCurrency:
                                        resources?.ledgers[t.ledgerId]?.currency,
                                    transferDirection: direction,
                                    onReturned: _refresh,
                                  ),
                                  if (!isLast)
                                    OriginDivider(startIndent: nextIsNewDay ? 0 : 56),
                                ],
                              ),
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
    final isLocked = ref.watch(currencyLockedProvider);
    final showCurrency = !isLocked && ref.watch(currencySymbolVisibleProvider);
    final symbol = showCurrency ? getDistinctCurrencySymbol(account.currency) : '';
    final unit = isLocked ? '' : (account.currency == 'CNY' ? '元' : symbol);
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

    final due = daysUntilAccountPayment(account.paymentDueDay, DateTime.now());

    // 外币换算提示（未锁定、未隐藏且币种不同于账本基准币时呈现）
    String? conversionText;
    if (!isLocked && !hidden && account.currency.toUpperCase() != base.toUpperCase()) {
      if (rates != null) {
        final converted = computeNativeAmount(
          amount: balance,
          accountCurrency: account.currency,
          ledgerBase: base,
          rates: rates,
        );
        if (converted != null) {
          final baseSymbol = showCurrency ? getDistinctCurrencySymbol(base) : '';
          conversionText =
              '≈ $baseSymbol${formatMoneyCompact(converted, trimZeros: false)}';
        }
      }
    }

    final List<OriginHeroMetric> metrics = [];

    if (credit) {
      if (account.creditLimit != null) {
        metrics.add(
          OriginHeroMetric(
            label: l.creditLimit,
            unit: unit,
            value: formatMoneyCompact(account.creditLimit!, trimZeros: false),
          ),
        );
      }
      if (due != null) {
        metrics.add(
          OriginHeroMetric(
            label: '还款提醒',
            value: due == 0
                ? l.creditCardPaymentDueToday
                : l.creditCardDaysUntilPayment(due),
            valueColor: due <= 3 ? const Color(0xFFFF5252) : null,
          ),
        );
      }
    } else if (conversionText != null) {
      metrics.add(
        OriginHeroMetric(
          label: '折合基准币',
          value: conversionText,
        ),
      );
      if (!isLocked) {
        metrics.add(
          OriginHeroMetric(
            label: '账户币种',
            value: account.currency.toUpperCase(),
          ),
        );
      }
    } else if (!isLocked && account.currency.toUpperCase() != base.toUpperCase()) {
      metrics.add(
        OriginHeroMetric(
          label: '账户币种',
          value: account.currency.toUpperCase(),
        ),
      );
    }

    // 单项资产大看板卡片 (统一 OriginHeroCard，19.0dp 圆角，主题色沉浸感，无磨砂条)
    // 根据 OriginOS 极简体验原则：点进资产详情即已明确资产类型，移除冗余的卡片类型标签（包括银行卡、信用卡等）
    return OriginHeroCard(
      title: balanceLabel,
      unit: unit,
      mainAmount: formatMoneyCompact(value, trimZeros: false),
      hideAmounts: hidden,
      onToggleHideAmounts: () {
        ref.read(hideAmountsProvider.notifier).state = !hidden;
      },
      metrics: metrics,
    );
  }
}
