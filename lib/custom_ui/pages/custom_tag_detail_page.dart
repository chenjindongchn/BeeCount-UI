import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/tag/detail/bindings/tag_detail.dart';
import '../../pages/tag/detail/widgets/tag_detail_sections.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../utils/month_range.dart';
import '../widgets/origin_date_picker.dart';
import 'custom_category_detail_page.dart';
import '../../pages/transaction/transaction_editor_page.dart';
import '../../pages/tag/tag_edit_page.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_segmented_control.dart';

/// vivo OriginOS 风格自定义标签详情页面 (CustomTagDetailPage)
///
/// 核心特性：
/// 1. 右上角采用统一的 2 个点入口 (OriginMoreButton)，点击呼出高质感展开式气泡菜单；
/// 2. 气泡菜单集成：编辑标签、删除标签；
/// 3. 复用已有标签数据查询与统计，与上游 upstream 保持零冲突。
class CustomTagDetailPage extends ConsumerStatefulWidget {
  const CustomTagDetailPage({
    super.key,
    required this.tagId,
    required this.tagName,
    this.allLedgers = false,
  });

  final int tagId;
  final String tagName;
  final bool allLedgers;

  @override
  ConsumerState<CustomTagDetailPage> createState() => _CustomTagDetailPageState();
}

class _CustomTagDetailPageState extends ConsumerState<CustomTagDetailPage> {
  TagDetailPeriod _period = TagDetailPeriod.all;
  DateTime? _anchor;
  bool _deleting = false;
  late TagDetailScope _scope;

  void _refresh() {
    ref.invalidate(tagDetailStatsProvider);
    ref.invalidate(tagDetailRowsProvider);
    ref.invalidate(tagDetailTagProvider(widget.tagId));
  }

  Future<void> _date(DateTime initial) async {
    final date = await showOriginDatePicker(
      context,
      initial: initial,
      mode: _period == TagDetailPeriod.month
          ? OriginDatePickerMode.ym
          : OriginDatePickerMode.y,
      maxDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _anchor = DateTime(
          date.year, _period == TagDetailPeriod.year ? 1 : date.month));
    }
  }

  Future<void> _edit(db.Tag tag) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => TagEditPage(tag: tag)),
    );
    if (mounted) _refresh();
  }

  Future<void> _deleteTag(db.Tag tag) async {
    if (_deleting) return;
    final l = AppLocalizations.of(context);
    final confirmed = await showBeeConfirm(
      context,
      title: l.tagDeleteConfirmTitle,
      message: l.tagDeleteConfirmMessage(tag.name),
      confirmLabel: l.commonDelete,
      cancelLabel: l.commonCancel,
      danger: true,
    );
    if (!confirmed || !mounted || _deleting) return;
    setState(() => _deleting = true);
    try {
      await ref.read(repositoryProvider).deleteTag(tag.id);
      ref.read(tagListRefreshProvider.notifier).state++;
      if (mounted) {
        showBeeToast(context, l.tagDeleteSuccess, tone: BeeTone.success);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    }
  }

  Future<void> _deleteTransaction(int id, int sourceLedgerId) async {
    final l = AppLocalizations.of(context);
    try {
      final repo = ref.read(repositoryProvider),
          transaction =
              await ref.read(repositoryProvider).getTransactionById(id);
      if (transaction == null || transaction.ledgerId != sourceLedgerId) {
        throw StateError('Transaction scope changed');
      }
      await repo.deleteTransaction(id);
      await PostProcessor.sync(ref, ledgerId: sourceLedgerId);
      ref.invalidate(countsForLedgerProvider(sourceLedgerId));
      ref.read(statsRefreshProvider.notifier).state++;
      ref.read(budgetRefreshProvider.notifier).state++;
      ref.read(tagListRefreshProvider.notifier).state++;
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        startDay = ref.watch(currentMonthStartDayProvider);
    final anchor = _anchor ?? labelForDate(DateTime.now(), startDay);
    final range = tagDetailRange(_period, startDay, anchor);
    _scope = (
      tagId: widget.tagId,
      ledgerId: widget.allLedgers ? null : ref.watch(currentLedgerIdProvider),
      start: range?.start,
      end: range?.end
    );
    final tag = ref.watch(tagDetailTagProvider(widget.tagId));
    final transactions = ref.watch(tagDetailTransactionsProvider(_scope));
    final rows = transactions.valueOrNull;
    final AsyncValue<TagDetailRows> data = rows == null
        ? transactions.hasError
            ? AsyncError(transactions.error!,
                transactions.stackTrace ?? StackTrace.current)
            : const AsyncLoading()
        : ref.watch(tagDetailRowsProvider(rows));
    final stats = ref.watch(tagDetailStatsProvider(_scope));
    void retry() {
      _refresh();
      ref.invalidate(tagDetailTransactionsProvider(_scope));
    }

    final hasTag = tag.valueOrNull != null;

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: tag.valueOrNull?.name ?? widget.tagName,
        leading: const BackButton(),
        actions: [
          if (hasTag)
            OriginMoreButton(
              items: [
                OriginMenuItem(
                  title: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => _edit(tag.valueOrNull!),
                ),
                OriginMenuItem(
                  title: l.commonDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  isDestructive: true,
                  onTap: () => _deleteTag(tag.valueOrNull!),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 8.0,
            ),
            child: OriginSegmentedControl<TagDetailPeriod>(
              items: const [
                TagDetailPeriod.month,
                TagDetailPeriod.year,
                TagDetailPeriod.all,
              ],
              selectedItem: _period,
              onSelected: (item) => setState(() => _period = item),
              labelBuilder: (item) => switch (item) {
                TagDetailPeriod.month => l.analyticsMonth,
                TagDetailPeriod.year => l.analyticsYear,
                TagDetailPeriod.all => l.analyticsAll,
              },
            ),
          ),
          if (_period != TagDetailPeriod.all)
            TextButton.icon(
              onPressed: () => _date(anchor),
              icon: const Icon(Icons.calendar_today_rounded, size: 14),
              label: Text(_period == TagDetailPeriod.year
                  ? '${anchor.year}'
                  : '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}'),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: tag.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: BeeStatus(
                  label: l.commonError,
                  tone: BeeTone.error,
                  action: BeeButton(
                    label: l.v4RecordingRetry,
                    onPressed: retry,
                  ),
                ),
              ),
              data: (value) => value == null
                  ? Center(child: BeeEmptyState(title: l.tagNotFound))
                  : TagDetailSections(
                      tag: value,
                      stats: stats,
                      data: data,
                      allLedgers: widget.allLedgers,
                      onRetry: retry,
                      onCategory: (category) => _open(CustomCategoryDetailPage(
                        categoryId: category.id,
                        categoryName: CategoryUtils.getDisplayName(
                            category.name, context, kind: category.kind),
                        allLedgers: widget.allLedgers,
                        startDate: range?.start,
                        endDate: range?.end,
                      )),
                      onRecord: () => _open(TransactionEditorPage(
                        initialKind: 'expense',
                        initialTagIds: [value.id],
                      )),
                      onDelete: _deleteTransaction,
                      onReturned: _refresh,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
