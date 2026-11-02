import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/attachment/attachment_preview_page.dart';
import '../../../pages/shared/resources/category_icon_adapter.dart';
import '../../../pages/shared/transactions/transaction_list_item.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../services/billing/post_processor.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/transaction_edit_utils.dart';
import '../pages/custom_category_detail_page.dart';
import '../pages/custom_tag_detail_page.dart';
import 'origin_dialog.dart';

/// vivo OriginOS 风格交易条目绑定组件 (CustomTransactionTileBinding)
///
/// 功能对齐原版 TransactionTileBinding，但将所有下钻页面（分类详情、标签详情）
/// 统一路由至定制的 CustomCategoryDetailPage 与 CustomTagDetailPage，
/// 确保全应用视觉语言与交互体验高度统一，同时绝不侵入修改原作者 lib/pages/ 代码。
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
    final t = row.t, transfer = row.t.type == 'transfer';
    final l = AppLocalizations.of(context);
    final name =
        CategoryUtils.getDisplayName(row.category?.name, context, kind: t.type);

    Future<void> open(Widget page) async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
      onReturned();
    }

    return TransactionListItem(
      icon: getCategoryIconData(category: row.category, categoryName: name),
      category: row.category,
      ledgerName: ledgerName,
      baseCurrencyCode: baseCurrency,
      alwaysShowCurrency: allLedgers,
      onDelete: onDelete,
      title: transfer && (t.note?.isEmpty ?? true)
          ? l.transferTitle
          : t.note ?? '',
      categoryName: transfer ? null : name,
      accountName: !accountsEnabled
          ? null
          : transfer
              ? [row.account?.name, row.toAccount?.name]
                  .whereType<String>()
                  .join(' → ')
              : row.account?.name,
      amount: t.amount,
      currencyCode: t.currencyCode,
      nativeAmount: t.nativeAmount,
      isExpense: t.type == 'expense',
      isTransfer: transfer,
      transferDirection: transferDirection,
      excludeFromStats: t.excludeFromStats,
      excludeFromBudget: t.excludeFromBudget,
      happenedAt: t.happenedAt,
      showFullDate: fullDate,
      tags: tags
          .map((tag) => (id: tag.id, name: tag.name, color: tag.color))
          .toList(),
      attachmentCount: attachmentCount,
      onAttachmentTap: () => open(
        AttachmentPreviewPage.fromTransaction(
          transactionId: t.id,
          allowDelete: false,
        ),
      ),
      onTagTap: (id, name) => open(
        CustomTagDetailPage(
          tagId: id,
          tagName: name,
          allLedgers: allLedgers,
        ),
      ),
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
      onLongPressStart: batch
          ? null
          : (details) async {
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
      onCategoryTap: !allowCategoryNavigation ||
              batch ||
              transfer ||
              row.category == null
          ? null
          : () => open(
                CustomCategoryDetailPage(
                  categoryId: row.category!.id,
                  categoryName: name,
                  allLedgers: allLedgers,
                ),
              ),
    );
  }
}
