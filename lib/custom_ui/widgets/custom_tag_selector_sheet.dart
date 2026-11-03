import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/tag_providers.dart';
import '../pages/custom_tag_edit_page.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_divider.dart';
import 'origin_search_bar.dart';

/// vivo OriginOS 风格标签选择底部抽屉组件 (CustomTagSelectorSheet)
///
/// 特性与规范：
/// 1. 顶部大圆角 (30dp)、药丸手柄、实底中性材质，遵循 OriginSheetTokens；
/// 2. 居中标题对齐 OriginUI 规范 (17sp SemiBold)，移除搜索框及多选冗余提示，聚焦高效；
/// 3. 每个标签采用高质感 OriginFilterChip 胶囊样式，左侧点缀标签色彩圆点，支持多选切换；
/// 4. 底部大胶囊操作按钮一行一个纵向依次排列（主操作“确定”在上、次操作“新建”在下），高 46dp、圆角 23dp，带轻触触感反馈与微缩放动效；
/// 5. 新建标签直接联动 CustomTagEditPage，创建成功后自动加入当前选择并实时响应式刷新列表。
class CustomTagSelectorSheet extends ConsumerStatefulWidget {
  const CustomTagSelectorSheet({
    super.key,
    this.selectedTagIds = const [],
    this.onConfirm,
  });

  /// 初始选中的标签 ID 列表
  final List<int> selectedTagIds;

  /// 确认选择回调
  final ValueChanged<List<int>>? onConfirm;

  /// 调起标签选择底部抽屉
  static Future<List<int>?> show(
    BuildContext context, {
    List<int> selectedTagIds = const [],
    ValueChanged<List<int>>? onConfirm,
  }) {
    return showOriginBottomSheet<List<int>>(
      context,
      builder: (ctx) => CustomTagSelectorSheet(
        selectedTagIds: selectedTagIds,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  ConsumerState<CustomTagSelectorSheet> createState() =>
      _CustomTagSelectorSheetState();
}

class _CustomTagSelectorSheetState
    extends ConsumerState<CustomTagSelectorSheet> {
  late final Set<int> _selectedIds = {...widget.selectedTagIds};

  /// 解析标签十六进制颜色
  Color _parseTagColor(Tag tag, BuildContext context) {
    final hex = tag.color?.replaceFirst('#', '');
    final parsed = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'ff$hex' : hex, radix: 16);
    return parsed == null
        ? OriginTokens.primary(context)
        : Color(parsed);
  }

  /// 跳转新建标签页面
  Future<void> _createNewTag() async {
    HapticFeedback.lightImpact();
    final tag = await Navigator.push<Tag>(
      context,
      MaterialPageRoute(builder: (_) => const CustomTagEditPage()),
    );
    if (!mounted) return;
    if (tag != null) {
      setState(() => _selectedIds.add(tag.id));
      ref.read(tagListRefreshProvider.notifier).state++;
    }
  }

  /// 确认当前选择并退出
  void _confirmSelection(Set<int>? visibleIds, bool canCreate) {
    HapticFeedback.lightImpact();
    // 保留未解析的 Owner 虚拟合成 ID；移除当前协作者无权查看的历史个人私有 ID
    final selected = _selectedIds
        .where((id) => canCreate || id < 0 || (visibleIds != null && visibleIds.contains(id)))
        .toList();

    widget.onConfirm?.call(selected);
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);

    final allAsync = ref.watch(tagsForCurrentLedgerProvider).unwrapPrevious();
    final recentAsync =
        ref.watch(recentTagsForCurrentLedgerProvider).unwrapPrevious();
    final canCreate = ref.watch(canCreateTagForCurrentLedgerProvider);

    final allTags = allAsync.valueOrNull ?? <Tag>[];
    final visibleIds = allAsync.valueOrNull?.map((t) => t.id).toSet();
    final recentTags = (recentAsync.valueOrNull ?? <Tag>[])
        .where((tag) => visibleIds?.contains(tag.id) == true)
        .toList();

    // 弹窗最大高度限制在屏幕高度的 68%
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.68;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: OriginSheetTokens.cardColor(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OriginSheetTokens.cornerRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部药丸手柄
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                width: OriginSheetTokens.dragHandleWidth,
                height: OriginSheetTokens.dragHandleHeight,
                decoration: BoxDecoration(
                  color: OriginSheetTokens.dragHandleColor(context),
                  borderRadius:
                      BorderRadius.circular(OriginSheetTokens.dragHandleRadius),
                ),
              ),
            ),

            // 2. 居中标题栏（严格对齐 OriginUI 规范：17sp SemiBold，居中排版）
            SizedBox(
              height: 48.0,
              child: Center(
                child: Text(
                  l10n.tagSelectTitle,
                  style: TextStyle(
                    fontSize: OriginSheetTokens.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),

            const OriginDivider(),

            // 3. 标签列表内容区域（去除了搜索框，纯粹平铺展示）
            Flexible(
              child: _buildBodyContent(
                context,
                l10n: l10n,
                allAsync: allAsync,
                allTags: allTags,
                recentTags: recentTags,
                canCreate: canCreate,
              ),
            ),

            const OriginDivider(),

            // 4. 底部操作胶囊按钮区：一行一个大胶囊按钮，纵向堆叠依次摆开
            Padding(
              padding: EdgeInsets.fromLTRB(
                20.0,
                12.0,
                20.0,
                MediaQuery.paddingOf(context).bottom + 12.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 主操作按钮：确定
                  _TagSheetActionButton(
                    text: '确定',
                    backgroundColor: primaryColor,
                    textColor: Colors.white,
                    isPrimary: true,
                    onPressed: () =>
                        _confirmSelection(visibleIds, canCreate),
                  ),
                  const SizedBox(height: 10.0),

                  // 次操作按钮：新建
                  _TagSheetActionButton(
                    text: '新建',
                    icon: Icons.add_rounded,
                    backgroundColor:
                        OriginTokens.dialogButtonSecondary(context),
                    textColor: canCreate
                        ? OriginTokens.textPrimary(context)
                        : OriginTokens.textTertiary(context),
                    onPressed: canCreate ? _createNewTag : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建内容区域视图
  Widget _buildBodyContent(
    BuildContext context, {
    required AppLocalizations l10n,
    required AsyncValue<List<Tag>> allAsync,
    required List<Tag> allTags,
    required List<Tag> recentTags,
    required bool canCreate,
  }) {
    if (allAsync.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (allAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.commonError,
                style: const TextStyle(
                  fontSize: 14.0,
                  color: OriginTokens.expenseRed,
                ),
              ),
              const SizedBox(height: 8.0),
              TextButton(
                onPressed: () => ref.invalidate(tagsForCurrentLedgerProvider),
                child: Text(l10n.v4RecordingRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (allTags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 38.0,
                color: OriginTokens.textTertiary(context),
              ),
              const SizedBox(height: 10.0),
              Text(
                l10n.tagManageEmpty,
                style: TextStyle(
                  fontSize: 14.0,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
              if (!canCreate) ...[
                const SizedBox(height: 4.0),
                Text(
                  l10n.tagSelectOwnerManaged,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: OriginTokens.summaryText(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 最近使用标签分组
          if (recentTags.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                l10n.tagSelectRecentlyUsed,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: OriginTokens.summaryText(context),
                ),
              ),
            ),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: recentTags.map(_buildTagChip).toList(),
            ),
            const SizedBox(height: 16.0),
          ],

          // 全部标签分组
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              recentTags.isNotEmpty ? l10n.tagSelectAllTags : '所有标签',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: OriginTokens.summaryText(context),
              ),
            ),
          ),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: allTags.map(_buildTagChip).toList(),
          ),

          if (!canCreate) ...[
            const SizedBox(height: 14.0),
            Text(
              l10n.tagSelectOwnerManaged,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.0,
                color: OriginTokens.summaryText(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建单个标签胶囊 Chip
  Widget _buildTagChip(Tag tag) {
    final isSelected = _selectedIds.contains(tag.id);
    final tagColor = _parseTagColor(tag, context);

    return OriginFilterChip(
      label: tag.name,
      selected: isSelected,
      leading: Container(
        width: 7.0,
        height: 7.0,
        decoration: BoxDecoration(
          color: tagColor,
          shape: BoxShape.circle,
        ),
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedIds.remove(tag.id);
          } else {
            _selectedIds.add(tag.id);
          }
        });
      },
    );
  }
}

/// 标签抽屉底部定制大胶囊操作按钮（高度 46dp，圆角 23dp，独占一行）
class _TagSheetActionButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _TagSheetActionButton({
    required this.text,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
    this.isPrimary = false,
    this.onPressed,
  });

  @override
  State<_TagSheetActionButton> createState() => _TagSheetActionButtonState();
}

class _TagSheetActionButtonState extends State<_TagSheetActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: OriginTokens.buttonHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16.0,
                  color: widget.textColor,
                ),
                const SizedBox(width: 4.0),
              ],
              Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight:
                      widget.isPrimary ? FontWeight.w600 : FontWeight.w500,
                  color: widget.textColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
