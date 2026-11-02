import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/shared/resources/category_icon_adapter.dart';
import '../../../pages/shared/selectors/bindings/category_selector.dart';
import '../../../providers.dart';
import '../../../utils/category_utils.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_card.dart';
import 'origin_divider.dart';
import 'origin_segmented_control.dart';

/// vivo OriginOS 风格分类选择底部抽屉
///
/// 遵循蓝河工具箱 `OriginUI/docs/15-bottom-sheet.md` 动效真值：
/// - 自底向上以 Cubic(0.28, 0.85, 0.36, 1.0) 曲线滑出；
/// - 顶部 30dp 大圆角，实底材质，支持下滑跟手退出；
/// - 支持支出/收入分段切换，展示分类彩色图标、层级名称与交易笔数。
class OriginCategorySelectorSheet extends ConsumerStatefulWidget {
  final int? currentCategoryId;
  final int? ledgerId;
  final String initialKind; // 'all', 'expense', 'income'

  const OriginCategorySelectorSheet({
    super.key,
    this.currentCategoryId,
    this.ledgerId,
    this.initialKind = 'all',
  });

  static Future<Category?> show(
    BuildContext context, {
    int? currentCategoryId,
    int? ledgerId,
    String initialKind = 'all',
  }) {
    return showOriginBottomSheet<Category?>(
      context,
      builder: (_) => OriginCategorySelectorSheet(
        currentCategoryId: currentCategoryId,
        ledgerId: ledgerId,
        initialKind: initialKind,
      ),
    );
  }

  @override
  ConsumerState<OriginCategorySelectorSheet> createState() =>
      _OriginCategorySelectorSheetState();
}

class _OriginCategorySelectorSheetState
    extends ConsumerState<OriginCategorySelectorSheet> {
  late String _selectedTab; // 'all', 'expense', 'income'
  CategorySelectorData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialKind == 'income' ? 'income' : 'expense';
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(repositoryProvider);
    final data = await loadCategorySelectorData(
      repo,
      ledgerId: widget.ledgerId,
      onlyTopLevel: false,
      showTransactionCount: true,
    );
    if (mounted) {
      setState(() {
        _data = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = _data?.categories.where((c) {
          if (_selectedTab == 'expense') return c.kind == 'expense';
          if (_selectedTab == 'income') return c.kind == 'income';
          return true;
        }).toList() ??
        [];

    // 分离一级分类与其对应子分类
    final topLevel = categories.where((c) => c.parentId == null).toList();
    final childMap = <int, List<Category>>{};
    for (final c in categories.where((c) => c.parentId != null)) {
      childMap.putIfAbsent(c.parentId!, () => []).add(c);
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.searchCategoryFilter,
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
          // 收支类型切换器
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
            ),
            child: OriginSegmentedControl<String>(
              items: const ['expense', 'income'],
              selectedItem: _selectedTab,
              labelBuilder: (item) =>
                  item == 'expense' ? l.categoryExpense : l.categoryIncome,
              onSelected: (val) {
                HapticFeedback.lightImpact();
                setState(() => _selectedTab = val);
              },
            ),
          ),
          const SizedBox(height: 12.0),
          // “全部分类”清除选项
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
            ),
            child: OriginCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                // 返回 null 表示选择全部分类
                Navigator.pop(context, null);
              },
              child: Row(
                children: [
                  Container(
                    width: 36.0,
                    height: 36.0,
                    decoration: BoxDecoration(
                      color: OriginTokens.chipBackground(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.apps_rounded,
                      size: 18.0,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      l.v4SearchAll,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  if (widget.currentCategoryId == null)
                    Icon(
                      Icons.check_rounded,
                      size: 20.0,
                      color: OriginTokens.primary(context),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          // 分类列表区域
          Expanded(
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 24.0,
                      height: 24.0,
                      child: CircularProgressIndicator(strokeWidth: 2.0),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      OriginTokens.cardMargin,
                      0,
                      OriginTokens.cardMargin,
                      24.0,
                    ),
                    itemCount: topLevel.length,
                    itemBuilder: (context, index) {
                      final parent = topLevel[index];
                      final children = childMap[parent.id] ?? [];
                      final parentName = CategoryUtils.getDisplayName(
                        parent.name,
                        context,
                        kind: parent.kind,
                      );
                      final isParentSelected =
                          widget.currentCategoryId == parent.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: OriginCard(
                          margin: EdgeInsets.zero,
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 一级分类行
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context, parent);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 12.0,
                                  ),
                                  child: Row(
                                    children: [
                                      CategoryIconWidget(
                                        category: parent,
                                        size: 20.0,
                                        showBackground: true,
                                        circular: true,
                                      ),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          parentName,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.w600,
                                            color: OriginTokens.textPrimary(
                                                context),
                                          ),
                                        ),
                                      ),
                                      if (_data?.counts[parent.id] != null &&
                                          _data!.counts[parent.id]! > 0)
                                        Text(
                                          '${_data!.counts[parent.id]}笔',
                                          style: TextStyle(
                                            fontSize: 12.0,
                                            color: OriginTokens.textTertiary(
                                                context),
                                          ),
                                        ),
                                      if (isParentSelected) ...[
                                        const SizedBox(width: 8.0),
                                        Icon(
                                          Icons.check_rounded,
                                          size: 18.0,
                                          color: OriginTokens.primary(context),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // 子分类网格/列表
                              if (children.isNotEmpty) ...[
                                const OriginDivider(startIndent: 48.0),
                                for (int i = 0; i < children.length; i++) ...[
                                  _buildChildRow(
                                    context,
                                    children[i],
                                    widget.currentCategoryId == children[i].id,
                                  ),
                                  if (i < children.length - 1)
                                    const OriginDivider(startIndent: 48.0),
                                ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildRow(BuildContext context, Category child, bool selected) {
    final name = CategoryUtils.getDisplayName(
      child.name,
      context,
      kind: child.kind,
    );

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context, child);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48.0, 10.0, 16.0, 10.0),
        child: Row(
          children: [
            CategoryIconWidget(
              category: child,
              size: 16.0,
              showBackground: false,
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14.0,
                  color: selected
                      ? OriginTokens.primary(context)
                      : OriginTokens.textSecondary(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (_data?.counts[child.id] != null && _data!.counts[child.id]! > 0)
              Text(
                '${_data!.counts[child.id]}笔',
                style: TextStyle(
                  fontSize: 12.0,
                  color: OriginTokens.textTertiary(context),
                ),
              ),
            if (selected) ...[
              const SizedBox(width: 8.0),
              Icon(
                Icons.check_rounded,
                size: 18.0,
                color: OriginTokens.primary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
