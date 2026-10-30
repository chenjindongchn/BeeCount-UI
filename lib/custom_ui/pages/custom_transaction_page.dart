import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom_transaction_sheet.dart';
import '../styles/origin_sheet_tokens.dart';

/// OriginUI 定制记账全屏承载页面（用于无缝替代原生全屏 TransactionEditorPage）
/// 严格遵守极简接触面与零冲突原则：所有日历、账户、分类、标签等外部入口
/// 均通过 TransactionEditorPage 无缝分发至本页面，100% 保持上游业务文件零变动。
class CustomTransactionPage extends ConsumerWidget {
  const CustomTransactionPage({
    super.key,
    this.initialKind = 'expense',
    this.initialCategoryId,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialDate,
    this.initialTagIds,
    this.initialAmount,
    this.initialNote,
    this.editingTransactionId,
    this.isCopy = false,
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
  });

  final String initialKind;
  final int? initialCategoryId;
  final int? initialAccountId;
  final int? initialToAccountId;
  final DateTime? initialDate;
  final List<int>? initialTagIds;
  final double? initialAmount;
  final String? initialNote;
  final int? editingTransactionId;
  final bool isCopy;
  final bool excludeFromStats;
  final bool excludeFromBudget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = OriginSheetTokens.cardColor(context);

    return Scaffold(
      backgroundColor: cardBg,
      body: SafeArea(
        bottom: false,
        child: CustomTransactionSheet(
          initialKind: initialKind,
          initialCategoryId: initialCategoryId,
          initialAccountId: initialAccountId,
          initialToAccountId: initialToAccountId,
          initialDate: initialDate,
          initialTagIds: initialTagIds,
          initialAmount: initialAmount,
          initialNote: initialNote,
          editingTransactionId: editingTransactionId,
          isCopy: isCopy,
          excludeFromStats: excludeFromStats,
          excludeFromBudget: excludeFromBudget,
          showDragHandle: false,
          showTopBar: true,
          onClose: () => Navigator.maybePop(context),
        ),
      ),
    );
  }
}
