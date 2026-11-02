import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 胶囊分段滑动指示器 (OriginSegmentedControl)
///
/// 遵循 `OriginUI/docs/18-navigation-bar-and-tab-row.md`：
/// 1. 外框高度 36dp，全圆角 18dp，内缩边距 3dp；
/// 2. 背景底色：日间 #EAEAEA / 夜间 #262626；
/// 3. 滑动药丸底色：日间 #FFFFFF (带微投影) / 夜间 #383838；
/// 4. 文字字号 14sp，选中态 SemiBold / textPrimary，未选态 Regular / textSecondary；
/// 5. 平滑滑动位移动画。
class OriginSegmentedControl<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;
  final String Function(T) labelBuilder;
  final double height;
  final TabController? tabController;

  const OriginSegmentedControl({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    required this.labelBuilder,
    this.height = OriginTokens.tabSelectorHeight,
    this.tabController,
  });

  @override
  Widget build(BuildContext context) {
    if (tabController != null) {
      final animation = tabController!.animation ?? tabController!;
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) => _buildControl(context),
      );
    }
    return _buildControl(context);
  }

  Widget _buildControl(BuildContext context) {
    final selectedIndex = items.indexOf(selectedItem);
    final count = items.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double animValue = tabController?.animation?.value ??
        (selectedIndex >= 0 ? selectedIndex.toDouble() : 0.0);
    final int activeIndex = count > 0 ? animValue.round().clamp(0, count - 1) : 0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(OriginTokens.tabSelectorPadding),
      decoration: BoxDecoration(
        color: OriginTokens.tabRowBackground(context),
        borderRadius: BorderRadius.circular(OriginTokens.tabSelectorRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final pillWidth = count > 0 ? totalWidth / count : 0.0;
          final currentPillLeft = count > 0
              ? (tabController != null
                  ? animValue.clamp(0.0, (count - 1).toDouble()) * pillWidth
                  : (selectedIndex >= 0 ? selectedIndex * pillWidth : 0.0))
              : 0.0;

          final pillChild = Container(
            decoration: BoxDecoration(
              color: OriginTokens.tabPillBackground(context),
              borderRadius: BorderRadius.circular(
                OriginTokens.tabSelectorRadius - OriginTokens.tabSelectorPadding,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3.0,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
          );

          return Stack(
            children: [
              // 浮动滑动药丸 (带微投影)
              if (tabController != null)
                Positioned(
                  left: currentPillLeft,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: pillChild,
                )
              else
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: OriginTokens.fastOutSlowIn,
                  left: currentPillLeft,
                  top: 0,
                  bottom: 0,
                  width: pillWidth,
                  child: pillChild,
                ),
              // 选项文字层
              Row(
                children: List.generate(count, (index) {
                  final item = items[index];
                  final isSelected = tabController != null
                      ? index == activeIndex
                      : index == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(item),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: OriginTokens.segmentedTextStyle(
                            context,
                            selected: isSelected,
                          ),
                          child: Text(
                            labelBuilder(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
