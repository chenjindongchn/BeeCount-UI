import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../models/home_transaction_preview.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格流水外框组件 (OriginJournalFrame)
///
/// 遵循需求 3：
/// 1. 展示纯净的“全部明细”及记录笔数；
/// 2. 彻底去除此排的日历、筛选和批量按钮（批量已转由长按条目触发）；
/// 3. 支持初次无闪烁加载预览计数。
class OriginJournalFrame extends ConsumerStatefulWidget {
  final Widget? child;
  final Widget Function(ValueChanged<HomeTransactionPreview> onPreviewReady)?
      childBuilder;
  final HomeTransactionPreview? initialPreview;

  const OriginJournalFrame({
    super.key,
    this.child,
    this.childBuilder,
    this.initialPreview,
  }) : assert(child != null || childBuilder != null);

  @override
  ConsumerState<OriginJournalFrame> createState() => _OriginJournalFrameState();
}

class _OriginJournalFrameState extends ConsumerState<OriginJournalFrame> {
  int? _countLedger;
  int? _displayCount;
  AsyncValue<({int dayCount, int txCount})>? _observedCounts;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPreview;
    if (initial != null &&
        initial.ledgerId == ref.read(currentLedgerIdProvider)) {
      _countLedger = initial.ledgerId;
      _displayCount = initial.totalCount;
      _observedCounts = ref.read(countsForLedgerProvider(initial.ledgerId));
    }
  }

  void _onPreviewReady(HomeTransactionPreview preview) {
    if (!mounted || preview.ledgerId != ref.read(currentLedgerIdProvider)) {
      return;
    }
    setState(() {
      _countLedger = preview.ledgerId;
      _displayCount = preview.totalCount;
    });
    ref.invalidate(countsForLedgerProvider(preview.ledgerId));
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    if (_countLedger != ledgerId) {
      _countLedger = ledgerId;
      _displayCount = null;
      _observedCounts = null;
    }

    final counts = ref.watch(countsForLedgerProvider(ledgerId));
    if (!identical(counts, _observedCounts)) {
      _observedCounts = counts;
      if (!counts.isLoading &&
          counts is AsyncData<({int dayCount, int txCount})>) {
        _displayCount = counts.value.txCount;
      }
    }
    final count = _displayCount ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // “全部明细”标题行（彻底移除日历筛选和批量，纯净呈现）
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 6.0),
          child: Row(
            children: [
              Text(
                '全部明细',
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: OriginTokens.textPrimary(context),
                  letterSpacing: -0.2,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6.0),
                Text(
                  '($count笔)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: OriginTokens.textTertiary(context),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 流水列表区域
        Expanded(
          child: widget.childBuilder?.call(_onPreviewReady) ?? widget.child!,
        ),
      ],
    );
  }
}
