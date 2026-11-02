import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/shared/resources/category_icon_adapter.dart';
import '../../../pages/transaction/search/bindings/transaction_search.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/format_money.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_card.dart';
import 'origin_category_selector_sheet.dart';
import 'origin_date_picker.dart';
import 'origin_search_bar.dart';
import 'origin_segmented_control.dart';

/// vivo OriginOS 风格搜索筛选底部抽屉 (OriginSearchFilterSheet)
///
/// 遵循 `OriginUI/docs/15-bottom-sheet.md` 规范：
/// 1. 顶部 30dp 大圆角，实底材质，进场 400ms Cubic(0.28, 0.85, 0.36, 1.0)；
/// 2. 分类筛选采用专属高质感卡片与 OriginCategorySelectorSheet 联动；
/// 3. 收支类型采用胶囊分段滑动指示器 (OriginSegmentedControl)；
/// 4. 账户与标签采用 OriginFilterChip 流式选择；
/// 5. 金额与日期均适配 OriginUI 规范控件；
/// 6. 底部双胶囊按钮（重置 + 确认筛选）。
class OriginSearchFilterSheet extends StatefulWidget {
  final TransactionSearchFilter initial;
  final List<Account> accounts;
  final List<Tag> tags;
  final String currency;
  final int? ledgerId;

  const OriginSearchFilterSheet({
    super.key,
    required this.initial,
    required this.accounts,
    required this.tags,
    required this.currency,
    this.ledgerId,
  });

  static Future<TransactionSearchFilter?> show(
    BuildContext context, {
    required TransactionSearchFilter initial,
    required List<Account> accounts,
    required List<Tag> tags,
    required String currency,
    int? ledgerId,
  }) {
    return showOriginBottomSheet<TransactionSearchFilter?>(
      context,
      builder: (_) => OriginSearchFilterSheet(
        initial: initial,
        accounts: accounts,
        tags: tags,
        currency: currency,
        ledgerId: ledgerId,
      ),
    );
  }

  @override
  State<OriginSearchFilterSheet> createState() =>
      _OriginSearchFilterSheetState();
}

class _OriginSearchFilterSheetState extends State<OriginSearchFilterSheet> {
  late Category? _category = widget.initial.category;
  late int? _account = widget.initial.accountId;
  late int? _tag = widget.initial.tagId;
  late String? _kind = widget.initial.kind;
  late DateTime? _start = widget.initial.start;
  late DateTime? _end = widget.initial.end;
  late SearchAmountBasis _basis = widget.initial.basis;

  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.initial.minimum?.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: widget.initial.maximum?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date, AppLocalizations l) {
    if (date == null) return l.searchNotSet;
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showOriginDatePicker(
      context,
      initial: (isStart ? _start : _end) ?? DateTime.now(),
      minDate: DateTime(2000),
      maxDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _selectCategory() async {
    final picked = await OriginCategorySelectorSheet.show(
      context,
      currentCategoryId: _category?.id,
      ledgerId: widget.ledgerId,
      initialKind: _kind ?? 'all',
    );
    if (mounted) {
      setState(() {
        _category = picked;
      });
    }
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _category = null;
      _account = null;
      _tag = null;
      _kind = null;
      _start = null;
      _end = null;
      _basis = SearchAmountBasis.original;
      _minController.clear();
      _maxController.clear();
      _error = null;
    });
  }

  void _submit() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    final l = AppLocalizations.of(context);

    if ((_minController.text.trim().isNotEmpty &&
            (min == null || !min.isFinite || min < 0)) ||
        (_maxController.text.trim().isNotEmpty &&
            (max == null || !max.isFinite || max < 0)) ||
        (min != null && max != null && min > max) ||
        (_start != null && _end != null && _start!.isAfter(_end!))) {
      setState(() => _error = l.v4SearchInvalidRange);
      return;
    }

    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      TransactionSearchFilter(
        category: _category,
        accountId: _account,
        tagId: _tag,
        kind: _kind,
        minimum: min,
        maximum: max,
        start: _start,
        end: _end,
        basis: _basis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部小把手
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10.0, bottom: 8.0),
              width: 32.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.searchFilterTitle,
                  style: TextStyle(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: OriginTokens.expenseRed,
                ),
              ),
            ),
          // 筛选内容滚动列表
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                OriginTokens.cardMargin,
                0,
                OriginTokens.cardMargin,
                16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 交易类型（全部 / 支出 / 收入 / 转账）
                  _buildSectionHeader(context, '交易类型'),
                  OriginSegmentedControl<String?>(
                    items: const [null, 'expense', 'income', 'transfer'],
                    selectedItem: _kind,
                    labelBuilder: (item) {
                      if (item == null) return l.v4SearchAll;
                      if (item == 'expense') return l.exportTypeExpense;
                      if (item == 'income') return l.exportTypeIncome;
                      return l.transferTitle;
                    },
                    onSelected: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _kind = val);
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // 2. 分类筛选卡片
                  _buildSectionHeader(context, l.searchCategoryFilter),
                  OriginCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    onTap: _selectCategory,
                    child: Row(
                      children: [
                        if (_category != null)
                          CategoryIconWidget(
                            category: _category,
                            size: 20.0,
                            showBackground: true,
                            circular: true,
                          )
                        else
                          Container(
                            width: 36.0,
                            height: 36.0,
                            decoration: BoxDecoration(
                              color: OriginTokens.chipBackground(context),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.category_rounded,
                              size: 18.0,
                              color: OriginTokens.textPrimary(context),
                            ),
                          ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _category == null
                                    ? l.v4SearchAll
                                    : CategoryUtils.getDisplayName(
                                        _category!.name,
                                        context,
                                        kind: _category!.kind,
                                      ),
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: _category != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _category != null
                                      ? primaryColor
                                      : OriginTokens.textPrimary(context),
                                ),
                              ),
                              Text(
                                _category == null
                                    ? '点击选择分类范围'
                                    : '${_category!.kind == 'expense' ? l.categoryExpense : l.categoryIncome}分类',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: OriginTokens.textTertiary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_category != null)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _category = null);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18.0,
                                color: OriginTokens.textTertiary(context),
                              ),
                            ),
                          ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20.0,
                          color: OriginTokens.textTertiary(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 3. 账户筛选
                  if (widget.accounts.isNotEmpty) ...[
                    _buildSectionHeader(context, l.exportCsvHeaderAccount),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        OriginFilterChip(
                          label: l.v4SearchAll,
                          selected: _account == null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _account = null);
                          },
                        ),
                        for (final acc in widget.accounts)
                          OriginFilterChip(
                            label: acc.name,
                            selected: _account == acc.id,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _account = acc.id);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                  ],

                  // 4. 标签筛选
                  if (widget.tags.isNotEmpty) ...[
                    _buildSectionHeader(context, l.exportCsvHeaderTags),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        OriginFilterChip(
                          label: l.v4SearchAll,
                          selected: _tag == null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _tag = null);
                          },
                        ),
                        for (final t in widget.tags)
                          OriginFilterChip(
                            label: t.name,
                            selected: _tag == t.id,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _tag = t.id);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                  ],

                  // 5. 金额区间筛选
                  _buildSectionHeader(context, l.searchAmountFilter),
                  if (!globalCurrencyLocked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          OriginFilterChip(
                            label: l.v4SearchOriginalAmount,
                            selected: _basis == SearchAmountBasis.original,
                            onTap: () => setState(
                                () => _basis = SearchAmountBasis.original),
                          ),
                          const SizedBox(width: 8.0),
                          OriginFilterChip(
                            label: '${l.v4SearchLedgerAmount} (${widget.currency})',
                            selected: _basis == SearchAmountBasis.ledger,
                            onTap: () => setState(
                                () => _basis = SearchAmountBasis.ledger),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38.0,
                          decoration: BoxDecoration(
                            color: OriginTokens.searchBarBackground(context),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              fontSize: 14.0,
                              color: OriginTokens.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              hintText: l.searchMinAmount,
                              hintStyle: TextStyle(
                                fontSize: 13.0,
                                color: OriginTokens.searchBarHint(context),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          '—',
                          style: TextStyle(
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 38.0,
                          decoration: BoxDecoration(
                            color: OriginTokens.searchBarBackground(context),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(
                              fontSize: 14.0,
                              color: OriginTokens.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              hintText: l.searchMaxAmount,
                              hintStyle: TextStyle(
                                fontSize: 13.0,
                                color: OriginTokens.searchBarHint(context),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // 6. 日期区间筛选
                  _buildSectionHeader(context, l.searchDateFilter),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateChip(
                          context,
                          title: l.searchStartDate,
                          date: _start,
                          onTap: () => _pickDate(true),
                          onClear: _start != null
                              ? () => setState(() => _start = null)
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          '—',
                          style: TextStyle(
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildDateChip(
                          context,
                          title: l.searchEndDate,
                          date: _end,
                          onTap: () => _pickDate(false),
                          onClear: _end != null
                              ? () => setState(() => _end = null)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 底部操作胶囊按钮（重置 + 确认筛选）
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 16.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: InkWell(
                      onTap: _reset,
                      borderRadius:
                          BorderRadius.circular(OriginTokens.buttonRadius),
                      child: Ink(
                        height: OriginTokens.buttonHeight,
                        decoration: BoxDecoration(
                          color: OriginTokens.dialogButtonSecondary(context),
                          borderRadius:
                              BorderRadius.circular(OriginTokens.buttonRadius),
                        ),
                        child: Center(
                          child: Text(
                            '重置',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: OriginTokens.textSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _submit,
                      borderRadius:
                          BorderRadius.circular(OriginTokens.buttonRadius),
                      child: Ink(
                        height: OriginTokens.buttonHeight,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius:
                              BorderRadius.circular(OriginTokens.buttonRadius),
                        ),
                        child: Center(
                          child: Text(
                            l.commonConfirm,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w600,
          color: OriginTokens.textSecondary(context),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildDateChip(
    BuildContext context, {
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final hasDate = date != null;
    final l = AppLocalizations.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        height: 38.0,
        decoration: BoxDecoration(
          color: OriginTokens.searchBarBackground(context),
          borderRadius: BorderRadius.circular(12.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14.0,
              color: hasDate
                  ? OriginTokens.primary(context)
                  : OriginTokens.textTertiary(context),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: Text(
                hasDate ? _formatDate(date, l) : title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                  color: hasDate
                      ? OriginTokens.textPrimary(context)
                      : OriginTokens.searchBarHint(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onClear();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.0,
                    color: OriginTokens.textTertiary(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
