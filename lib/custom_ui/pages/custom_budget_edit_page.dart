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
import '../../utils/currencies.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_amount_field.dart';
import '../widgets/origin_dialog.dart';

/// vivo OriginOS 风格预算编辑/添加页面 (CustomBudgetEditPage)
class CustomBudgetEditPage extends ConsumerStatefulWidget {
  final Budget? budget;
  final bool isCategory;

  const CustomBudgetEditPage({
    super.key,
    this.budget,
    this.isCategory = false,
  });

  @override
  ConsumerState<CustomBudgetEditPage> createState() =>
      _CustomBudgetEditPageState();
}

class _CustomBudgetEditPageState extends ConsumerState<CustomBudgetEditPage> {
  late final TextEditingController _amountController;
  late final int _ledgerId;
  late String _type;
  Category? _selectedCategory;
  bool _loading = true;
  bool _saving = false;
  bool _totalUnavailable = false;
  String? _loadError;
  String? _amountError;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _type = widget.budget?.type ?? (widget.isCategory ? 'category' : 'total');
    _amountController = TextEditingController(
      text: widget.budget?.amount != null
          ? widget.budget!.amount.toStringAsFixed(
              widget.budget!.amount.truncateToDouble() == widget.budget!.amount
                  ? 0
                  : 2,
            )
          : '',
    );
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final categories = await repo.getAllCategories();
      final total =
          widget.budget == null ? await repo.getTotalBudget(_ledgerId) : null;
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = categories
            .where((c) => c.id == widget.budget?.categoryId)
            .firstOrNull;
        _totalUnavailable = total != null;
        if (_totalUnavailable && _type == 'total') {
          _type = 'category';
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickCategory() async {
    if (_saving || _loading || widget.budget != null) return;
    final l10n = AppLocalizations.of(context);
    final selected = await showBeeSheet<Category>(
      context,
      title: l10n.budgetCategoryLabel,
      child: BeeChoicePicker<Category>(
        items: _categories
            .where((c) => c.kind == 'expense' && c.parentId == null)
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
      setState(() => _selectedCategory = selected);
    }
  }

  Future<void> _guardWrite() async {
    if (ref.read(currentLedgerIdProvider) != _ledgerId ||
        (widget.budget != null && widget.budget!.ledgerId != _ledgerId)) {
      throw StateError('Budget ledger changed');
    }
    final ledger = await ref.read(currentLedgerProvider.future);
    if (ledger != null && ledger.isShared && ledger.myRole != 'owner') {
      throw StateError('Budget is owner-only');
    }
  }

  void _saved(String message) {
    ref.read(budgetRefreshProvider.notifier).state++;
    unawaited(PostProcessor.sync(ref, ledgerId: _ledgerId));
    showBeeToast(context, message, tone: BeeTone.success);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    final l10n = AppLocalizations.of(context);
    final raw =
        BeeDecimalInputFormatter.normalize(_amountController.text.trim());
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) {
      setState(() => _amountError = l10n.budgetAmountHint);
      return;
    }
    if (_type == 'category' && _selectedCategory == null) {
      showBeeToast(context, l10n.budgetCategoryHint, tone: BeeTone.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _guardWrite();
      if (!mounted) return;
      final repo = ref.read(repositoryProvider);
      final existing = widget.budget;
      if (existing != null) {
        await repo.updateBudget(
          existing.id,
          amount: value,
          startDay: existing.startDay,
        );
      } else {
        await repo.createBudget(
          ledgerId: _ledgerId,
          type: _type,
          categoryId: _selectedCategory?.id,
          amount: value,
          startDay: 1,
        );
      }
      if (mounted) _saved(l10n.budgetSaveSuccess);
    } catch (error) {
      if (mounted) {
        showBeeToast(
          context,
          '${l10n.commonError}: $error',
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || _loading || widget.budget == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l10n.commonDelete,
      message: l10n.budgetDeleteConfirm,
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDanger: true,
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await _guardWrite();
      if (!mounted) return;
      await ref.read(repositoryProvider).deleteBudget(widget.budget!.id);
      if (mounted) _saved(l10n.budgetDeleteSuccess);
    } catch (error) {
      if (mounted) {
        showBeeToast(
          context,
          '${l10n.commonError}: $error',
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final ledger = ref.watch(currentLedgerProvider).asData?.value;
    final currencySymbol = getCurrencySymbol(ledger?.currency ?? 'CNY');
    final permitted =
        ledger == null || !ledger.isShared || ledger.myRole == 'owner';

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: widget.budget == null
            ? l10n.budgetAddTitle
            : l10n.budgetEditTitle,
        leading: BackButton(
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
        actions: [
          if (widget.budget != null && permitted)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: l10n.commonDelete,
              onPressed: _saving || _loading ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.commonError}: $_loadError',
                        style: TextStyle(
                          color: OriginTokens.expenseRed,
                          fontSize: 14.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: Text(l10n.v4RecordingRetry),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(
                    top: 12.0,
                    bottom: 24.0,
                  ),
                  children: [
                    // 1. 预算类型切换 (总预算 / 分类预算)
                    if (widget.budget == null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OriginTokens.cardMargin,
                        ),
                        child: OriginSegmentedControl<String>(
                          items: _totalUnavailable
                              ? ['category']
                              : ['total', 'category'],
                          selectedItem: _type,
                          labelBuilder: (t) => t == 'total'
                              ? l10n.budgetTypeTotalLabel
                              : l10n.budgetTypeCategoryLabel,
                          onSelected: (t) {
                            setState(() {
                              _type = t;
                              _amountError = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 6.0),
                    ],

                    // 2. 表单主卡片
                    OriginCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 分类选择行（仅分类预算展示）
                          if (_type == 'category') ...[
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.budget == null ? _pickCategory : null,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    if (_selectedCategory != null) ...[
                                      RecordingCategoryIcon(
                                        category: _selectedCategory!,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10.0),
                                    ] else ...[
                                      Icon(
                                        Icons.category_outlined,
                                        size: 22.0,
                                        color: OriginTokens.textTertiary(context),
                                      ),
                                      const SizedBox(width: 10.0),
                                    ],
                                    Expanded(
                                      child: Text(
                                        _selectedCategory != null
                                            ? CategoryUtils.getDisplayName(
                                                _selectedCategory!.name,
                                                context,
                                              )
                                            : l10n.budgetCategoryHint,
                                        style: TextStyle(
                                          fontSize: 15.0,
                                          color: _selectedCategory != null
                                              ? OriginTokens.textPrimary(context)
                                              : OriginTokens.textTertiary(
                                                  context),
                                        ),
                                      ),
                                    ),
                                    if (widget.budget == null)
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
                            const OriginDivider(startIndent: 0),
                            const SizedBox(height: 10.0),
                          ],

                          // 预算金额输入行
                          Text(
                            l10n.budgetAmountLabel,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: OriginTokens.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 6.0),
                          OriginAmountField(
                            controller: _amountController,
                            currencySymbol: currencySymbol,
                            showBackground: false,
                            clearable: true,
                            onChanged: (_) {
                              if (_amountError != null) {
                                setState(() => _amountError = null);
                              }
                            },
                          ),
                          if (_amountError != null) ...[
                            const SizedBox(height: 6.0),
                            Text(
                              _amountError!,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: OriginTokens.expenseRed,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
      // 底部常驻 OriginUI 规范胶囊大按钮 (46dp高度 / 23dp圆角)
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
                  borderRadius:
                      BorderRadius.circular(OriginTokens.buttonRadius),
                ),
              ),
              onPressed: _saving || _loading || _loadError != null || !permitted
                  ? null
                  : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l10n.commonSave,
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
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
