import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../data/db.dart' as db;
import '../../utils/format_money.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../services/billing/post_processor.dart';
import '../styles/origin_tokens.dart';
import '../providers/amount_format_provider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import 'custom_account_detail_page.dart';

/// vivo OriginOS 风格已隐藏账户管理页面 (CustomHiddenAccountsPage)
///
/// 遵循全局定制与第一性原理：
/// 1. 将已隐藏账户从资产主视觉流彻底收敛至独立二级页面；
/// 2. 统计已隐藏账户汇总金额与数量；
/// 3. 支持快捷恢复账户至主列表，或进入详情查看流水；
/// 4. 纯 Riverpod 驱动，保持底层数据库与同步协议零改动。
class CustomHiddenAccountsPage extends ConsumerStatefulWidget {
  const CustomHiddenAccountsPage({super.key});

  @override
  ConsumerState<CustomHiddenAccountsPage> createState() => _CustomHiddenAccountsPageState();
}

class _CustomHiddenAccountsPageState extends ConsumerState<CustomHiddenAccountsPage> {
  Future<void> _restoreAccount(BuildContext context, db.Account account) async {
    final repo = ref.read(repositoryProvider);
    await repo.setAccountHidden(account.id, false);
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
    }
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.accountRestoredToast}：${account.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountsAsync = ref.watch(allAccountsStreamProvider);
    final allStatsAsync = ref.watch(allAccountStatsProvider);
    final hideAmounts = ref.watch(hideAmountsProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final isLocked = ref.watch(currencyLockedProvider);
    final showCurrency = !isLocked && ref.watch(currencySymbolVisibleProvider);
    final currencySymbol =
        showCurrency ? getCurrencySymbol(baseCurrency) : '';

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l10n.accountHiddenSection,
        leading: const BackButton(),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          final hiddenAccounts = accounts.where((a) => a.hidden).toList();
          final statsMap = allStatsAsync.valueOrNull ?? {};

          if (hiddenAccounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 64,
                    color: OriginTokens.textTertiary(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无已隐藏账户',
                    style: TextStyle(
                      color: OriginTokens.textSecondary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '在账户详情或编辑中设置隐藏后，将归集在此处',
                    style: TextStyle(
                      color: OriginTokens.textTertiary(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          // 计算隐藏账户合计
          double hiddenTotal = 0.0;
          for (final account in hiddenAccounts) {
            final balance = statsMap[account.id]?.balance ?? account.initialBalance;
            hiddenTotal += balance;
          }

          return ListView(
            padding: const EdgeInsets.only(top: 0.0, bottom: 48.0),
            children: [
              // 1. 顶部提示与汇总卡片
              OriginCard(
                margin: const EdgeInsets.fromLTRB(
                  OriginTokens.cardMargin,
                  4.0,
                  OriginTokens.cardMargin,
                  8.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16.0,
                          color: OriginTokens.textSecondary(context),
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            l10n.v4AssetsHiddenIncluded,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: OriginTokens.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    const OriginDivider(startIndent: 0),
                    const SizedBox(height: 10.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '隐藏账户数量',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: OriginTokens.textTertiary(context),
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              '${hiddenAccounts.length} 个',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: OriginTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '隐藏资产合计',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: OriginTokens.textTertiary(context),
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              hideAmounts
                                  ? '****'
                                  : '${currencySymbol.isNotEmpty ? "$currencySymbol " : ""}${formatMoneyCompact(hiddenTotal)}',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: OriginTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. 隐藏账户列表卡片
              OriginCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < hiddenAccounts.length; i++) ...[
                      if (i > 0) const OriginDivider(startIndent: 52.0),
                      _HiddenAccountRow(
                        account: hiddenAccounts[i],
                        balance: statsMap[hiddenAccounts[i].id]?.balance ??
                            hiddenAccounts[i].initialBalance,
                        currencySymbol: currencySymbol,
                        hideAmounts: hideAmounts,
                        borderRadius: BorderRadius.vertical(
                          top: i == 0 ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                          bottom: i == hiddenAccounts.length - 1 ? const Radius.circular(OriginTokens.cardRadius) : Radius.zero,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              allowSnapshotting: false,
                              builder: (_) => CustomAccountDetailPage(
                                account: hiddenAccounts[i],
                              ),
                            ),
                          );
                        },
                        onRestore: () => _restoreAccount(context, hiddenAccounts[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

class _HiddenAccountRow extends StatelessWidget {
  final db.Account account;
  final double balance;
  final String currencySymbol;
  final bool hideAmounts;
  final BorderRadius? borderRadius;
  final VoidCallback onTap;
  final VoidCallback onRestore;

  const _HiddenAccountRow({
    required this.account,
    required this.balance,
    required this.currencySymbol,
    required this.hideAmounts,
    this.borderRadius,
    required this.onTap,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                child: Opacity(
                  opacity: 0.6,
                  child: AccountTypeIcon(
                    type: account.type,
                    size: 20.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                            color: OriginTokens.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          l10n.accountHiddenTag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (account.note != null && account.note!.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      account.note!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              hideAmounts
                  ? '****'
                  : '${currencySymbol.isNotEmpty ? "$currencySymbol " : ""}${formatMoneyCompact(balance)}',
              style: TextStyle(
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
                color: OriginTokens.textTertiary(context),
              ),
            ),
            const SizedBox(width: 10.0),
            // 恢复按钮
            GestureDetector(
              onTap: onRestore,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  l10n.accountRestore,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
