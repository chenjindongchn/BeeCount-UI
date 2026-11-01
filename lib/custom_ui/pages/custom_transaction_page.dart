import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'custom_transaction_sheet.dart';
import '../styles/origin_sheet_tokens.dart';

/// OriginUI 定制记账承载页面（用于无缝替代原生全屏 TransactionEditorPage）
/// 严格遵守极简接触面与零冲突原则：任何通过 Route 路由进入记账的入口（日历、账户、标签等），
/// 均表现为与首页加号完全一致的“从底部升上来”的 Origin 记账抽屉。
class CustomTransactionPage extends ConsumerStatefulWidget {
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
  ConsumerState<CustomTransactionPage> createState() =>
      _CustomTransactionPageState();
}

class _CustomTransactionPageState extends ConsumerState<CustomTransactionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: OriginSheetTokens.enterDuration,
      reverseDuration: OriginSheetTokens.exitDuration,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: OriginSheetTokens.enterCurve,
        reverseCurve: OriginSheetTokens.exitCurve,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: OriginSheetTokens.enterCurve,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _animController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final barrierColor = OriginSheetTokens.scrimColor(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleClose();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            return Stack(
              children: [
                // 1. 半透明半黑背景遮罩（点击退出）
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleClose,
                    child: Container(
                      color: barrierColor.withValues(
                        alpha: barrierColor.a * _fadeAnimation.value,
                      ),
                    ),
                  ),
                ),

                // 2. 从底部升上来的 72% 高度 Origin 记账抽屉
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionalTranslation(
                    translation: Offset(0, _slideAnimation.value),
                    child: RepaintBoundary(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {}, // 阻止向背景遮罩穿透
                        child: SizedBox(
                          height: MediaQuery.sizeOf(context).height *
                              (MediaQuery.orientationOf(context) ==
                                      Orientation.landscape
                                  ? 0.95
                                  : 0.72),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(OriginSheetTokens.cornerRadius),
                            ),
                            child: CustomTransactionSheet(
                              initialKind: widget.initialKind,
                              initialCategoryId: widget.initialCategoryId,
                              initialAccountId: widget.initialAccountId,
                              initialToAccountId: widget.initialToAccountId,
                              initialDate: widget.initialDate,
                              initialTagIds: widget.initialTagIds,
                              initialAmount: widget.initialAmount,
                              initialNote: widget.initialNote,
                              editingTransactionId: widget.editingTransactionId,
                              isCopy: widget.isCopy,
                              excludeFromStats: widget.excludeFromStats,
                              excludeFromBudget: widget.excludeFromBudget,
                              showDragHandle: true,
                              showTopBar: false,
                              onClose: _handleClose,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
