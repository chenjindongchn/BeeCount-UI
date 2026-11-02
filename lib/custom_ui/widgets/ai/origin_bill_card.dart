import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../ai/core/bill_info.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../utils/format_utils.dart';
import '../../styles/origin_tokens.dart';
import '../origin_divider.dart';

/// vivo OriginOS 风格记账结果卡片 (OriginBillCard)
///
/// 遵循蓝河/OriginUI 规范：
/// 1. 14dp 圆角纯白卡片，带有 0.5dp 发丝边框；
/// 2. 分类圆形图标 + 大金额强调排版；
/// 3. 支持转账账户双向指示（from → to）与标签微胶囊展示；
/// 4. 底部配置 30dp 高度的紧凑操作胶囊（撤销、编辑、换账本）；
/// 5. 已撤销状态下自动呈现删除线与优雅置灰。
class OriginBillCard extends ConsumerWidget {
  final BillInfo billInfo;
  final int? transactionId;
  final VoidCallback? onUndo;
  final VoidCallback? onEdit;
  final VoidCallback? onChangeLedger;
  final bool isUndone;

  const OriginBillCard({
    super.key,
    required this.billInfo,
    this.transactionId,
    this.onUndo,
    this.onEdit,
    this.onChangeLedger,
    this.isUndone = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // 获取账本信息
    final ledger = billInfo.ledgerId != null
        ? ref.watch(ledgerByIdProvider(billInfo.ledgerId!)).asData?.value
        : null;
    final ledgerName = ledger?.name != null
        ? translateLedgerName(context, ledger!.name)
        : l10n.billCardUnknownLedger;
    final currency = (billInfo.currency?.trim().isNotEmpty ?? false)
        ? billInfo.currency!.trim().toUpperCase()
        : ledger?.currency ?? 'CNY';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE8E8EC);

    // 金额与色彩
    final rawAmount = billInfo.amount?.abs() ?? 0;
    final isIncome = billInfo.type == BillType.income;
    final isTransfer = billInfo.type == BillType.transfer;
    final amountSign = isTransfer ? '' : (isIncome ? '+' : '-');
    final amountColor = isUndone
        ? OriginTokens.textTertiary(context)
        : (isTransfer
            ? OriginTokens.textPrimary(context)
            : (isIncome ? OriginTokens.incomeGreen : OriginTokens.expenseRed));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: borderColor, width: OriginTokens.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            offset: const Offset(0, 2),
            blurRadius: 8.0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部条：账本标签与状态指示
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 14.0, 8.0),
              child: Row(
                children: [
                  // 账本微胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.book_rounded,
                          size: 11.0,
                          color: OriginTokens.textSecondary(context),
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          ledgerName,
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 状态小标
                  if (isUndone)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF3F3F4),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        l10n.billCardUndone,
                        style: TextStyle(
                          fontSize: 11.0,
                          color: OriginTokens.textTertiary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 13.0,
                          color: Color(0xFF2EA44F),
                        ),
                        const SizedBox(width: 3.0),
                        Text(
                          l10n.billCardSuccess,
                          style: const TextStyle(
                            fontSize: 11.0,
                            color: Color(0xFF2EA44F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // 主体信息行：分类图标、名称、账户、大金额
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 分类圆形图标
                  _buildCategoryAvatar(context, isDark),
                  const SizedBox(width: 12.0),
                  // 分类与账户
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          billInfo.category ?? l10n.commonOther,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w600,
                            color: isUndone
                                ? OriginTokens.textTertiary(context)
                                : OriginTokens.textPrimary(context),
                            decoration: isUndone ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          _buildAccountAndTimeString(context, l10n),
                          style: TextStyle(
                            fontSize: 12.0,
                            color: OriginTokens.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (billInfo.note != null && billInfo.note!.isNotEmpty) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            billInfo.note!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: OriginTokens.textSecondary(context).withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // 金额大字号
                  Text(
                    '$amountSign${formatBalanceFull(rawAmount, currency)}',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: amountColor,
                      decoration: isUndone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),

            // 标签列表（若存在）
            if (_tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14.0, 0.0, 14.0, 10.0),
                child: Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: _tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF5F6F9),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // 底部操作区（未撤销时提供 30dp 胶囊按钮）
            if (!isUndone && (onUndo != null || onEdit != null || onChangeLedger != null)) ...[
              const OriginDivider(startIndent: 0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onChangeLedger != null)
                      _buildActionPill(
                        context,
                        label: '换账本',
                        icon: Icons.swap_horiz_rounded,
                        onTap: onChangeLedger!,
                      ),
                    if (onEdit != null) ...[
                      const SizedBox(width: 8.0),
                      _buildActionPill(
                        context,
                        label: l10n.billCardEdit,
                        icon: Icons.edit_outlined,
                        onTap: onEdit!,
                      ),
                    ],
                    if (onUndo != null) ...[
                      const SizedBox(width: 8.0),
                      _buildActionPill(
                        context,
                        label: l10n.billCardUndo,
                        icon: Icons.undo_rounded,
                        isDestructive: true,
                        onTap: onUndo!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAvatar(BuildContext context, bool isDark) {
    final isIncome = billInfo.type == BillType.income;
    final isTransfer = billInfo.type == BillType.transfer;
    final themeColor = isTransfer
        ? const Color(0xFF4A90E2)
        : (isIncome ? OriginTokens.incomeGreen : const Color(0xFFFF6B6B));

    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: isUndone
            ? (isDark ? Colors.white10 : const Color(0xFFECECEC))
            : themeColor.withValues(alpha: isDark ? 0.2 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isTransfer
              ? Icons.swap_horiz_rounded
              : (isIncome ? Icons.arrow_downward_rounded : Icons.shopping_bag_outlined),
          size: 20.0,
          color: isUndone ? OriginTokens.textTertiary(context) : themeColor,
        ),
      ),
    );
  }

  String _buildAccountAndTimeString(BuildContext context, AppLocalizations l10n) {
    final buffer = StringBuffer();
    if (billInfo.type == BillType.transfer) {
      final from = billInfo.fromAccount?.trim();
      final to = billInfo.toAccount?.trim();
      if (from != null && from.isNotEmpty && to != null && to.isNotEmpty) {
        buffer.write('$from → $to');
      } else if (from != null && from.isNotEmpty) {
        buffer.write(from);
      }
    } else {
      final acc = billInfo.account?.trim();
      if (acc != null && acc.isNotEmpty) {
        buffer.write(acc);
      }
    }

    if (billInfo.time != null) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      buffer.write(DateFormat('MM-dd HH:mm').format(billInfo.time!));
    }

    return buffer.isEmpty ? l10n.billCardSuccess : buffer.toString();
  }

  Widget _buildActionPill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDestructive
        ? OriginTokens.expenseRed
        : OriginTokens.textPrimary(context);
    final bgColor = isDark
        ? (isDestructive ? OriginTokens.expenseRed.withValues(alpha: 0.15) : Colors.white12)
        : (isDestructive ? const Color(0xFFFFF0F0) : const Color(0xFFF2F3F6));

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(OriginTokens.smallButtonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(OriginTokens.smallButtonRadius),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: OriginTokens.smallButtonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.0, color: textColor),
              const SizedBox(width: 4.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> get _tags {
    final uniqueTags = <String>{};
    for (final tag in billInfo.tags ?? const <String>[]) {
      final normalized = tag.trim();
      if (normalized.isNotEmpty) uniqueTags.add(normalized);
    }
    return uniqueTags.toList();
  }
}
