import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 官方规范右上角“竖排双圆点”图标 (OriginMoreIcon)
///
/// 几何依据蓝河工具箱反编译的官方设置资源：
/// `vivo-assets/out/settings/res/drawable/originui_vtoolbar_icon_more_rom13_5.xml`
/// - 24×24 视口；
/// - 两个空心圆点：圆心坐标分别为 (12, 6.5) 与 (12, 17.5)；
/// - 外半径 4.0、内半径 2.0（以 Canvas 半径 3.0*unit、线宽 2.0*unit 绘制完美还原）；
/// - 支持主题自适应 tint 色值与尺寸缩放。
class OriginMoreIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const OriginMoreIcon({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? OriginTokens.textPrimary(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OriginMoreIconPainter(iconColor),
      ),
    );
  }
}

class _OriginMoreIconPainter extends CustomPainter {
  final Color color;

  const _OriginMoreIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * unit
      ..isAntiAlias = true;

    final centerX = size.width / 2.0;
    // 两个圆点圆心 Y 坐标：6.5 与 17.5
    for (final y in const [6.5, 17.5]) {
      canvas.drawCircle(Offset(centerX, y * unit), 3.0 * unit, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OriginMoreIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 气泡菜单条目数据模型 (OriginMenuItem)
class OriginMenuItem {
  final String title;
  final Widget? icon;
  final String? subtitle;
  final Widget? trailing;
  final bool showBadge;
  final bool isDestructive;
  final VoidCallback onTap;

  const OriginMenuItem({
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
    this.showBadge = false,
    this.isDestructive = false,
  });
}

/// vivo OriginOS 规范顶栏右上角“两个点”设置与菜单入口按钮 (OriginMoreButton)
///
/// 具备 40×40dp 标准点击热区，支持未读状态红点（Badge），
/// 点击后自动获取当前按钮的屏幕位置，并从右上角平滑呼出 OriginOS 风格气泡菜单。
class OriginMoreButton extends StatelessWidget {
  final List<OriginMenuItem> items;
  final bool showBadge;
  final Color? iconColor;
  final String? tooltip;

  const OriginMoreButton({
    super.key,
    required this.items,
    this.showBadge = false,
    this.iconColor,
    this.tooltip,
  });

  void _handleTap(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final targetRect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

    showOriginMenu(
      context: context,
      targetRect: targetRect,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(20.0),
        splashColor: OriginTokens.pressedOverlay(context),
        highlightColor: Colors.transparent,
        child: SizedBox(
          width: 40.0,
          height: 40.0,
          child: Center(
            child: OriginMoreIcon(
              size: 20.0,
              color: iconColor ?? OriginTokens.textPrimary(context),
            ),
          ),
        ),
      ),
    );

    Widget content = button;

    // 当需要展示红点时（例如个人中心有新消息/新功能更新），在两个点右上方点缀微型红点
    if (showBadge) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: 6.0,
            top: 6.0,
            child: Container(
              width: 7.0,
              height: 7.0,
              decoration: const BoxDecoration(
                color: Color(0xFFFF3636),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: content,
      );
    }
    return content;
  }
}

/// 呼出 OriginOS 风格气泡下拉菜单
Future<void> showOriginMenu({
  required BuildContext context,
  required Rect targetRect,
  required List<OriginMenuItem> items,
}) {
  return Navigator.of(context).push(
    _OriginMenuRoute(
      targetRect: targetRect,
      items: items,
    ),
  );
}

class _OriginMenuRoute extends PopupRoute<void> {
  final Rect targetRect;
  final List<OriginMenuItem> items;

  _OriginMenuRoute({
    required this.targetRect,
    required this.items,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.08);

  @override
  String? get barrierLabel => '关闭菜单';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    // 锚定在 targetRect 底部并紧贴（间距 4.0dp），移除外层 SafeArea 避免全局坐标与状态栏内边距双重叠加
    final menuTop = (targetRect.bottom + 4.0).clamp(
      topPadding + 4.0,
      screenHeight - bottomPadding - 60.0,
    );

    // 菜单右边距：与按钮右边缘保持协调一致（限制在 12.0~20.0dp 舒适区间）
    final rightMargin = (screenWidth - targetRect.right).clamp(12.0, 20.0);

    // 计算可用最大高度，防止极端屏幕或横屏下溢出
    final maxMenuHeight = (screenHeight - menuTop - bottomPadding - 16.0).clamp(120.0, double.infinity);

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.fastOutSlowIn,
      reverseCurve: const Cubic(0.4, 0.0, 1.0, 1.0),
    );

    return Stack(
      children: [
        Positioned(
          top: menuTop,
          right: rightMargin,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: ScaleTransition(
              // 关键：以气泡菜单卡片自身的右上角为中心进行缩放展开，贴合两个点按钮的右下侧
              alignment: Alignment.topRight,
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(curvedAnimation),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: OriginTokens.popupMenuMinWidth,
                    maxWidth: OriginTokens.popupMenuMaxWidth,
                    maxHeight: maxMenuHeight,
                  ),
                  decoration: BoxDecoration(
                    color: OriginTokens.surfacePopup(context),
                    borderRadius: BorderRadius.circular(OriginTokens.popupMenuRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
                        blurRadius: 16.0,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: IntrinsicWidth(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (int i = 0; i < items.length; i++) ...[
                              _OriginMenuItemWidget(item: items[i]),
                              if (i < items.length - 1)
                                Divider(
                                  height: 0.5,
                                  thickness: 0.5,
                                  indent: OriginTokens.popupMenuItemPadding,
                                  endIndent: OriginTokens.popupMenuItemPadding,
                                  color: OriginTokens.menuDivider(context),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 菜单本身的缩放与淡入已由 buildPage 内部精确绑定到卡片右上角锚点，此处直接传递 child
    return child;
  }
}

class _OriginMenuItemWidget extends StatelessWidget {
  final OriginMenuItem item;

  const _OriginMenuItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    final textPrimary = OriginTokens.textPrimary(context);
    final textSecondary = OriginTokens.textSecondary(context);
    final dangerColor = const Color(0xFFFF3636);

    final itemColor = item.isDestructive ? dangerColor : textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          item.onTap();
        },
        splashColor: OriginTokens.pressedOverlay(context),
        highlightColor: OriginTokens.pressedOverlay(context),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: OriginTokens.popupMenuItemMinHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: OriginTokens.popupMenuItemPadding,
            vertical: 10.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: 20.0,
                    color: itemColor,
                  ),
                  child: item.icon!,
                ),
                const SizedBox(width: 12.0),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: itemColor,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          fontSize: 11.0,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.showBadge) ...[
                const SizedBox(width: 8.0),
                Container(
                  width: 6.0,
                  height: 6.0,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3636),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              if (item.trailing != null) ...[
                const SizedBox(width: 8.0),
                item.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
