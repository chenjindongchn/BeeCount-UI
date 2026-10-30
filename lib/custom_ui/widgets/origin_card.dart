import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 分组卡片组件 (OriginCard)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md`：
/// 1. 圆角为 12.0dp；
/// 2. 横向边距默认为 20.0dp；
/// 3. 采用纯色不透明卡片底色（日间 #FFFFFF / 夜间 #202020）；
/// 4. 具备触碰反馈与轻微按压弹性（有点击回调时）。
class OriginCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;

  const OriginCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.color,
    this.radius = OriginTokens.cardRadius,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  State<OriginCard> createState() => _OriginCardState();
}

class _OriginCardState extends State<OriginCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: OriginTokens.pressDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveMargin = widget.margin ??
        const EdgeInsets.symmetric(
          horizontal: OriginTokens.cardMargin,
          vertical: 6.0,
        );
    final effectivePadding =
        widget.padding ?? const EdgeInsets.all(OriginTokens.cardInnerPadding);
    final cardBg = widget.color ?? OriginTokens.cardBackground(context);

    Widget content = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      clipBehavior: widget.clipBehavior,
      padding: effectivePadding,
      child: widget.child,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      content = GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: content,
        ),
      );
    }

    return Padding(
      padding: effectiveMargin,
      child: content,
    );
  }
}

/// vivo OriginOS 分组小节标题 (OriginSectionTitle)
///
/// 遵循 `OriginUI/docs/12-icons-and-section-title.md` 与 `13`:
/// 横向外边距 20dp，与卡片左边缘严格垂向对齐。
class OriginSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const OriginSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(
      OriginTokens.cardMargin,
      16.0,
      OriginTokens.cardMargin,
      6.0,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: OriginTokens.textSecondary(context),
              letterSpacing: 0.2,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
