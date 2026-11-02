import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../pages/shared/selectors/category_selector_dialog.dart';
import '../../../pages/tag/widgets/tag_selector.dart';
import '../../../pages/transaction/search/bindings/transaction_batch.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../services/billing/post_processor.dart';
import '../../../utils/category_utils.dart';
import '../../../pages/transaction/search_page.dart';
import '../styles/origin_tokens.dart';
import '../widgets/custom_search_results.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_search_filter_sheet.dart';
import '../widgets/origin_search_bar.dart';

export '../../../pages/transaction/search/bindings/transaction_search.dart'
    show SearchTransaction;

/// vivo OriginOS 风格自定义交易搜索页面 (CustomSearchPage)
///
/// 遵循蓝河工具箱与 vivo 视觉规范：
/// 1. 【顶栏体系】
///    - 普通搜索态：返回键 + 32dp OriginSearchBar 胶囊搜索条（带取消/清空交互状态机） + 筛选入口；
///    - 批量模式态：平滑切换为 OriginSmallTopAppBar，突出展示已选笔数与退出批量按钮；
/// 2. 【过滤胶囊】OriginFilterChip 动态横向排布，支持单项点击小叉即时撤销过滤；
/// 3. 【搜索结果】CustomSearchResults 卡片化自然日分组，双环加载，精致空状态；
/// 4. 【批量操作】OriginBatchActionBar 纯净吸底栏，配合 OriginDialog 弹窗体系与触觉反馈；
/// 5. 【原则遵循】100% 隔离于 custom_ui，零侵入 lib/pages/，零阻碍上游更新。
class CustomSearchPage extends SearchPage {
  const CustomSearchPage({
    super.key,
    super.initialBatchMode = false,
    super.initialFilter = const TransactionSearchFilter(),
    super.initialOpenFilter = false,
  });

  @override
  ConsumerState<CustomSearchPage> createState() => _CustomSearchPageState();
}

class _CustomSearchPageState extends ConsumerState<CustomSearchPage> {
  final _text = TextEditingController();
  final _focusNode = FocusNode();
  TransactionSearchController? _data;
  bool _writing = false, _openedFilter = false;

  @override
  void dispose() {
    _text.dispose();
    _focusNode.dispose();
    _data?.dispose();
    super.dispose();
  }

  void _ensureData(int ledgerId, AppLocalizations l) {
    if (_data?.ledgerId == ledgerId) return;
    _data?.dispose();
    _text.clear();
    _data = TransactionSearchController(
      repository: ref.read(repositoryProvider),
      ledgerId: ledgerId,
      initialBatch: widget.initialBatchMode,
      categoryLabel: (c) =>
          CategoryUtils.displayName(c?.name, l, kind: c?.kind ?? 'expense'),
    );
    _data!.filter = widget.initialFilter;
    unawaited(_data!.start());
    if (widget.initialOpenFilter && !_openedFilter) {
      _openedFilter = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _filters();
      });
    }
  }

  Future<void> _filters() async {
    if (_writing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final c = _data!;
    final filter = await OriginSearchFilterSheet.show(
      context,
      initial: c.filter,
      accounts: c.accounts,
      tags: c.availableTags,
      ledgerId: c.ledgerId,
      currency:
          ref.read(currentLedgerProvider).valueOrNull?.currency ?? 'CNY',
    );
    if (mounted && identical(_data, c) && filter != null) {
      c.applyFilter(filter);
    }
  }

  Future<void> _write(
    Future<int> Function() action,
    String Function(int) success,
    String Function(String) failure,
  ) async {
    final c = _data!;
    if (_writing ||
        c.selected.isEmpty ||
        ref.read(currentLedgerIdProvider) != c.ledgerId) {
      return;
    }
    setState(() => _writing = true);
    try {
      final count = await action();
      if (!mounted) return;
      ref.invalidate(countsForLedgerProvider(c.ledgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      ref.read(tagListRefreshProvider.notifier).state++;
      PostProcessor.sync(ref, ledgerId: c.ledgerId);
      if (mounted && identical(_data, c)) {
        c.afterWrite();
        await c.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success(count)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure(e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: OriginTokens.expenseRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  Future<void> _note() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    final note = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: OriginTokens.dialogScrim(context),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim, secondaryAnim) =>
          _OriginBatchNoteDialog(count: ids.length),
    );
    if (!mounted || !identical(c, _data) || note == null) return;
    await _write(
      () => TransactionBatchBinding(ref.read(repositoryProvider)).replaceNotes(
        ledgerId: c.ledgerId,
        transactionIds: ids,
        note: note,
      ),
      l.searchBatchSetNoteSuccess,
      l.searchBatchSetNoteFailed,
    );
  }

  Future<void> _category() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final kinds = c.results
        .where((r) => ids.contains(r.t.id))
        .map((r) => r.t.type)
        .toSet();
    if (kinds.contains('transfer') || kinds.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kinds.contains('transfer')
                ? l.searchBatchCategoryTransferError
                : l.searchBatchCategoryTypeError,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final category = await showCategorySelector(
      context,
      type: kinds.single,
      includeParentCategories: false,
      showTransactionCount: true,
      ledgerId: c.ledgerId,
    );
    if (!mounted || !identical(c, _data) || category == null) return;
    await _write(
      () =>
          TransactionBatchBinding(ref.read(repositoryProvider)).changeCategory(
        ledgerId: c.ledgerId,
        transactionIds: ids,
        category: category,
      ),
      l.searchBatchChangeCategorySuccess,
      l.searchBatchChangeCategoryFailed,
    );
  }

  Future<void> _tags() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final initial = ids.isEmpty
        ? <int>{}
        : (c.tags[ids.first] ?? []).map((t) => t.id).toSet();
    for (final id in ids.skip(1)) {
      initial.retainAll((c.tags[id] ?? []).map((t) => t.id));
    }
    final tags =
        await TagSelector.show(context, selectedTagIds: initial.toList());
    if (!mounted || !identical(c, _data) || tags == null) return;
    await _write(
      () => TransactionBatchBinding(ref.read(repositoryProvider)).replaceTags(
        ledgerId: c.ledgerId,
        transactionIds: ids,
        tagIds: tags,
      ),
      (_) => l.v4SearchTagsSaved,
      (error) => '${l.commonError}: $error',
    );
  }

  Future<void> _delete() async {
    final c = _data!,
        ids = _data!.selected.toList(),
        l = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l.searchBatchDeleteConfirmTitle,
      message: l.searchBatchDeleteConfirmMessage(ids.length),
      confirmText: l.commonDelete,
      cancelText: l.commonCancel,
      isDanger: true,
    );
    if (!mounted || !identical(c, _data) || confirmed != true) return;
    await _write(() async {
      final repo = ref.read(repositoryProvider);
      for (final id in ids) {
        if ((await repo.getTransactionById(id))?.ledgerId != c.ledgerId) {
          throw StateError('Batch scope changed');
        }
      }
      for (final id in ids) {
        await repo.deleteTransaction(id);
      }
      return ids.length;
    }, l.searchBatchDeleteSuccess, l.searchBatchDeleteFailed);
  }

  List<Widget> _filterChips(TransactionSearchController c, AppLocalizations l) {
    final f = c.filter;
    final labels = <String, String>{
      if (f.category != null)
        'category': CategoryUtils.displayName(f.category!.name, l,
            kind: f.category!.kind),
      if (f.accountId != null)
        'account':
            c.accounts.where((a) => a.id == f.accountId).firstOrNull?.name ??
                l.exportCsvHeaderAccount,
      if (f.tagId != null)
        'tag':
            c.availableTags.where((t) => t.id == f.tagId).firstOrNull?.name ??
                l.exportCsvHeaderTags,
      if (f.kind != null)
        'kind': f.kind == 'income'
            ? l.exportTypeIncome
            : f.kind == 'expense'
                ? l.exportTypeExpense
                : l.transferTitle,
      if (f.minimum != null || f.maximum != null)
        'amount':
            '${f.basis == SearchAmountBasis.original ? l.v4SearchOriginalAmount : l.v4SearchLedgerAmount}: ${f.minimum ?? 0} — ${f.maximum ?? '∞'}',
      if (f.start != null || f.end != null) 'date': l.searchDateFilter,
    };

    return labels.entries
        .map(
          (e) => OriginFilterChip(
            label: e.value,
            selected: true,
            onDeleted: _writing
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    c.applyFilter(
                      TransactionSearchFilter(
                        category: e.key == 'category' ? null : f.category,
                        accountId: e.key == 'account' ? null : f.accountId,
                        tagId: e.key == 'tag' ? null : f.tagId,
                        kind: e.key == 'kind' ? null : f.kind,
                        basis: f.basis,
                        minimum: e.key == 'amount' ? null : f.minimum,
                        maximum: e.key == 'amount' ? null : f.maximum,
                        start: e.key == 'date' ? null : f.start,
                        end: e.key == 'date' ? null : f.end,
                      ),
                    );
                  },
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        ledgerId = ref.watch(currentLedgerIdProvider);
    ref.watch(hideAmountsProvider);
    _ensureData(ledgerId, l);
    final c = _data!;

    final hasActiveFilter = c.filter.category != null ||
        c.filter.accountId != null ||
        c.filter.tagId != null ||
        c.filter.kind != null ||
        c.filter.minimum != null ||
        c.filter.maximum != null ||
        c.filter.start != null ||
        c.filter.end != null;

    final chips = _filterChips(c, l);

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) => PopScope(
        canPop: !_writing,
        child: OriginScaffold(
          backgroundColor: OriginTokens.pageBackground(context),
          appBar: c.batch
              ? OriginSmallTopAppBar(
                  title: c.selected.isEmpty
                      ? l.searchBatchMode
                      : l.v4SearchSelected(c.selected.length),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18.0),
                    onPressed: _writing
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            if (!widget.initialBatchMode) {
                              c.toggleBatch();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                  ),
                  actions: [
                    TextButton(
                      onPressed: _writing || c.results.isEmpty
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              c.selectAll();
                            },
                      child: Text(
                        c.selected.length == c.results.length &&
                                c.results.isNotEmpty
                            ? l.searchDeselectAll
                            : l.searchSelectAll,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: c.results.isEmpty
                              ? OriginTokens.textTertiary(context)
                              : OriginTokens.primary(context),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
          bottomNavigationBar: !c.batch
              ? null
              : _OriginBatchBottomBar(
                  busy: _writing,
                  hasSelection: c.selected.isNotEmpty,
                  onNote: _note,
                  onCategory: _category,
                  onTags: _tags,
                  onDelete: _delete,
                ),
          body: Column(
            children: [
              if (!c.batch) ...[
                // OriginOS 官方一体化搜索顶栏（状态栏留白 + 返回按钮 + 32dp 胶囊搜索框 + 筛选入口）
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 6.0, 16.0, 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18.0,
                          ),
                          color: OriginTokens.textPrimary(context),
                          onPressed: _writing
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36.0,
                            minHeight: 36.0,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Expanded(
                          child: OriginSearchBar(
                            controller: _text,
                            focusNode: _focusNode,
                            hintText: l.v4SearchHint,
                            enabled: !_writing,
                            showCancelWhenFocused: true,
                            onChanged: c.search,
                            onSubmitted: (_) => c.remember(),
                            onCancel: () {
                              _text.clear();
                              c.search('');
                            },
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        // 右上角设置/筛选入口（vivo OriginOS 官方规范“2个点”图标，附带筛选激活小徽标）
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              color: hasActiveFilter
                                  ? OriginTokens.chipSelectedBackground(context)
                                  : OriginTokens.chipBackground(context),
                              borderRadius: BorderRadius.circular(16.0),
                              child: InkWell(
                                onTap: _writing
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        _filters();
                                      },
                                borderRadius: BorderRadius.circular(16.0),
                                child: Container(
                                  width: 32.0,
                                  height: 32.0,
                                  alignment: Alignment.center,
                                  child: OriginMoreIcon(
                                    size: 18.0,
                                    color: hasActiveFilter
                                        ? OriginTokens.primary(context)
                                        : OriginTokens.textPrimary(context),
                                  ),
                                ),
                              ),
                            ),
                            if (hasActiveFilter)
                              Positioned(
                                top: -1.0,
                                right: -1.0,
                                child: Container(
                                  width: 7.0,
                                  height: 7.0,
                                  decoration: BoxDecoration(
                                    color: OriginTokens.primary(context),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: OriginTokens.cardBackground(
                                          context),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 筛选胶囊栏（如果有筛选条件或可展开时平滑呈现）
                if (chips.isNotEmpty)
                  Container(
                    height: 38.0,
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: OriginTokens.cardMargin,
                      ),
                      children: [
                        OriginFilterChip(
                          label: l.searchFilterTitle,
                          leading: const Icon(Icons.tune_rounded, size: 13.0),
                          onTap: _writing ? null : _filters,
                        ),
                        for (final chip in chips) ...[
                          const SizedBox(width: 8.0),
                          chip,
                        ],
                      ],
                    ),
                  ),
              ],
              Expanded(
                child: CustomSearchResults(
                  data: c,
                  writing: _writing,
                  onScope: _filters,
                  onQuery: (query) {
                    _text.text = query;
                    c.search(query);
                  },
                  onRetry: () => setState(() {
                    c.dispose();
                    _data = null;
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格吸底批量操作底栏
class _OriginBatchBottomBar extends StatelessWidget {
  final bool busy;
  final bool hasSelection;
  final VoidCallback onNote;
  final VoidCallback onCategory;
  final VoidCallback onTags;
  final VoidCallback onDelete;

  const _OriginBatchBottomBar({
    required this.busy,
    required this.hasSelection,
    required this.onNote,
    required this.onCategory,
    required this.onTags,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      (l.searchBatchSetNote, Icons.edit_note_rounded, onNote, false),
      (l.searchBatchChangeCategory, Icons.category_rounded, onCategory, false),
      (l.v4SearchSetTags, Icons.local_offer_rounded, onTags, false),
      (l.commonDelete, Icons.delete_outline_rounded, onDelete, true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: OriginTokens.cardBackground(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            offset: const Offset(0, -2),
            blurRadius: 8.0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OriginDivider(startIndent: 0),
            SizedBox(
              height: OriginTokens.bottomBarHeight,
              child: Row(
                children: items.map((item) {
                  final label = item.$1;
                  final icon = item.$2;
                  final action = item.$3;
                  final isDanger = item.$4;

                  final enabled = hasSelection && !busy;
                  final color = !enabled
                      ? OriginTokens.textTertiary(context).withValues(alpha: 0.5)
                      : isDanger
                          ? OriginTokens.expenseRed
                          : OriginTokens.textPrimary(context);

                  return Expanded(
                    child: InkWell(
                      onTap: enabled
                          ? () {
                              HapticFeedback.lightImpact();
                              action();
                            }
                          : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 24.0, color: color),
                          const SizedBox(height: 2.0),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10.0,
                              color: color,
                              fontWeight: isDanger && enabled
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格批量修改备注弹窗
class _OriginBatchNoteDialog extends StatefulWidget {
  const _OriginBatchNoteDialog({required this.count});
  final int count;

  @override
  State<_OriginBatchNoteDialog> createState() => _OriginBatchNoteState();
}

class _OriginBatchNoteState extends State<_OriginBatchNoteDialog> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return OriginDialog(
      title: l.searchBatchSetNoteTitle,
      message: l.searchBatchSetNoteMessage(widget.count),
      content: Container(
        decoration: BoxDecoration(
          color: OriginTokens.searchBarBackground(context),
          borderRadius: BorderRadius.circular(OriginTokens.cardRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: TextField(
          controller: _textController,
          maxLines: 3,
          autofocus: true,
          style: TextStyle(
            fontSize: 14.0,
            color: OriginTokens.textPrimary(context),
          ),
          decoration: InputDecoration(
            hintText: l.searchBatchSetNoteHint,
            hintStyle: TextStyle(
              fontSize: 14.0,
              color: OriginTokens.searchBarHint(context),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
      confirmText: l.commonConfirm,
      cancelText: l.commonCancel,
      onConfirm: () => Navigator.pop(context, _textController.text),
      onCancel: () => Navigator.pop(context),
    );
  }
}
