import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../pages/transaction/recording/bindings/amount_editor_sheet.dart';
import '../../pages/transaction/recording/bindings/recording_category_section.dart';
import '../../pages/transaction/recording/bindings/recording_save.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import '../widgets/custom_account_grid_picker.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../widgets/origin_date_picker.dart';
import '../widgets/origin_keypad.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_text_field.dart';
import '../widgets/origin_time_picker.dart';

/// 弹出 OriginOS 规范的定制记账底部抽屉
Future<bool?> showCustomTransactionSheet(
  BuildContext context, {
  String initialKind = 'expense',
  int? initialCategoryId,
  int? initialAccountId,
  int? initialToAccountId,
  DateTime? initialDate,
  List<int>? initialTagIds,
  double? initialAmount,
  String? initialNote,
  int? editingTransactionId,
  bool isCopy = false,
  bool excludeFromStats = false,
  bool excludeFromBudget = false,
}) {
  final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
  return showOriginBottomSheet<bool>(
    context,
    heightFactor: isLandscape ? 0.95 : 0.72, // 竖屏约占屏幕 72%，横屏扩展至 95% 留出舒适空间
    builder: (_) => CustomTransactionSheet(
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
      showDragHandle: true,
      dragHandleBarVisible: false,
    ),
  );
}

/// OriginUI 定制记账抽屉主体
class CustomTransactionSheet extends ConsumerStatefulWidget {
  const CustomTransactionSheet({
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
    this.showDragHandle = true,
    this.dragHandleBarVisible = true,
    this.showTopBar = false,
    this.onClose,
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
  final bool showDragHandle;

  /// 是否显示拉手横线（隐藏时仍保留同等高度与下拉关闭热区）
  final bool dragHandleBarVisible;
  final bool showTopBar;
  final VoidCallback? onClose;

  @override
  ConsumerState<CustomTransactionSheet> createState() =>
      _CustomTransactionSheetState();
}

class _CustomTransactionSheetState extends ConsumerState<CustomTransactionSheet>
    with SingleTickerProviderStateMixin {
  // 0=支出, 1=收入, 2=转账
  late int _selectedType;
  int? _animatingToPage;
  late int _ledgerId;
  late final PageController _pageController;
  late final AnimationController _cursorController;

  // 金额相关
  String _amountExpression = '0';

  // 记账属性
  Category? _selectedCategory;
  final TextEditingController _noteController = TextEditingController();
  late DateTime _selectedDate;
  int? _selectedAccountId;
  List<int> _selectedTagIds = [];

  // 转账专用属性
  int? _transferToAccountId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialKind == 'income'
        ? 1
        : widget.initialKind == 'transfer'
            ? 2
            : 0;
    _pageController = PageController(initialPage: _selectedType);
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _selectedDate = widget.initialDate ?? DateTime.now();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _selectedAccountId = widget.initialAccountId;
    _transferToAccountId = widget.initialToAccountId;
    if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
      _selectedTagIds = List.from(widget.initialTagIds!);
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      final amt = widget.initialAmount!;
      if (amt == amt.roundToDouble()) {
        _amountExpression = amt.toInt().toString();
      } else {
        _amountExpression = amt.toStringAsFixed(2);
      }
    }
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _noteController.text = widget.initialNote!;
    }
    _initDefaultAccount();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _noteController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  Future<void> _initDefaultAccount() async {
    if (_selectedAccountId != null) return;
    try {
      final acc = await defaultRecordingAccount(ref, _currentKind, _ledgerId);
      if (mounted && acc != null) {
        setState(() => _selectedAccountId = acc);
      }
    } catch (_) {}
  }

  String get _currentKind {
    switch (_selectedType) {
      case 1:
        return 'income';
      case 2:
        return 'transfer';
      default:
        return 'expense';
    }
  }

  Future<void> _updateDefaultAccountForKind(int index) async {
    if (index == 2 || widget.initialAccountId != null || widget.editingTransactionId != null) return;
    try {
      final kind = index == 1 ? 'income' : 'expense';
      final acc = await defaultRecordingAccount(ref, kind, _ledgerId);
      if (mounted) {
        setState(() => _selectedAccountId = acc);
      }
    } catch (_) {}
  }

  void _onTypeSelected(int index) {
    if (_selectedType == index) return;
    HapticFeedback.selectionClick();
    _animatingToPage = index;
    setState(() {
      _selectedType = index;
      _selectedCategory = null;
    });
    _updateDefaultAccountForKind(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: OriginTokens.fastOutSlowIn,
    ).then((_) {
      if (mounted) {
        _animatingToPage = null;
      }
    });
  }

  void _onPageChanged(int index) {
    if (_animatingToPage != null) {
      if (index == _animatingToPage) {
        _animatingToPage = null;
      }
      return;
    }
    if (_selectedType != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedType = index;
        _selectedCategory = null;
      });
      _updateDefaultAccountForKind(index);
    }
  }

  // --- 键盘计算器逻辑 ---

  void _onDigit(String digit) {
    setState(() {
      if (_amountExpression == '0') {
        _amountExpression = digit;
      } else {
        final parts = _amountExpression.split(RegExp(r'[\+\-]'));
        final currentNumber = parts.last;
        if (currentNumber.contains('.')) {
          final decParts = currentNumber.split('.');
          if (decParts.length > 1 && decParts[1].length >= 2) {
            return;
          }
        }
        if (_amountExpression.length < 15) {
          _amountExpression += digit;
        }
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      if (_amountExpression.endsWith('+') || _amountExpression.endsWith('-')) {
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1) + op;
      } else {
        _evaluateExpression();
        _amountExpression += op;
      }
    });
  }

  void _onDecimal() {
    setState(() {
      final parts = _amountExpression.split(RegExp(r'[\+\-]'));
      final currentNumber = parts.last;
      if (!currentNumber.contains('.')) {
        if (currentNumber.isEmpty) {
          _amountExpression += '0.';
        } else {
          _amountExpression += '.';
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountExpression.length <= 1) {
        _amountExpression = '0';
      } else {
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountExpression = '0';
    });
  }

  double _evaluateExpression() {
    try {
      String expr = _amountExpression;
      if (expr.endsWith('+') || expr.endsWith('-')) {
        expr = expr.substring(0, expr.length - 1);
      }
      final regex = RegExp(r'([\+\-]?[0-9]*\.?[0-9]+)');
      final matches = regex.allMatches(expr);
      double total = 0.0;
      for (final match in matches) {
        final val = double.tryParse(match.group(0) ?? '') ?? 0.0;
        total += val;
      }
      final formatted = total.toStringAsFixed(2);
      return double.parse(formatted);
    } catch (_) {
      return 0.0;
    }
  }

  // --- 保存记账 ---

  Future<void> _submit({required bool continueAdding}) async {
    if (_isSaving) return;

    final amount = _evaluateExpression();
    if (amount <= 0) {
      _showToast('请输入有效金额');
      return;
    }

    final categories = ref.read(
      recordingCategoriesProvider((ledgerId: _ledgerId, kind: _currentKind)),
    ).valueOrNull;
    Category? initialMatch;
    if (widget.initialCategoryId != null && categories != null) {
      initialMatch = categories.where((c) => c.id == widget.initialCategoryId).firstOrNull;
    }
    final catToSave = _selectedCategory ?? initialMatch ?? categories?.firstOrNull;

    if (_selectedType != 2 && catToSave == null) {
      _showToast('请选择记账分类');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_selectedType == 2) {
        if (_selectedAccountId == null || _transferToAccountId == null) {
          _showToast('请选择转出与转入账户');
          setState(() => _isSaving = false);
          return;
        }
        if (_selectedAccountId == _transferToAccountId) {
          _showToast('转出与转入账户不能相同');
          setState(() => _isSaving = false);
          return;
        }
        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: const <File>[],
          excludeFromStats: widget.excludeFromStats,
          excludeFromBudget: widget.excludeFromBudget,
          currencyCode: null as String?,
          nativeAmount: null as double?,
        );

        await persistTransferDraft(
          ref,
          ledgerId: _ledgerId,
          result: resultRecord,
          fromAccountId: _selectedAccountId!,
          toAccountId: _transferToAccountId!,
          editingId: widget.editingTransactionId,
          onCreated: (_) {},
        );
      } else {
        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: const <File>[],
          excludeFromStats: widget.excludeFromStats,
          excludeFromBudget: widget.excludeFromBudget,
          currencyCode: null as String?,
          nativeAmount: null as double?,
        );

        await persistRecordingDraft(
          ref,
          ledgerId: _ledgerId,
          category: catToSave!,
          kind: _currentKind,
          result: resultRecord,
          editingId: widget.editingTransactionId,
          onCreated: (_) {},
        );
      }

      if (!mounted) return;

      if (continueAdding) {
        setState(() {
          _isSaving = false;
          _amountExpression = '0';
          _noteController.clear();
        });
        _showToast('已记一笔，请继续');
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('保存失败: $e');
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI 组件构建 ---

  @override
  Widget build(BuildContext context) {
    final cardBg = OriginSheetTokens.cardColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    if (isLandscape) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(OriginSheetTokens.cornerRadius),
          ),
        ),
        child: Column(
          children: [
            // 顶部微型拉手条（横屏模式留出轻微拖拽热区）
            if (widget.showDragHandle)
              OriginSheetDragRegion(
                child: SizedBox(
                  height: 12,
                  child: widget.dragHandleBarVisible
                      ? Center(
                          child: Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        )
                      : null,
                ),
              ),

            // 横屏下采用双栏并排结构（彻底解决竖向空间被挤压导致溢出）
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左栏：分类切换与分类网格/转账视图
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: [
                        _buildTopHeader(context),
                        const SizedBox(height: 4),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: 3,
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              switch (index) {
                                case 0:
                                  return _buildCategoryGrid(context,
                                      kind: 'expense', crossAxisCount: 4);
                                case 1:
                                  return _buildCategoryGrid(context,
                                      kind: 'income', crossAxisCount: 4);
                                case 2:
                                  return _buildTransferAccounts(context);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 纵向精致分割线
                  VerticalDivider(
                    width: 1,
                    thickness: 0.6,
                    indent: 4,
                    endIndent: 4,
                    color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                  ),

                  // 右栏：金额展示、备注输入、日期账户胶囊、紧凑数字键盘
                  Expanded(
                    flex: 12,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: MediaQuery.of(context).padding.right > 0
                            ? MediaQuery.of(context).padding.right
                            : 6.0,
                        bottom: bottomInset > 0 ? bottomInset * 0.35 : 2.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAmountDisplay(context, compact: true),
                              const SizedBox(height: 2),
                              _buildNoteInput(context),
                              const SizedBox(height: 3),
                              _buildMetaSelectorRow(context),
                            ],
                          ),
                          OriginKeypad(
                            keyHeight: 36, // 横屏按键高度调为紧凑 36dp，布局完美无任何溢出
                            onDigit: _onDigit,
                            onOperator: _onOperator,
                            onBackspace: _onBackspace,
                            onClear: _onClear,
                            onDecimal: _onDecimal,
                            onSave: () => _submit(continueAdding: false),
                            onSaveAndContinue: () =>
                                _submit(continueAdding: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OriginSheetTokens.cornerRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 顶部拖拽热区条（抽屉模式下展示，横线可隐藏但保留占位与热区）
          if (widget.showDragHandle)
            OriginSheetDragRegion(
              child: SizedBox(
                height: 16,
                child: widget.dragHandleBarVisible
                    ? Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )
                    : null,
              ),
            ),

          // 2. 居中类型切换 Segmented（页面模式下左侧提供轻巧返回按钮）
          _buildTopHeader(context),

          const SizedBox(height: 4),

          // 3. 支持左右滑动切换的分类网格与转账视图（按需构建）
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 3,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildCategoryGrid(context, kind: 'expense');
                  case 1:
                    return _buildCategoryGrid(context, kind: 'income');
                  case 2:
                    return _buildTransferAccounts(context);
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),

          // 4. 金额大字输入展示区（严格位于备注正上方，紧凑精致）
          _buildAmountDisplay(context),

          const SizedBox(height: 4),

          // 5. 备注输入栏（紧凑胶囊）
          _buildNoteInput(context),

          const SizedBox(height: 5),

          // 6. 时间、账户、标签选择栏（严格位于备注正下方）
          _buildMetaSelectorRow(context),

          const SizedBox(height: 4),

          // 7. OriginOS 风格数字键盘（紧密贴底）
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset * 0.35 : 2.0),
            child: OriginKeypad(
              onDigit: _onDigit,
              onOperator: _onOperator,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onDecimal: _onDecimal,
              onSave: () => _submit(continueAdding: false),
              onSaveAndContinue: () => _submit(continueAdding: true),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部栏容器（根据 showTopBar 动态提供返回按钮或纯居中胶囊）
  Widget _buildTopHeader(BuildContext context) {
    if (!widget.showTopBar) {
      return _buildTypeSegmented(context);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose ?? () => Navigator.maybePop(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                ),
              ),
            ),
          ),
          _buildTypeSegmented(context),
        ],
      ),
    );
  }

  /// 居中 Segmented 切换胶囊（高 32dp，使用统一现成的 OriginSegmentedControl）
  Widget _buildTypeSegmented(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 216,
        child: OriginSegmentedControl<int>(
          items: const [0, 1, 2],
          selectedItem: _selectedType,
          height: 32,
          onSelected: _onTypeSelected,
          labelBuilder: (index) {
            switch (index) {
              case 0:
                return '支出';
              case 1:
                return '收入';
              case 2:
                return '转账';
              default:
                return '';
            }
          },
        ),
      ),
    );
  }

  /// 金额输入展示区（位于备注正上方，字号 25sp，轻巧自然，末端带主题色闪烁光标）
  Widget _buildAmountDisplay(BuildContext context, {bool compact = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 10, 20, compact ? 1 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: compact ? 17 : 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      Text(
                        _amountExpression,
                        style: TextStyle(
                          fontSize: compact ? 22 : 26,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                        ),
                      ),
                      FadeTransition(
                        opacity: _cursorController,
                        child: Container(
                          width: 1.8,
                          height: compact ? 22 : 26,
                          margin: const EdgeInsets.only(left: 2.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : 3),
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }

  /// 5 列（横屏 4 列）精致分类图标网格（紧凑尺寸，直径 38dp）
  Widget _buildCategoryGrid(BuildContext context, {required String kind, int crossAxisCount = 5}) {
    final categoriesAsync = ref.watch(
      recordingCategoriesProvider((ledgerId: _ledgerId, kind: kind)),
    );

    return categoriesAsync.when(
      // 骨架屏与真实网格同布局同尺寸，数据到达时切换近似无缝，避免上升动画中视觉跳变
      loading: () => _buildCategoryGridSkeleton(context, crossAxisCount: crossAxisCount),
      error: (_, __) => const Center(child: Text('分类加载失败')),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('暂无分类'));
        }

        Category? initialMatch;
        if (widget.initialCategoryId != null && _currentKind == kind) {
          initialMatch = categories
              .where((c) => c.id == widget.initialCategoryId)
              .firstOrNull;
        }
        final currentSelected =
            (_currentKind == kind && _selectedCategory != null)
                ? _selectedCategory
                : (initialMatch ?? categories.firstOrNull);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.vertical,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.92,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = currentSelected?.id == cat.id;
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final selectedBg = Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: isDark ? 0.25 : 0.15);
              final unselectedBg =
                  isDark ? const Color(0xFF28282C) : const Color(0xFFF4F5F7);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected ? selectedBg : unselectedBg,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: RecordingCategoryIcon(
                          category: cat,
                          size: 19,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white70 : const Color(0xFF4A4A4F)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.white70 : const Color(0xFF333336)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 分类网格骨架屏：复用未选中分类的底色与尺寸，保证 loading→data 无视觉跳变
  Widget _buildCategoryGridSkeleton(BuildContext context, {int crossAxisCount = 5}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleColor = isDark ? const Color(0xFF28282C) : const Color(0xFFF4F5F7);
    final labelColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.92,
        ),
        itemCount: 10,
        itemBuilder: (context, index) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
            ),
            const SizedBox(height: 2),
            Container(
              width: 26,
              height: 7,
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 转账模式下的账户选择
  Widget _buildTransferAccounts(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider(_ledgerId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return accountsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(child: Text('加载账户失败')),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(child: Text('暂无可用账户，请先添加账户'));
        }
        if (_transferToAccountId == null && accounts.length > 1) {
          _transferToAccountId = accounts[1].id;
        }

        final fromAcc = accounts.where((a) => a.id == _selectedAccountId).firstOrNull ?? accounts.first;
        final toAcc = accounts.where((a) => a.id == _transferToAccountId).firstOrNull ?? (accounts.length > 1 ? accounts[1] : accounts.first);

        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAccountPickerChip(
                  context,
                  label: '转出账户',
                  accountName: fromAcc.name,
                  onTap: () => _pickAccount(context, accounts, true),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
                _buildAccountPickerChip(
                  context,
                  label: '转入账户',
                  accountName: toAcc.name,
                  onTap: () => _pickAccount(context, accounts, false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountPickerChip(
    BuildContext context, {
    required String label,
    required String accountName,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF28282C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 备注输入栏（高度 34dp）
  Widget _buildNoteInput(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OriginTextField.compact(
        controller: _noteController,
        hintText: '点击填写备注',
        clearable: true,
        suffixIcon: Icon(
          Icons.camera_alt_outlined,
          size: 18,
          color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
        ),
      ),
    );
  }

  /// 严格位于备注正下方：时间、账户、标签选择（高度 28dp）
  Widget _buildMetaSelectorRow(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider(_ledgerId));

    String accountTitle = '选择账户';
    accountsAsync.whenData((accounts) {
      if (accounts.isNotEmpty && _selectedAccountId != null) {
        final acc = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
        if (acc != null) {
          accountTitle = acc.name;
        }
      }
    });

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final dateStr = isToday ? '今天' : DateFormat('MM-dd').format(_selectedDate);
    final timeStr = DateFormat('HH:mm').format(_selectedDate);

    final tagTitle = _selectedTagIds.isEmpty
        ? '标签'
        : '标签(${_selectedTagIds.length})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 账户选择 (非转账模式下)
          if (_selectedType != 2) ...[
            _buildMetaChip(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: accountTitle,
              onTap: () {
                accountsAsync.whenData((accounts) {
                  _pickAccount(context, accounts, true);
                });
              },
            ),
            const SizedBox(width: 6),
          ],

          // 原厂规范日期胶囊
          _buildMetaChip(
            context,
            icon: Icons.calendar_today_outlined,
            title: dateStr,
            onTap: _pickDate,
          ),
          const SizedBox(width: 6),

          // 原厂规范时间胶囊
          _buildMetaChip(
            context,
            icon: Icons.access_time_rounded,
            title: timeStr,
            onTap: _pickTime,
          ),
          const SizedBox(width: 6),

          // 标签选择
          _buildMetaChip(
            context,
            icon: Icons.local_offer_outlined,
            title: tagTitle,
            onTap: _pickTags,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF262629) : const Color(0xFFF3F4F6);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isDark ? Colors.white54 : const Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF424242),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 弹窗选择逻辑 ---

  Future<void> _pickDate() async {
    final picked = await showOriginDatePicker(
      context,
      initial: _selectedDate,
      minDate: DateTime(2000, 1, 1),
      maxDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
        _selectedDate.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showOriginTimePicker(
      context,
      initial: TimeOfDay(
        hour: _selectedDate.hour,
        minute: _selectedDate.minute,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
        _selectedDate.second,
      );
    });
  }

  Future<void> _pickAccount(
    BuildContext context,
    List<Account> accounts,
    bool isSourceAccount,
  ) async {
    final currentId = isSourceAccount ? _selectedAccountId : _transferToAccountId;

    final selectedId = await CustomAccountGridPicker.show(
      context,
      accounts: accounts,
      currentAccountId: currentId,
      showNoAccountOption: _selectedType != 2 && isSourceAccount,
      title: isSourceAccount ? '选择账户' : '选择转入账户',
    );

    if (selectedId != null && mounted) {
      setState(() {
        final newId = selectedId == CustomAccountGridPicker.noAccountId ? null : selectedId;
        if (isSourceAccount) {
          _selectedAccountId = newId;
        } else {
          _transferToAccountId = newId;
        }
      });
    }
  }

  Future<void> _pickTags() async {
    final result = await TagSelector.show(
      context,
      selectedTagIds: _selectedTagIds,
    );
    if (result != null && mounted) {
      setState(() => _selectedTagIds = result);
    }
  }
}
