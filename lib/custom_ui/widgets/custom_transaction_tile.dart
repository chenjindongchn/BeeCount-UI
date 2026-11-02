import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../services/billing/post_processor.dart';
import '../../../utils/transaction_edit_utils.dart';
import 'origin_dialog.dart';
import 'origin_transaction_item.dart';

/// vivo OriginOS 风格交易条目绑定组件 (CustomTransactionTileBinding)
///
/// 封装通用业务数据（SearchTransaction、标签、附件、批量选择与删除操作），
/// 底层统一由 OriginTransactionItem 进行视觉渲染，
/// 确保全应用所有流水列表（资产、分类、标签、搜索）与首页明细页面的
/// 支出名称、备注、金额与银行卡显示逻辑 100% 保持一致。
class CustomTransactionTileBinding extends ConsumerWidget {
  const CustomTransactionTileBinding({
    super.key,
    required this.row,
    required this.tags,
    required this.attachmentCount,
    this.batch = false,
    this.selected = false,
    this.onSelect,
    this.fullDate = false,
    this.allLedgers = false,
    this.ledgerName,
    this.baseCurrency,
    this.transferDirection,
    this.onDelete,
    this.allowCategoryNavigation = true,
    this.accountsEnabled = true,
    required this.onReturned,
  });

  final SearchTransaction row;
  final List<Tag> tags;
  final int attachmentCount;
  final bool batch,
      selected,
      accountsEnabled,
      fullDate,
      allLedgers,
      allowCategoryNavigation;
  final String? ledgerName, baseCurrency;
  final int? transferDirection;
  final Future<void> Function()? onDelete;
  final VoidCallback? onSelect;
  final VoidCallback onReturned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = row.t;

    return OriginTransactionItem(
      transaction: t,
      category: row.category,
      account: accountsEnabled ? row.account : null,
      toAccount: accountsEnabled ? row.toAccount : null,
      tags: tags,
      transferDirection: transferDirection,
      isSelectionMode: batch,
      isSelected: selected,
      onSelectionChanged: onSelect,
      onTap: batch
          ? null
          : () async {
              await TransactionEditUtils.editTransaction(
                context,
                ref,
                t,
                row.category,
              );
              onReturned();
            },
      onLongPress: batch
          ? null
          : () async {
              final confirmed = await showOriginConfirmDialog(
                context,
                title: '确定要删除该条账单吗？删除后不可恢复',
                confirmText: '确定',
                cancelText: '取消',
                isDanger: true,
              );
              if (confirmed == true && context.mounted) {
                if (onDelete != null) {
                  await onDelete!();
                } else {
                  try {
                    final repo = ref.read(repositoryProvider);
                    await repo.deleteTransaction(t.id);
                    final curLedger = ref.read(currentLedgerIdProvider);
                    ref.invalidate(countsForLedgerProvider(curLedger));
                    ref.read(statsRefreshProvider.notifier).state++;
                    ref.read(budgetRefreshProvider.notifier).state++;
                    PostProcessor.sync(ref, ledgerId: curLedger);
                    if (context.mounted) {
                      showBeeToast(context, '删除成功');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      showBeeToast(context, '删除失败: $e', tone: BeeTone.error);
                    }
                  }
                }
                onReturned();
              }
            },
    );
  }
}
