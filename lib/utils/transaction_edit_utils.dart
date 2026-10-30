import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import '../data/repositories/local/local_repository.dart';
import '../providers/database_providers.dart';
import '../l10n/app_localizations.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'shared_ledger_picker_filter.dart' show syntheticIdForSyncId;
import '../custom_ui/pages/custom_transaction_sheet.dart';

class TransactionEditUtils {
  static Future<void> copyTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) =>
      _openTransaction(context, ref, transaction, asCopy: true);

  static Future<void> editTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
    Category? category,
  ) async {
    await _openTransaction(context, ref, transaction, asCopy: false);
  }

  static Future<void> _openTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction, {
    required bool asCopy,
  }) async {
    // 获取交易关联的标签ID(主表 + §7 override 表)
    final repo = ref.read(repositoryProvider);
    final source =
        asCopy ? await repo.getTransactionById(transaction.id) : transaction;
    transaction = source ?? transaction;
    final ledger = await repo.getLedgerById(transaction.ledgerId);
    if (!context.mounted) return;
    if (asCopy &&
        (source == null ||
            ledger == null ||
            !const {'expense', 'income', 'transfer'}
                .contains(transaction.type) ||
            (ledger.isShared &&
                !const {'owner', 'editor'}.contains(ledger.myRole)))) {
      showBeeToast(
          context, AppLocalizations.of(context).transactionCopyUnavailable);
      return;
    }
    // Use the latest source after an asynchronous menu selection.
    if (asCopy) {
      final category = transaction.categoryId == null
          ? null
          : await repo.getCategoryById(transaction.categoryId!);
      final account = transaction.accountId == null
          ? null
          : await repo.getAccount(transaction.accountId!);
      final toAccount = transaction.toAccountId == null
          ? null
          : await repo.getAccount(transaction.toAccountId!);
      if (!context.mounted) return;
      if ((transaction.categoryId != null && category == null) ||
          (transaction.accountId != null && account == null) ||
          (transaction.toAccountId != null && toAccount == null)) {
        showBeeToast(
            context, AppLocalizations.of(context).transactionCopyUnavailable);
        return;
      }
    }
    final tags = await repo.getTagsForTransaction(transaction.id);
    final tagIds = <int>[for (final t in tags) t.id];

    // §7 共享账本:加 TransactionTagOverrides → synthetic id 加进列表,
    // picker 显示选中
    if (repo is LocalRepository && transaction.syncId != null) {
      final overrides = await (repo.db.select(repo.db.transactionTagOverrides)
            ..where((t) => t.transactionSyncId.equals(transaction.syncId!)))
          .get();
      for (final ov in overrides) {
        final synthetic = syntheticIdForSyncId(ov.tagSyncId);
        if (!tagIds.contains(synthetic)) tagIds.add(synthetic);
      }
      if (asCopy && ledger != null) {
        final categories = await (repo.db.select(repo.db.sharedLedgerCategories)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        final accounts = await (repo.db.select(repo.db.sharedLedgerAccounts)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        final tags = await (repo.db.select(repo.db.sharedLedgerTags)
              ..where((t) => t.ledgerSyncId.equals(ledger.syncId ?? '')))
            .get();
        bool missing(String? syncId, Iterable<String> available) =>
            syncId != null && !available.contains(syncId);
        final invalid = missing(transaction.categorySyncIdOverride,
                categories.map((c) => c.syncId)) ||
            missing(transaction.accountSyncIdOverride,
                accounts.map((a) => a.syncId)) ||
            missing(transaction.toAccountSyncIdOverride,
                accounts.map((a) => a.syncId)) ||
            overrides
                .any((ov) => !tags.any((tag) => tag.syncId == ov.tagSyncId));
        if (!context.mounted) return;
        if (invalid) {
          showBeeToast(
              context, AppLocalizations.of(context).transactionCopyUnavailable);
          return;
        }
      }
    }

    // §7 v25 共享账本:Editor 视角下记的 tx,categoryId/accountId 为 null,
    // 真实引用在 *SyncIdOverride。编辑时用 syntheticIdForSyncId 转成 picker
    // 列表里的 synthetic id,让 editor 反查时能命中"已选"。
    final int? initialCategoryId = transaction.categorySyncIdOverride != null
        ? syntheticIdForSyncId(transaction.categorySyncIdOverride!)
        : transaction.categoryId;
    final int? initialAccountId = transaction.accountSyncIdOverride != null
        ? syntheticIdForSyncId(transaction.accountSyncIdOverride!)
        : transaction.accountId;
    final int? initialToAccountId = transaction.toAccountSyncIdOverride != null
        ? syntheticIdForSyncId(transaction.toAccountSyncIdOverride!)
        : transaction.toAccountId;

    if (!context.mounted) return;
    // The copy entry belongs to the current homepage ledger. Recheck after
    // loading references so an asynchronously changed selection cannot redirect
    // this new transaction to another ledger.
    if (asCopy && ref.read(currentLedgerIdProvider) != transaction.ledgerId) {
      showBeeToast(
          context, AppLocalizations.of(context).transactionCopyUnavailable);
      return;
    }

    // 统一使用从底部升上来的全新 OriginUI 记账抽屉界面
    await showCustomTransactionSheet(
      context,
      initialKind: transaction.type,
      initialCategoryId: initialCategoryId,
      initialAmount: transaction.amount,
      initialDate: asCopy ? DateTime.now() : transaction.happenedAt,
      initialNote: transaction.note,
      editingTransactionId: asCopy ? null : transaction.id,
      initialAccountId: initialAccountId,
      initialToAccountId: initialToAccountId,
      initialTagIds: tagIds,
      excludeFromStats: transaction.excludeFromStats,
      excludeFromBudget: transaction.excludeFromBudget,
      isCopy: asCopy,
    );
  }
}
