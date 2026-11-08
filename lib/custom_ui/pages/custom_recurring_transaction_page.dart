import 'package:beecount_ui/beecount_ui.dart' hide OriginSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/shared/formatting/amount_text.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../pages/transaction/recurring/bindings/recurring_bill_controls.dart'
    show recurringFrequencyLabel;
import '../../providers.dart';
import '../../utils/category_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_empty_state.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_switch.dart';
import 'custom_recurring_transaction_edit_page.dart';

/// vivo OriginOS 风格周期账单列表页 (CustomRecurringTransactionPage)
class CustomRecurringTransactionPage extends ConsumerStatefulWidget {
  const CustomRecurringTransactionPage({super.key});

  @override
  ConsumerState<CustomRecurringTransactionPage> createState() =>
      _CustomRecurringTransactionPageState();
}

class _CustomRecurringTransactionPageState
    extends ConsumerState<CustomRecurringTransactionPage> {
  final _pendingIds = <int>{};

  Future<void> _openEditor([RecurringTransaction? recurring]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CustomRecurringTransactionEditPage(recurring: recurring),
      ),
    );
    if (mounted && changed == true) {
      ref.invalidate(allRecurringTransactionsProvider);
    }
  }

  Future<void> _toggle(RecurringTransaction recurring, bool enabled) async {
    if (_pendingIds.contains(recurring.id)) return;
    final repo = ref.read(repositoryProvider);
    setState(() => _pendingIds.add(recurring.id));
    try {
      await repo.toggleRecurringTransaction(recurring.id, enabled);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) ref.invalidate(allRecurringTransactionsProvider);
    } catch (error) {
      debugPrint('周期账单切换失败: $error');
      if (mounted) {
        showBeeToast(
          context,
          AppLocalizations.of(context).commonFailed,
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(recurring.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(allRecurringTransactionsProvider);
    final primaryColor = OriginTokens.primary(context);

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.recurringTransactionTitle,
        leading: BackButton(
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l.recurringTransactionAdd,
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${l.commonError}: $error'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    ref.invalidate(allRecurringTransactionsProvider),
                child: Text(l.v4RecordingRetry),
              ),
            ],
          ),
        ),
        data: (records) {
          if (records.isEmpty) {
            return OriginEmptyState(
              iconData: Icons.repeat_rounded,
              title: l.recurringTransactionEmpty,
              message: l.recurringTransactionEmptyHint,
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                onPressed: () => _openEditor(),
                child: Text(l.recurringTransactionAdd),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 12.0,
            ),
            itemCount: records.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                // 顶部使用说明卡片
                return OriginCard(
                  padding: const EdgeInsets.all(14.0),
                  color: primaryColor.withValues(alpha: 0.08),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.recurringTransactionUsageTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.recurringTransactionUsageContent,
                              style: TextStyle(
                                fontSize: 12,
                                color: OriginTokens.textSecondary(context),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final record = records[index - 1];
              final isBusy = _pendingIds.contains(record.id);

              return _RecurringBillTile(
                recurring: record,
                busy: isBusy,
                onTap: () => _openEditor(record),
                onToggle: (val) => _toggle(record, val),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecurringBillTile extends ConsumerWidget {
  final RecurringTransaction recurring;
  final bool busy;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  const _RecurringBillTile({
    required this.recurring,
    required this.busy,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final ledger =
        ref.watch(ledgerByIdProvider(recurring.ledgerId)).valueOrNull;
    final code = recurring.currencyCode;
    final foreign = code != null &&
        code.isNotEmpty &&
        code.toUpperCase() != (ledger?.currency.toUpperCase() ?? '');

    final amountColor = switch (recurring.type) {
      'expense' => Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFF5252)
          : const Color(0xFFD32F2F),
      'income' => Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF69F0AE)
          : const Color(0xFF2E7D32),
      _ => OriginTokens.textPrimary(context),
    };

    Widget renderContent(Category? category) {
      final title = recurring.type == 'transfer'
          ? l.transferTitle
          : category == null
              ? l.commonOther
              : CategoryUtils.getDisplayName(category.name, context);

      final icon = recurring.type == 'transfer'
          ? const Icon(Icons.swap_horiz_rounded, size: 22)
          : category == null
              ? const Icon(Icons.category_outlined, size: 22)
              : RecordingCategoryIcon(category: category, size: 22);

      return OriginCard(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 分类/转账图标
                SizedBox(width: 24, height: 24, child: Center(child: icon)),
                const SizedBox(width: 10),

                // 标题与账本/频次
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${ledger?.name ?? ''} · ${recurringFrequencyLabel(l, recurring)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // 开关
                OriginSwitch(
                  value: recurring.enabled,
                  enabled: !busy,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 金额与最后生成时间
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 备注或最后生成时间
                Expanded(
                  child: Text(
                    recurring.note?.isNotEmpty == true
                        ? recurring.note!
                        : (recurring.lastGeneratedDate != null
                            ? '${l.v4RecurringLastGeneratedLabel} ${DateFormat.Md().format(recurring.lastGeneratedDate!)}'
                            : ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: OriginTokens.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 金额
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (foreign) ...[
                      Text(
                        code.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: OriginTokens.textSecondary(context),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    AmountText(
                      value: recurring.type == 'expense'
                          ? -recurring.amount
                          : recurring.amount,
                      signed: recurring.type != 'transfer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (recurring.type == 'transfer' || recurring.categoryId == null) {
      return renderContent(null);
    }

    return FutureBuilder<Category?>(
      future: ref
          .watch(repositoryProvider)
          .getCategoryById(recurring.categoryId!),
      builder: (_, snapshot) => renderContent(snapshot.data),
    );
  }
}
