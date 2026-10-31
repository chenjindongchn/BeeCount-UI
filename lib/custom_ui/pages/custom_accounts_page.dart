import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../data/db.dart' as db;
import '../../utils/format_money.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../pages/account/account_edit_page.dart';
import '../../pages/account/account_detail_page.dart';
import '../../pages/account/net_worth_trend_page.dart';
import '../../pages/currency/exchange_rate_page.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_setting_card.dart';

/// vivo OriginOS 风格资产总览与账户管理页面 (CustomAccountsPage)
///
/// 遵循 `OriginUI/docs/` 规范：
/// 1. 大标题栏（84dp / 22sp SemiBold）；
/// 2. 资产总览采用 12dp 纯色卡片，清晰呈现净资产、总资产、总负债；
/// 3. 分类账户列表使用 12dp 卡片 + 0.5dp 发丝分割线；
/// 4. 纯 Riverpod 驱动，不修改业务表与数据库逻辑。
class CustomAccountsPage extends ConsumerStatefulWidget {
  final bool asTab;
  const CustomAccountsPage({super.key, this.asTab = true});

  @override
  ConsumerState<CustomAccountsPage> createState() => _CustomAccountsPageState();
}

class _CustomAccountsPageState extends ConsumerState<CustomAccountsPage> {
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

  void _openAccountPreferences(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomAccountPreferencesSheet(),
    );
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

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: widget.asTab ? l10n.tabAssets : l10n.accountsTitle,
        leading: widget.asTab ? null : const BackButton(),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: OriginTokens.textPrimary(context)),
            tooltip: l10n.commonSettings,
            onPressed: () => _openAccountPreferences(context),
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: primaryColor),
            tooltip: l10n.accountAddButton,
            onPressed: () => _openAddAccount(context, ledgerId),
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

          // 计算资产汇总
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

          // 按账户类型分组
          final Map<String, List<db.Account>> grouped = {};
          for (final account in accounts) {
            grouped.putIfAbsent(account.type, () => []).add(account);
          }

          final currencySymbol = getCurrencySymbol(baseCurrency);

          return ListView(
            padding: const EdgeInsets.only(top: 8.0, bottom: 120.0),
            children: [
              // 1. 资产总览大卡片 (vivo 纯色 12dp 卡片)
              OriginCard(
                onTap: () => _openNetWorthTrend(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.netWorthTrendLineNet,
                          style: TextStyle(
                            fontSize: 13.0,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            hideAmounts
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18.0,
                            color: OriginTokens.textTertiary(context),
                          ),
                          onPressed: () {
                            ref.read(hideAmountsProvider.notifier).state = !hideAmounts;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6.0),
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
                    const SizedBox(height: 16.0),
                    const OriginDivider(startIndent: 0),
                    const SizedBox(height: 12.0),
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

              // 2. 分类账户列表
              for (final entry in grouped.entries) ...[
                OriginSectionTitle(
                  title: getAccountTypeLabel(context, entry.key),
                ),
                OriginCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const OriginDivider(startIndent: 52.0),
                        _OriginAccountRow(
                          account: entry.value[i],
                          balance: statsMap[entry.value[i].id]?.balance ??
                              entry.value[i].initialBalance,
                          currencySymbol: currencySymbol,
                          hideAmounts: hideAmounts,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AccountDetailPage(
                                  account: entry.value[i],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
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
  final VoidCallback onTap;

  const _OriginAccountRow({
    required this.account,
    required this.balance,
    required this.currencySymbol,
    required this.hideAmounts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
                  if (account.note != null && account.note!.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      account.note!,
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

/// vivo OriginOS 风格账户偏好设置抽屉
class _CustomAccountPreferencesSheet extends ConsumerWidget {
  const _CustomAccountPreferencesSheet();

  Future<void> _pickAccountDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<db.Account> accounts,
    required int? currentId,
    required bool isIncome,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ref.read(primaryColorProvider);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: OriginTokens.cardSecondary(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.not_interested_rounded,
                          size: 18,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                      title: Text(
                        '不设默认',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: currentId == null ? FontWeight.w600 : FontWeight.normal,
                          color: currentId == null
                              ? primaryColor
                              : OriginTokens.textPrimary(context),
                        ),
                      ),
                      trailing: currentId == null
                          ? Icon(Icons.check_rounded, color: primaryColor)
                          : null,
                      onTap: () async {
                        final setter = ref.read(defaultAccountSetterProvider);
                        if (isIncome) {
                          await setter.setDefaultIncomeAccountId(null);
                          ref.invalidate(defaultIncomeAccountIdProvider);
                        } else {
                          await setter.setDefaultExpenseAccountId(null);
                          ref.invalidate(defaultExpenseAccountIdProvider);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    ),
                    for (final acc in accounts)
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: OriginTokens.cardSecondary(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getIconForAccountType(acc.type),
                            size: 18,
                            color: OriginTokens.textPrimary(context),
                          ),
                        ),
                        title: Text(
                          acc.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: currentId == acc.id ? FontWeight.w600 : FontWeight.normal,
                            color: currentId == acc.id
                                ? primaryColor
                                : OriginTokens.textPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          '${acc.currency} · ${getAccountTypeLabel(context, acc.type)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        trailing: currentId == acc.id
                            ? Icon(Icons.check_rounded, color: primaryColor)
                            : null,
                        onTap: () async {
                          final setter = ref.read(defaultAccountSetterProvider);
                          if (isIncome) {
                            await setter.setDefaultIncomeAccountId(acc.id);
                            ref.invalidate(defaultIncomeAccountIdProvider);
                          } else {
                            await setter.setDefaultExpenseAccountId(acc.id);
                            ref.invalidate(defaultExpenseAccountIdProvider);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allAccounts = (ref.watch(allAccountsStreamProvider).valueOrNull ?? const <db.Account>[])
        .where((a) => !a.hidden)
        .toList();
    final defaultExpenseId = ref.watch(defaultExpenseAccountIdProvider).valueOrNull;
    final defaultIncomeId = ref.watch(defaultIncomeAccountIdProvider).valueOrNull;
    final hasMultipleCurrencies = (ref.watch(usedCurrenciesProvider).valueOrNull?.length ?? 0) >= 2;

    String accountName(int? id) {
      if (id == null) return '不设默认';
      final acc = allAccounts.where((a) => a.id == id).firstOrNull;
      return acc?.name ?? '不设默认';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部拖拽指示条
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '账户偏好设置',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: OriginTokens.textSecondary(context),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),
              // 设置分组卡片
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: OriginSettingGroup(
                  items: [
                    OriginSettingItem(
                      leading: Icon(Icons.arrow_upward_rounded, color: OriginTokens.expenseRed, size: 20),
                      title: '默认支出账户',
                      valueText: accountName(defaultExpenseId),
                      onTap: () => _pickAccountDialog(
                        context,
                        ref,
                        title: '选择默认支出账户',
                        accounts: allAccounts,
                        currentId: defaultExpenseId,
                        isIncome: false,
                      ),
                    ),
                    OriginSettingItem(
                      leading: Icon(Icons.arrow_downward_rounded, color: OriginTokens.incomeGreen, size: 20),
                      title: '默认收入账户',
                      valueText: accountName(defaultIncomeId),
                      onTap: () => _pickAccountDialog(
                        context,
                        ref,
                        title: '选择默认收入账户',
                        accounts: allAccounts,
                        currentId: defaultIncomeId,
                        isIncome: true,
                      ),
                    ),
                  ],
                ),
              ),
              // 多币种汇率管理（仅多币种时展示）
              if (hasMultipleCurrencies) ...[
                const SizedBox(height: 12.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: OriginSettingGroup(
                    items: [
                      OriginSettingItem(
                        leading: Icon(Icons.currency_exchange_rounded, color: primaryColor, size: 20),
                        title: l10n.exchangeRatePageTitle,
                        subtitle: '多币种换算汇率管理',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ExchangeRatePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

