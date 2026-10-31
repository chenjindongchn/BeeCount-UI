import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../data/repositories/base_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/home_transaction_preview.dart';
import '../../../providers.dart';
import '../../../providers/budget_providers.dart';
import '../../../providers/home_startup_preview_provider.dart';
import '../../../services/billing/post_processor.dart';
import '../../../utils/transaction_edit_utils.dart';
import '../../../utils/format_money.dart';
import '../../../utils/month_range.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_divider.dart';
import 'origin_dialog.dart';
import 'origin_transaction_item.dart';
import '../providers/amount_format_provider.dart';

/// vivo OriginOS 风格交易流加载器 (OriginTransactionFeed)
class OriginTransactionFeed extends ConsumerStatefulWidget {
  final int ledgerId;
  final bool hideAmounts;
  final GlobalKey<OriginTransactionListState> listKey;
  final FlutterListViewController controller;
  final void Function(String, bool)? onDateVisibilityChanged;
  final Widget? emptyWidget;
  final ValueChanged<HomeTransactionPreview>? onPreviewReady;
  final HomeStartupPreview? startupPreview;
  final VoidCallback? onBatch;
  final Future<void> Function(dynamic item)? onDelete;
  final Widget? header;

  const OriginTransactionFeed({
    super.key,
    required this.ledgerId,
    required this.hideAmounts,
    required this.listKey,
    required this.controller,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.onPreviewReady,
    this.startupPreview,
    this.onBatch,
    this.onDelete,
    this.header,
  });

  @override
  ConsumerState<OriginTransactionFeed> createState() =>
      _OriginTransactionFeedState();
}

class _OriginTransactionFeedState extends ConsumerState<OriginTransactionFeed> {
  BaseRepository? _repository;
  int? _ledger;
  int _generation = 0;
  StreamSubscription<List<TransactionRowData>>? _subscription;
  HomeTransactionPreview? _preview;
  List<TransactionRowData>? _fullRows;
  Object? _error;
  bool _sourceLoading = false;

  void _bind(BaseRepository repository, int ledger) {
    final firstBind = _repository == null;
    _repository = repository;
    _ledger = ledger;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _preview = null;
    _fullRows = null;
    _error = null;
    _sourceLoading = true;
    final startup = firstBind ? widget.startupPreview : null;
    if (startup?.matches(repository, ledger) == true) {
      _preview = startup!.preview;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) return;
        widget.onPreviewReady?.call(startup.preview);
        _watchFull(repository, ledger, generation);
      });
      return;
    }
    unawaited(_readPreview(repository, ledger, generation));
  }

  Future<void> _readPreview(
      BaseRepository repository, int ledger, int generation) async {
    try {
      final preview =
          await repository.getHomeTransactionPreview(ledgerId: ledger);
      if (!mounted || generation != _generation) return;
      widget.onPreviewReady?.call(preview);
      setState(() => _preview = preview);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && generation == _generation) {
          _watchFull(repository, ledger, generation);
        }
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _sourceLoading = false;
      });
    }
  }

  void _watchFull(BaseRepository repository, int ledger, int generation) {
    var received = false;
    try {
      _subscription =
          repository.transactionsWithCategoryAll(ledgerId: ledger).listen(
        (rows) {
          if (!mounted || generation != _generation) return;
          received = true;
          setState(() {
            _fullRows = rows;
            _error = null;
            _sourceLoading = false;
          });
        },
        onError: (Object error, StackTrace stack) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _error = error;
            _sourceLoading = false;
          });
        },
        onDone: () {
          if (!mounted || generation != _generation || received) return;
          setState(() {
            _error = StateError('流水数据通道已关闭');
            _sourceLoading = false;
          });
        },
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _sourceLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    final repository = _repository!, ledger = _ledger!;
    final generation = ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted || generation != _generation) return;
    setState(() {
      _error = null;
      _sourceLoading = true;
    });
    if (_preview == null) {
      await _readPreview(repository, ledger, generation);
    } else {
      _watchFull(repository, ledger, generation);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    if (_repository != repository || _ledger != widget.ledgerId) {
      _bind(repository, widget.ledgerId);
    }
    final preview = _preview;
    if (preview == null) {
      if (_error != null) {
        final l = AppLocalizations.of(context);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.commonError),
              TextButton(onPressed: _retry, child: Text(l.v4RecordingRetry)),
            ],
          ),
        );
      }
      return const Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return OriginTransactionList(
      key: widget.listKey,
      ledgerId: widget.ledgerId,
      transactions: _fullRows ??
          (preview.totalCount == 0 ? const <TransactionRowData>[] : null),
      transactionsWithDetails: preview.rows,
      previewDayTotals: preview.dayTotals,
      sourceReady: _fullRows != null || preview.totalCount == 0,
      sourceLoading: _sourceLoading,
      sourceError: _error,
      onRetrySource: _retry,
      hideAmounts: widget.hideAmounts,
      enableVisibilityTracking: true,
      onDateVisibilityChanged: widget.onDateVisibilityChanged,
      controller: widget.controller,
      emptyWidget: widget.emptyWidget,
      onBatch: widget.onBatch,
      onDelete: widget.onDelete,
      header: widget.header,
    );
  }
}

/// vivo OriginOS 风格流水列表核心组件 (OriginTransactionList)
class OriginTransactionList extends ConsumerStatefulWidget {
  final List<TransactionDisplayItem>? transactionsWithDetails;
  final List<TransactionRowData>? transactions;
  final bool hideAmounts;
  final bool enableVisibilityTracking;
  final Function(String dateKey, bool isVisible)? onDateVisibilityChanged;
  final Widget? emptyWidget;
  final FlutterListViewController? controller;
  final bool sourceReady;
  final int? ledgerId;
  final Map<String, TransactionDayTotals>? previewDayTotals;
  final Object? sourceError;
  final bool sourceLoading;
  final VoidCallback? onRetrySource;
  final VoidCallback? onBatch;
  final Future<void> Function(dynamic item)? onDelete;
  final Widget? header;

  const OriginTransactionList({
    super.key,
    this.transactionsWithDetails,
    this.transactions,
    required this.hideAmounts,
    this.enableVisibilityTracking = false,
    this.onDateVisibilityChanged,
    this.emptyWidget,
    this.controller,
    this.sourceReady = true,
    this.ledgerId,
    this.previewDayTotals,
    this.sourceError,
    this.sourceLoading = false,
    this.onRetrySource,
    this.onBatch,
    this.onDelete,
    this.header,
  });

  @override
  ConsumerState<OriginTransactionList> createState() =>
      OriginTransactionListState();
}

class OriginTransactionListState extends ConsumerState<OriginTransactionList> {
  late FlutterListViewController _controller;
  List<({String dateKey, List<TransactionRowData> list})> _groupedDays = [];
  final Map<String, int> _dateIndexMap = {};
  bool _usePreloadedData = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? FlutterListViewController();
    _usePreloadedData = widget.transactionsWithDetails != null &&
        (widget.transactions == null || !widget.sourceReady);
  }

  @override
  void didUpdateWidget(covariant OriginTransactionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sourceReady && _usePreloadedData) {
      _usePreloadedData = false;
    }
  }

  void switchToStreamMode() {
    if (!_usePreloadedData) return;
    setState(() {
      _usePreloadedData = false;
    });
  }

  void forceStreamModeImmediate() {
    if (!mounted) return;
    setState(() {
      _usePreloadedData = false;
    });
  }

  /// 长按记账条目触发删除，弹出符合截图与 OriginOS 规范的危险删除确认弹窗
  Future<void> _handleDeleteTransaction(dynamic transaction) async {
    final confirmed = await showOriginConfirmDialog(
      context,
      title: '确定要删除该条账单吗？删除后不可恢复',
      confirmText: '确定',
      cancelText: '取消',
      isDanger: true,
    );

    if (confirmed == true && mounted) {
      switchToStreamMode();
      try {
        final repo = ref.read(repositoryProvider);
        await repo.deleteTransaction(transaction.id);
        if (!mounted) return;
        final curLedger = ref.read(currentLedgerIdProvider);
        ref.invalidate(countsForLedgerProvider(curLedger));
        ref.read(statsRefreshProvider.notifier).state++;
        ref.read(budgetRefreshProvider.notifier).state++;
        PostProcessor.sync(ref, ledgerId: curLedger);
        if (mounted) {
          showBeeToast(context, '删除成功');
        }
      } catch (e) {
        if (mounted) {
          showBeeToast(context, '删除失败: $e', tone: BeeTone.error);
        }
      }
    }
  }

  void jumpToTop() {
    try {
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    } catch (_) {}
  }

  bool jumpToMonth(DateTime targetMonth, {int startDay = 1}) {
    final range = periodForLabel(targetMonth.year, targetMonth.month, startDay);
    for (final entry in _dateIndexMap.entries) {
      final parts = entry.key.split('-');
      if (parts.length != 3) continue;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      if (!d.isBefore(range.start) && d.isBefore(range.end)) {
        try {
          _controller.sliverController.jumpToIndex(entry.value);
          return true;
        } catch (_) {
          return false;
        }
      }
    }
    return false;
  }

  void _buildGroups() {
    final rows = !_usePreloadedData && widget.transactions != null
        ? widget.transactions!
        : (widget.transactionsWithDetails
                ?.map((item) => (
                      t: item.t,
                      category: item.category,
                      account: item.account,
                      toAccount: item.toAccount,
                    ))
                .toList(growable: false) ??
            widget.transactions ??
            const []);

    final dateFmt = DateFormat('yyyy-MM-dd');
    final map = <String, List<TransactionRowData>>{};
    for (final item in rows) {
      final dt = item.t.happenedAt.toLocal();
      final key = dateFmt.format(DateTime(dt.year, dt.month, dt.day));
      map.putIfAbsent(key, () => []).add(item);
    }

    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    _groupedDays = sortedKeys.map((k) => (dateKey: k, list: map[k]!)).toList();

    final headerOffset = widget.header != null ? 1 : 0;
    _dateIndexMap.clear();
    for (var i = 0; i < _groupedDays.length; i++) {
      _dateIndexMap[_groupedDays[i].dateKey] = i + headerOffset;
    }
  }

  String _formatWeekday(DateTime dt) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[dt.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(thousandSeparatorProvider);
    _buildGroups();

    final hasHeader = widget.header != null;
    final headerCount = hasHeader ? 1 : 0;

    if (_groupedDays.isEmpty && widget.sourceLoading) {
      return Column(
        children: [
          if (hasHeader) widget.header!,
          const Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      );
    }

    if (_groupedDays.isEmpty) {
      return ListView(
        controller: _controller,
        physics: const BouncingScrollPhysics(),
        children: [
          if (hasHeader) widget.header!,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(
              child: widget.emptyWidget ??
                  Text(
                    '暂无流水记录',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                  ),
            ),
          ),
        ],
      );
    }

    final totalItems = headerCount + _groupedDays.length + 1; // +1 为底部留白 Spacer

    return FlutterListView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      delegate: FlutterListViewDelegate(
        (BuildContext context, int index) {
          if (hasHeader && index == 0) {
            return widget.header!;
          }

          final dayIndex = index - headerCount;
          if (dayIndex >= _groupedDays.length) {
            // 底部安全留白
            final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
            return SizedBox(height: 56 + 16 + bottomPadding + 20);
          }

          final dayData = _groupedDays[dayIndex];
          final dateKey = dayData.dateKey;
          final items = dayData.list;

          // 计算当日收支统计
          double dayIncome = 0;
          double dayExpense = 0;
          for (final it in items) {
            if (it.t.type == 'income') {
              dayIncome += it.t.nativeAmount ?? it.t.amount;
            } else if (it.t.type == 'expense') {
              dayExpense += it.t.nativeAmount ?? it.t.amount;
            }
          }

          if (_usePreloadedData && widget.previewDayTotals?[dateKey] != null) {
            final t = widget.previewDayTotals![dateKey]!;
            dayIncome = t.income;
            dayExpense = t.expense;
          }

          // 格式化日期：2025年9月22日 星期一
          final dateParts = dateKey.split('-');
          String dateTitle = dateKey;
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final month = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            final dt = DateTime(year, month, day);
            dateTitle = '$year年$month月$day日 ${_formatWeekday(dt)}';
          }

          // 格式化统计：支87.54  收0.00
          final expenseStr = widget.hideAmounts
              ? '****'
              : formatMoneyCompact(dayExpense, maxDecimals: 2);
          final incomeStr = widget.hideAmounts
              ? '****'
              : formatMoneyCompact(dayIncome, maxDecimals: 2);

          Widget cardContent = Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: OriginTokens.cardBackground(context),
              borderRadius: BorderRadius.circular(16.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 日期头部 (2025年9月22日 星期一        支87.54 收0.00)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateTitle,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: OriginTokens.textPrimary(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        '支$expenseStr  收$incomeStr',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: OriginTokens.textSecondary(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. 发丝分割线
                const OriginDivider(startIndent: 0),

                // 3. 当天条目列表
                for (var i = 0; i < items.length; i++) ...[
                  OriginTransactionItem(
                    transaction: items[i].t,
                    category: items[i].category,
                    account: items[i].account,
                    toAccount: items[i].toAccount,
                    hideAmounts: widget.hideAmounts,
                    onTap: () async {
                      switchToStreamMode();
                      await TransactionEditUtils.editTransaction(
                        context,
                        ref,
                        items[i].t,
                        items[i].category,
                      );
                    },
                    // 长按条目触发删除确认弹窗
                    onLongPress: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(items[i].t);
                      } else {
                        _handleDeleteTransaction(items[i].t);
                      }
                    },
                  ),
                  if (i < items.length - 1)
                    const OriginDivider(startIndent: 56.0),
                ],
              ],
            ),
          );

          if (widget.enableVisibilityTracking &&
              widget.onDateVisibilityChanged != null) {
            return VisibilityDetector(
              key: Key('header-$dateKey'),
              onVisibilityChanged: (info) {
                widget.onDateVisibilityChanged!(
                    dateKey, info.visibleFraction > 0.5);
              },
              child: cardContent,
            );
          }

          return cardContent;
        },
        childCount: totalItems,
        keepPosition: true,
        onItemKey: (index) {
          if (hasHeader && index == 0) return 'header-item';
          final dayIndex = index - headerCount;
          if (dayIndex >= _groupedDays.length) return 'bottom-spacer';
          return 'group-${_groupedDays[dayIndex].dateKey}';
        },
      ),
    );
  }
}
