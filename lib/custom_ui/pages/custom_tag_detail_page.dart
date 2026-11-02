import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/shared/resources/widgets/detail_period_controls.dart'
    show detailRangeLabel;
import '../../pages/tag/detail/bindings/tag_detail.dart';
import '../widgets/custom_tag_detail_sections.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../../utils/month_range.dart';
import '../widgets/origin_period_picker.dart';
import 'custom_category_detail_page.dart';
import 'custom_transaction_sheet.dart';
import '../../pages/tag/tag_edit_page.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';

/// vivo OriginOS 风格自定义标签详情页面 (CustomTagDetailPage)
///
/// 核心特性：
/// 1. 右上角采用统一的 2 个点入口 (OriginMoreButton)，点击呼出高质感展开式气泡菜单（编辑、删除）；
/// 2. 顶部提供高质感周期切换滑块 (BeeCompactTabs: 月/年/全部) 及动态日期调节条 (BeeDateRangeBar)；
/// 3. 页面内容集成 OriginHeroCard 顶级数据看板卡片，展示标签专属色彩底、核心支出数额与核心多维指标；
/// 4. 底部常驻“使用此标签记一笔”高质感大胶囊按钮 (Bottom CTA)，无缝联动 OriginOS 记账抽屉，预选当前标签；
/// 5. 纯 Riverpod 驱动，复用底层标签数据与业务逻辑，零上游冲突。
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

  Future<void> _date(DateTime anchor) async {
    final chosen = await showOriginPeriodPicker(
      context,
      period: _period.name,
      anchor: anchor,
    );
    if (chosen != null && mounted) {
      setState(() {
        _period = TagDetailPeriod.values.byName(chosen.period);
        _anchor = chosen.anchor;
      });
    }
  }

  Future<void> _record(db.Tag? currentTag) async {
    final tagId = currentTag?.id ?? widget.tagId;
    final saved = await showCustomTransactionSheet(
      context,
      initialKind: 'expense',
      initialTagIds: [tagId],
    );
    if (saved == true && mounted) {
      _refresh();
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
    final primaryColor = ref.watch(primaryColorProvider);
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
          // 顶部时间选择滑块与日期调节条
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Column(
              children: [
                BeeCompactTabs<TagDetailPeriod>(
                  value: _period,
                  trackHeight: 32,
                  tapHeight: 44,
                  items: [
                    BeeSegment(
                      TagDetailPeriod.month,
                      l.v4DetailMonth,
                    ),
                    BeeSegment(
                      TagDetailPeriod.year,
                      l.v4DetailYear,
                    ),
                    BeeSegment(
                      TagDetailPeriod.all,
                      l.analyticsAll,
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _period = value);
                  },
                ),
                if (_period != TagDetailPeriod.all)
                  BeeDateRangeBar(
                    label: detailRangeLabel(
                      context,
                      _period.name,
                      anchor,
                    ),
                    onChoose: () => _date(anchor),
                    previousLabel:
                        MaterialLocalizations.of(context).previousMonthTooltip,
                    nextLabel:
                        MaterialLocalizations.of(context).nextMonthTooltip,
                    onPrevious: () => setState(() {
                      _anchor = _period == TagDetailPeriod.year
                          ? DateTime(anchor.year - 1, anchor.month)
                          : DateTime(anchor.year, anchor.month - 1);
                    }),
                    onNext: () => setState(() {
                      _anchor = _period == TagDetailPeriod.year
                          ? DateTime(anchor.year + 1, anchor.month)
                          : DateTime(anchor.year, anchor.month + 1);
                    }),
                  ),
              ],
            ),
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
                  : CustomTagDetailSections(
                      tag: value,
                      stats: stats,
                      data: data,
                      allLedgers: widget.allLedgers,
                      period: _period,
                      anchor: anchor,
                      onRetry: retry,
                      onCategory: (category) => _open(CustomCategoryDetailPage(
                        categoryId: category.id,
                        categoryName: CategoryUtils.getDisplayName(
                            category.name, context, kind: category.kind),
                        allLedgers: widget.allLedgers,
                        startDate: range?.start,
                        endDate: range?.end,
                      )),
                      onDelete: _deleteTransaction,
                      onReturned: _refresh,
                    ),
            ),
          ),
        ],
      ),
      // 底部常驻“使用此标签记一笔”大胶囊按钮
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OriginTokens.cardMargin,
            vertical: 12.0,
          ),
          child: SizedBox(
            height: OriginTokens.buttonHeight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    OriginTokens.buttonRadius,
                  ),
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _record(tag.valueOrNull);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l.v4TagRecord,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
