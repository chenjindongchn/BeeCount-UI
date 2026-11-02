import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart' show BeeAction;
import '../styles/origin_tokens.dart';

/// Origin 风格右下角加号扇形快捷菜单（极简纯图标紧凑版）
///
/// 1. 紧凑尺寸：去除了文字说明，采用 42dp 精致小圆按钮；
/// 2. 紧贴加号：展开半径收紧至约 64dp，大拇指微动即可灵敏切换；
/// 3. 原点精准对齐：展开原点锁定在右下角加号中心，顺滑过渡。
class OriginQuickAddFan extends StatelessWidget {
  final Offset buttonCenter;
  final Size buttonSize;
  final List<BeeAction> actions;
  final String? title;
  final String? hint;
  final String cancelLabel;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final Set<String> disabled;
  final int? hoveredIndex;
  final double progress;

  const OriginQuickAddFan({
    super.key,
    required this.buttonCenter,
    this.buttonSize = const Size(48, 48),
    required this.actions,
    this.title,
    this.hint,
    this.cancelLabel = '关闭',
    required this.onSelected,
    required this.onDismiss,
    this.disabled = const {},
    this.hoveredIndex,
    this.progress = 1.0,
  });

  /// 紧凑版扇形展开偏移量（收紧展开半径至 64dp 左右）
  static List<Offset> getOffsets(Offset buttonCenter, Size viewport) {
    if (buttonCenter.dx > viewport.width * 0.5) {
      // 按钮在屏幕右侧：向左上方紧凑展开
      return const [
        Offset(-64, -14), // 拍照（偏左）
        Offset(-46, -46), // 相册（正左上方 45°）
        Offset(-14, -64), // 语音（偏上方）
      ];
    } else if (buttonCenter.dx < viewport.width * 0.3) {
      // 按钮在屏幕左侧：向右上方紧凑展开
      return const [
        Offset(14, -64),
        Offset(46, -46),
        Offset(64, -14),
      ];
    } else {
      // 居中按钮：向上方三向紧凑展开
      return const [
        Offset(-68, -40),
        Offset(0, -78),
        Offset(68, -40),
      ];
    }
  }

  /// 获取指定选项在当前展开进度下的全局中心点坐标
  static Offset centerFor(
    Offset buttonCenter,
    int index,
    Size viewport, {
    double progress = 1.0,
  }) {
    final offsets = getOffsets(buttonCenter, viewport);
    if (index < 0 || index >= offsets.length) return buttonCenter;
    return buttonCenter + offsets[index] * progress;
  }

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    if (p == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);
    final viewport = MediaQuery.sizeOf(context);
    final offsets = getOffsets(buttonCenter, viewport);

    // 加号正圆尺寸（通常为 48dp）
    final btnWidth = buttonSize.width > 0 ? buttonSize.width : 48.0;
    final btnHeight = buttonSize.height > 0 ? buttonSize.height : 48.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 1. 全局轻量毛玻璃遮罩 + 点击背景收起
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3 * p, sigmaY: 3 * p),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.22 * p),
                ),
              ),
            ),
          ),

          // 2. 展开的三个纯图标按钮（拍照、相册、语音，无多余文字标签）
          for (var i = 0; i < actions.length && i < offsets.length; i++) ...[
            _buildActionIcon(
              context: context,
              action: actions[i],
              index: i,
              center: centerFor(buttonCenter, i, viewport, progress: p),
              progress: p,
              isHovered: i == hoveredIndex,
              isDisabled: disabled.contains(actions[i].id),
              primaryColor: primaryColor,
              isDark: isDark,
            ),
          ],

          // 3. 原点覆盖按钮（精确位于原加号位置，加号顺滑旋转 45° 变成叉号）
          Positioned(
            left: buttonCenter.dx - btnWidth / 2,
            top: buttonCenter.dy - btnHeight / 2,
            width: btnWidth,
            height: btnHeight,
            child: Transform.rotate(
              angle: p * math.pi / 4, // 旋转 45° 变成叉号
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建纯图标圆形按钮（无文字说明，尺寸缩至 42x42）
  Widget _buildActionIcon({
    required BuildContext context,
    required BeeAction action,
    required int index,
    required Offset center,
    required double progress,
    required bool isHovered,
    required bool isDisabled,
    required Color primaryColor,
    required bool isDark,
  }) {
    const itemSize = 42.0;
    final scale = progress * (isHovered ? 1.16 : 1.0);
    final cardBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Positioned(
      left: center.dx - itemSize / 2,
      top: center.dy - itemSize / 2,
      width: itemSize,
      height: itemSize,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: progress,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isDisabled ? null : () => onSelected(action.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isHovered ? primaryColor : cardBg,
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? primaryColor.withValues(alpha: 0.42)
                        : Colors.black.withValues(alpha: 0.12),
                    blurRadius: isHovered ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    size: 21,
                    color: isDisabled
                        ? Colors.grey
                        : isHovered
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                  ),
                  child: action.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
