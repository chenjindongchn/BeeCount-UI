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

  void _openExchangeRate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ExchangeRatePage(),
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
            icon: const Icon(Icons.currency_exchange_rounded),
            tooltip: '汇率管理',
            onPressed: () => _openExchangeRate(context),
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
