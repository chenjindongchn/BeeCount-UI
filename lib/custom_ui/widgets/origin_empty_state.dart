import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格统一空状态组件 (OriginEmptyState)
///
/// 解决全应用空状态体验不统一、位置偏上或偏下的核心问题：
/// 1. 统一视觉语言：精致微透明圆形底座 (80dp) + 40dp 线性图标 + 16sp SemiBold 标题 + 13sp 辅助描述；
/// 2. 黄金视觉居中：综合考虑顶部标题栏高度与底部导航条 (bottomNavigationBar / TabBar) 的占位避让，
///    配合向上 16~24dp 的视觉心理中心微调，消除“坠底偏下”或“顶格偏上”的问题；
/// 3. 支持内嵌操作按钮 (action) 或纯信息引导展示。
class OriginEmptyState extends StatelessWidget {
  /// 主图标或自定义 Widget
  final Widget? icon;

  /// 便捷传入 IconData
  final IconData? iconData;

  /// 主标题（如“暂无标签”、“暂无资产账户”）
  final String title;

  /// 次级辅助描述或操作引导文案
  final String? message;

  /// 可选的操作按钮（建议当页面无底部常驻按钮时使用）
  final Widget? action;

  /// 底部避让高度（例如处于主页 Tab 时避让悬浮底栏，默认 0）
  final double bottomSpacing;

  /// 黄金视觉中心向上偏移量（默认 20dp，使视觉重心更舒适自然）
  final double visualOffset;

  /// 图标底座圆形尺寸
  final double circleSize;

  /// 图标大小
  final double iconSize;

  const OriginEmptyState({
    super.key,
    this.icon,
    this.iconData,
    required this.title,
    this.message,
    this.action,
    this.bottomSpacing = 0.0,
    this.visualOffset = 20.0,
    this.circleSize = 80.0,
    this.iconSize = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget iconWidget;
    if (icon != null) {
      iconWidget = icon!;
    } else {
      iconWidget = Icon(
        iconData ?? Icons.inbox_outlined,
        size: iconSize,
        color: OriginTokens.textTertiary(context),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. 圆形浅色底座
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            alignment: Alignment.center,
            child: iconWidget,
          ),
          const SizedBox(height: 16.0),

          // 2. 主标题
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              color: OriginTokens.textPrimary(context),
              letterSpacing: 0.2,
            ),
          ),

          // 3. 次级提示
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 7.0),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
                color: OriginTokens.textTertiary(context),
                height: 1.4,
              ),
            ),
          ],

          // 4. 操作按钮插槽
          if (action != null) ...[
            const SizedBox(height: 20.0),
            action!,
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 如果高度未受约束（如放在非 Expanded 的 ListView 中）
        if (!constraints.hasBoundedHeight) {
          return Padding(
            padding: EdgeInsets.only(
              top: 56.0,
              bottom: 56.0 + bottomSpacing,
            ),
            child: Center(child: content),
          );
        }

        // 真实视口计算：扣除底部导航避让后，将内容置于视觉舒适中心
        final availableHeight = constraints.maxHeight;
        final targetBottomPadding = bottomSpacing;
        final netHeight = availableHeight - targetBottomPadding;

        return SizedBox(
          width: double.infinity,
          height: availableHeight,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: targetBottomPadding + (netHeight > 240 ? visualOffset : 0),
            ),
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }
}
