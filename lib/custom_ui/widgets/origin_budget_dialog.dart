import 'dart:async';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/category_utils.dart';
import '../styles/origin_tokens.dart';
import 'origin_dialog.dart';
import 'origin_amount_field.dart';

/// vivo OriginOS 风格预算操作弹窗体系 (OriginBudgetDialog)
///
/// 严格遵守项目中所有其他 OriginOS 对话框的统一设计规范：
/// 1. 【贴底弹出】：对齐 Alignment.bottomCenter，入场动效自底部平滑滑升（SlideUp + Fade）；
/// 2. 【上下堆叠双胶囊】：确认按钮在上方（实心强调色），取消按钮在下方（中性灰底），高度 46dp，圆角 23dp；
/// 3. 【软键盘避让】：通过 AnimatedPadding 响应 viewInsets，键盘弹起时弹窗贴在键盘上方，键盘收起时贴在屏幕底部；
/// 4. 【完全复用 OriginDialog】：统一视觉风格、几何圆角 (30dp) 与阴影深度。

/// 弹出修改/设置总预算对话框（贴底弹出，按钮上下排列）
Future<void> showOriginTotalBudgetDialog({
  required BuildContext context,
  required WidgetRef ref,
  Budget? budget,
  required String currencySymbol,
}) {
  return showOriginCustomDialog<void>(
    context,
    child: _TotalBudgetDialog(
      budget: budget,
      currencySymbol: currencySymbol,
    ),
  );
}

/// 弹出添加分类预算对话框（贴底弹出，按钮上下排列）
Future<void> showOriginAddCategoryBudgetDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currencySymbol,
}) {
  return showOriginCustomDialog<void>(
    context,
    child: _AddCategoryBudgetDialog(
      currencySymbol: currencySymbol,
    ),
  );
}

/// 弹出修改已有分类预算对话框（贴底弹出，按钮上下排列）
Future<void> showOriginCategoryBudgetEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Budget budget,
  required String categoryName,
  Category? category,
  required String currencySymbol,
}) {
  return showOriginCustomDialog<void>(
    context,
    child: _EditCategoryBudgetDialog(
      budget: budget,
      categoryName: categoryName,
      category: category,
      currencySymbol: currencySymbol,
    ),
  );
}

// =============================================================================
// 1. 月度总预算对话框 (新建/编辑)
// =============================================================================
class _TotalBudgetDialog extends ConsumerStatefulWidget {
  final Budget? budget;
  final String currencySymbol;

  const _TotalBudgetDialog({
    this.budget,
    required this.currencySymbol,
  });

  @override
  ConsumerState<_TotalBudgetDialog> createState() => _TotalBudgetDialogState();
}

class _TotalBudgetDialogState extends ConsumerState<_TotalBudgetDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.budget?.amount;
    final initialText = amount != null
        ? (amount.truncateToDouble() == amount
            ? amount.toStringAsFixed(0)
            : amount.toStringAsFixed(2))
        : '';
    _controller = TextEditingController(text: initialText);
    if (initialText.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_saving || widget.budget == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l10n.commonDelete,
      message: l10n.budgetDeleteConfirm,
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      await ref.read(repositoryProvider).deleteBudget(widget.budget!.id);
      if (mounted) {
        ref.read(budgetRefreshProvider.notifier).state++;
        unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
        showBeeToast(context, l10n.budgetDeleteSuccess, tone: BeeTone.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final raw = BeeDecimalInputFormatter.normalize(_controller.text.trim());
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = l10n.budgetAmountHint);
      return;
    }

    setState(() => _saving = true);
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);
      if (widget.budget != null) {
        await repo.updateBudget(
          widget.budget!.id,
          amount: value,
          startDay: widget.budget!.startDay,
        );
      } else {
        await repo.createBudget(
          ledgerId: ledgerId,
          type: 'total',
          amount: value,
          startDay: 1,
        );
      }

      if (mounted) {
        ref.read(budgetRefreshProvider.notifier).state++;
        unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
        showBeeToast(context, l10n.budgetSaveSuccess, tone: BeeTone.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    final title = widget.budget != null
        ? l10n.budgetMonthlyBudget
        : l10n.budgetAddTotal;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: OriginDialog(
        alignment: Alignment.bottomCenter,
        title: title,
        textAlign: TextAlign.center,
        confirmText: _saving ? '...' : l10n.commonSave,
        onConfirm: _save,
        cancelText: l10n.commonCancel,
        onCancel: () => Navigator.of(context).pop(),
        stackActions: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12.0),
            // 金额输入槽 (OriginAmountField)
            OriginAmountField(
              controller: _controller,
              currencySymbol: widget.currencySymbol,
              autofocus: true,
              clearable: true,
              borderRadius: 16.0,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),

            // 错误提示
            if (_error != null) ...[
              const SizedBox(height: 8.0),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12.0,
                  color: OriginTokens.expenseRed,
                ),
              ),
            ],

            // 可选删除操作
            if (widget.budget != null) ...[
              const SizedBox(height: 12.0),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _saving ? null : _delete,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Center(
                    child: Text(
                      '删除总预算',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: OriginTokens.expenseRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. 添加分类预算对话框 (选择分类 + 输入金额)
// =============================================================================
class _AddCategoryBudgetDialog extends ConsumerStatefulWidget {
  final String currencySymbol;

  const _AddCategoryBudgetDialog({
    required this.currencySymbol,
  });

  @override
  ConsumerState<_AddCategoryBudgetDialog> createState() =>
      _AddCategoryBudgetDialogState();
}

class _AddCategoryBudgetDialogState
    extends ConsumerState<_AddCategoryBudgetDialog> {
  late final TextEditingController _controller;
  Category? _selectedCategory;
  List<Category> _categories = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadCategories();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);
      final all = await repo.getAllCategories();
      final existingBudgets = await repo.getCategoryBudgets(ledgerId);
      final existingCategoryIds =
          existingBudgets.map((b) => b.categoryId).toSet();

      final expenseCategories =
          all.where((c) => c.kind == 'expense' && c.parentId == null).toList();

      if (!mounted) return;
      setState(() {
        _categories = expenseCategories;
        // 自动预选第一个尚未设置预算的分类
        _selectedCategory = expenseCategories
            .where((c) => !existingCategoryIds.contains(c.id))
            .firstOrNull;
        // 如果全部都已设置，则默认选中第一个分类
        _selectedCategory ??= expenseCategories.firstOrNull;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickCategory() async {
    if (_saving || _loading || _categories.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final selected = await showBeeSheet<Category>(
      context,
      title: l10n.budgetCategoryLabel,
      child: BeeChoicePicker<Category>(
        items: _categories
            .map(
              (c) => BeeChoice(
                value: c,
                title: CategoryUtils.getDisplayName(c.name, context),
                searchText: c.name,
                leading: RecordingCategoryIcon(category: c, size: 24),
              ),
            )
            .toList(),
        selected: _selectedCategory,
        searchLabel: l10n.commonSearch,
        emptyLabel: l10n.budgetCategoryHint,
        onSelected: (value) => Navigator.pop(context, value),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedCategory = selected;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final l10n = AppLocalizations.of(context);
    if (_selectedCategory == null) {
      setState(() => _error = l10n.budgetCategoryHint);
      return;
    }

    final raw = BeeDecimalInputFormatter.normalize(_controller.text.trim());
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = l10n.budgetAmountHint);
      return;
    }

    setState(() => _saving = true);
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);

      // 检查该分类是否已有预算
      final existing =
          await repo.getBudgetByCategory(ledgerId, _selectedCategory!.id);
      if (existing != null) {
        await repo.updateBudget(
          existing.id,
          amount: value,
          startDay: existing.startDay,
        );
      } else {
        await repo.createBudget(
          ledgerId: ledgerId,
          type: 'category',
          categoryId: _selectedCategory!.id,
          amount: value,
          startDay: 1,
        );
      }

      if (mounted) {
        ref.read(budgetRefreshProvider.notifier).state++;
        unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
        showBeeToast(context, l10n.budgetSaveSuccess, tone: BeeTone.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: OriginDialog(
        alignment: Alignment.bottomCenter,
        title: '添加分类预算',
        textAlign: TextAlign.center,
        confirmText: _saving ? '...' : l10n.commonSave,
        onConfirm: _save,
        cancelText: l10n.commonCancel,
        onCancel: () => Navigator.of(context).pop(),
        stackActions: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12.0),
            // 分类选择槽
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickCategory,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    if (_selectedCategory != null) ...[
                      RecordingCategoryIcon(
                        category: _selectedCategory!,
                        size: 22,
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          CategoryUtils.getDisplayName(
                            _selectedCategory!.name,
                            context,
                          ),
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                            color: OriginTokens.textPrimary(context),
                          ),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.category_outlined,
                        size: 22.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: Text(
                          _loading ? '正在加载分类...' : '点击选择分类',
                          style: TextStyle(
                            fontSize: 15.0,
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10.0),

            // 金额输入槽 (OriginAmountField)
            OriginAmountField(
              controller: _controller,
              currencySymbol: widget.currencySymbol,
              autofocus: true,
              clearable: true,
              borderRadius: 16.0,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),

            // 错误提示
            if (_error != null) ...[
              const SizedBox(height: 8.0),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12.0,
                  color: OriginTokens.expenseRed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. 修改已有分类预算对话框 (输入金额 + 可选删除)
// =============================================================================
class _EditCategoryBudgetDialog extends ConsumerStatefulWidget {
  final Budget budget;
  final String categoryName;
  final Category? category;
  final String currencySymbol;

  const _EditCategoryBudgetDialog({
    required this.budget,
    required this.categoryName,
    this.category,
    required this.currencySymbol,
  });

  @override
  ConsumerState<_EditCategoryBudgetDialog> createState() =>
      _EditCategoryBudgetDialogState();
}

class _EditCategoryBudgetDialogState
    extends ConsumerState<_EditCategoryBudgetDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final amount = widget.budget.amount;
    final initialText = amount.truncateToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    _controller = TextEditingController(text: initialText);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialText.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l10n.commonDelete,
      message: l10n.budgetDeleteConfirm,
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDanger: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      await ref.read(repositoryProvider).deleteBudget(widget.budget.id);
      if (mounted) {
        ref.read(budgetRefreshProvider.notifier).state++;
        unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
        showBeeToast(context, l10n.budgetDeleteSuccess, tone: BeeTone.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final raw = BeeDecimalInputFormatter.normalize(_controller.text.trim());
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _error = l10n.budgetAmountHint);
      return;
    }

    setState(() => _saving = true);
    try {
      final ledgerId = ref.read(currentLedgerIdProvider);
      final repo = ref.read(repositoryProvider);
      await repo.updateBudget(
        widget.budget.id,
        amount: value,
        startDay: widget.budget.startDay,
      );

      if (mounted) {
        ref.read(budgetRefreshProvider.notifier).state++;
        unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
        showBeeToast(context, l10n.budgetSaveSuccess, tone: BeeTone.success);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l10n.commonError}: $e', tone: BeeTone.error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: OriginDialog(
        alignment: Alignment.bottomCenter,
        title: widget.categoryName,
        textAlign: TextAlign.center,
        confirmText: _saving ? '...' : l10n.commonSave,
        onConfirm: _save,
        cancelText: l10n.commonCancel,
        onCancel: () => Navigator.of(context).pop(),
        stackActions: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12.0),
            // 分类信息条
            if (widget.category != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: RecordingCategoryIcon(
                    category: widget.category!,
                    size: 32,
                  ),
                ),
              ),

            // 金额输入槽 (OriginAmountField)
            OriginAmountField(
              controller: _controller,
              currencySymbol: widget.currencySymbol,
              autofocus: true,
              clearable: true,
              borderRadius: 16.0,
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),

            // 错误提示
            if (_error != null) ...[
              const SizedBox(height: 8.0),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12.0,
                  color: OriginTokens.expenseRed,
                ),
              ),
            ],

            // 删除该分类预算入口
            const SizedBox(height: 12.0),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _saving ? null : _delete,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Center(
                  child: Text(
                    '删除分类预算',
                    style: TextStyle(
                      fontSize: 13.0,
                      color: OriginTokens.expenseRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
