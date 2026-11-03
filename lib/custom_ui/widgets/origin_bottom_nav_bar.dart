import 'dart:async' show Timer;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../pages/shared/appearance/skin_animation_scope.dart';
import '../styles/origin_tokens.dart';
import 'origin_animated_nav_icon.dart';

/// vivo OriginOS 底部导航项定义
class OriginBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final OriginNavigationIconType? animatedIcon;
  final String label;

  const OriginBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    this.animatedIcon,
    required this.label,
  });
}

/// vivo OriginOS 风格分体式悬浮胶囊底栏 (OriginBottomNavBar)
///
/// 遵循蓝河工具箱 `AppBottomNavigationBar.kt` 与 `OriginAnimatedNavigationIcon.kt` 规范：
/// 1. 分体式结构：左侧三项紧凑悬浮磨砂胶囊（明细 / 洞察 / 资产）+ 右侧独立 48dp 正圆记账按钮（+）；
/// 2. 几何真值：胶囊与圆钮高 48.0dp（圆角 24.0dp），内部滑动药丸高 40.0dp（圆角 20.0dp）；
/// 3. 边距规范：距手势安全区上移至 28.0dp，左右紧凑边距 36.0dp，分体间距 10.0dp；
/// 4. 动态图标：支持 700ms 内部独立零件物理动效与原地点击重播 (`replay`)。
class OriginBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<OriginBottomNavItem> items;
  final VoidCallback onCenterTap;
  final VoidCallback? onCenterDoubleTap;
  final GestureLongPressStartCallback? onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback? onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback? onCenterLongPressEnd;
  final GlobalKey? centerButtonKey;
  final Color? primaryColor;
  final dynamic skin;

  const OriginBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
    required this.onCenterTap,
    this.onCenterDoubleTap,
    this.onCenterLongPressStart,
    this.onCenterLongPressMoveUpdate,
    this.onCenterLongPressEnd,
    this.centerButtonKey,
    this.primaryColor,
    this.skin,
  });

  @override
  State<OriginBottomNavBar> createState() => _OriginBottomNavBarState();
}

class _OriginBottomNavBarState extends State<OriginBottomNavBar> {
  int? _pressedIndex;
  double? _dragLeftPx;
  final Map<int, int> _replayCounters = <int, int>{};

  bool get _isInteracting => _pressedIndex != null;

  void _triggerTabTap(int index) {
    if (index == widget.currentIndex) {
      setState(() {
        _replayCounters[index] = (_replayCounters[index] ?? 0) + 1;
      });
    }
    widget.onTabSelected(index);
  }

  void _handlePointerDown(int index) {
    setState(() {
      _pressedIndex = index;
      _dragLeftPx = null;
    });
  }

  void _handlePointerCancel() {
    if (_pressedIndex != null || _dragLeftPx != null) {
      setState(() {
        _pressedIndex = null;
        _dragLeftPx = null;
      });
    }
  }

  void _handleHorizontalDragUpdate(
    DragUpdateDetails details,
    double totalWidth,
    int itemCount,
  ) {
    if (itemCount <= 0 || totalWidth <= 0) return;
    final itemWidth = totalWidth / itemCount;
    final localX = details.localPosition.dx.clamp(0.0, totalWidth);
    final rawLeft = (localX - itemWidth / 2).clamp(0.0, totalWidth - itemWidth);
    final targetIdx = (localX / itemWidth).floor().clamp(0, itemCount - 1);

    setState(() {
      _dragLeftPx = rawLeft;
      _pressedIndex = targetIdx;
    });
  }

  void _handleHorizontalDragEnd(int itemCount) {
    final target = _pressedIndex;
    setState(() {
      _pressedIndex = null;
      _dragLeftPx = null;
    });
    if (target != null && target >= 0 && target < itemCount) {
      _triggerTabTap(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.primaryColor ?? OriginTokens.primary(context);
    final itemCount = widget.items.length;
    if (itemCount == 0) return const SizedBox.shrink();

    final validIndex = widget.currentIndex.clamp(0, itemCount - 1);
    final activeIndex = _pressedIndex ?? validIndex;

    final capsuleBg = OriginTokens.floatingBarBackground(context);
    final borderColor = OriginTokens.floatingBarBorder(context);
    final pillColor = OriginTokens.floatingPillIndicator(context);
    final unselectedColor = OriginTokens.bottomBarUnselected(context);

    return SizedBox(
      height: OriginTokens.floatingBarHeight +
          OriginTokens.floatingBarBottomMargin +
          bottomInset,
      child: Padding(
        padding: EdgeInsets.only(
          left: OriginTokens.floatingBarHorizontalMargin,
          right: OriginTokens.floatingBarHorizontalMargin,
          bottom: bottomInset + OriginTokens.floatingBarBottomMargin,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. 左侧：三项悬浮磨砂胶囊导航栏（明细 / 洞察 / 资产）
            Expanded(
              child: AnimatedScale(
                scale: _isInteracting ? 1.025 : 1.0,
                duration: OriginTokens.pressDuration,
                curve: OriginTokens.enterCurve,
                child: Container(
                  height: OriginTokens.floatingBarHeight,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(OriginTokens.floatingBarRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.36 : 0.08),
                        blurRadius: 18.0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.18 : 0.03),
                        blurRadius: 4.0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(OriginTokens.floatingBarRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: capsuleBg,
                          borderRadius: BorderRadius.circular(
                              OriginTokens.floatingBarRadius),
                          border: Border.all(
                            color: borderColor,
                            width: 0.6,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // 兼容头部皮肤附带的底栏装饰层
                            if (widget.skin?.tabBarBuilder != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: SkinAnimationScope(
                                    child: widget.skin!.tabBarBuilder!(
                                      accent,
                                      isDark,
                                    ),
                                  ),
                                ),
                              ),

                            // 内部滑动药丸与前景导航项
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: OriginTokens.floatingBarPaddingH,
                                vertical: OriginTokens.floatingBarPaddingV,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final maxWidth = constraints.maxWidth;
                                  final itemWidth = maxWidth / itemCount;
                                  final targetLeft =
                                      _dragLeftPx ?? (itemWidth * activeIndex);

                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onHorizontalDragUpdate: (details) =>
                                        _handleHorizontalDragUpdate(
                                      details,
                                      maxWidth,
                                      itemCount,
                                    ),
                                    onHorizontalDragEnd: (_) =>
                                        _handleHorizontalDragEnd(itemCount),
                                    onHorizontalDragCancel:
                                        _handlePointerCancel,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.centerLeft,
                                      children: [
                                        // 滑动药丸指示器 (46dp 高, 23dp 圆角, 按住呈水滴微放大)
                                        AnimatedPositioned(
                                          duration: _dragLeftPx != null
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 280),
                                          curve: OriginTokens.enterCurve,
                                          left: targetLeft,
                                          top: 0,
                                          bottom: 0,
                                          width: itemWidth,
                                          child: AnimatedScale(
                                            scale:
                                                _isInteracting ? 1.06 : 1.0,
                                            duration:
                                                OriginTokens.pressDuration,
                                            curve: OriginTokens.enterCurve,
                                            child: Container(
                                              height: OriginTokens
                                                  .floatingPillHeight,
                                              decoration: BoxDecoration(
                                                color: pillColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  OriginTokens
                                                      .floatingPillRadius,
                                                ),
                                                border: _isInteracting
                                                    ? Border.all(
                                                        color: isDark
                                                            ? Colors.white
                                                                .withValues(
                                                                    alpha: 0.18)
                                                            : Colors.white
                                                                .withValues(
                                                                    alpha:
                                                                        0.85),
                                                        width: 0.8,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // 前景三项 Tab (明细 / 洞察 / 资产)
                                        Row(
                                          children: [
                                            for (var i = 0; i < itemCount; i++)
                                              Expanded(
                                                child: _OriginFloatingNavItem(
                                                  item: widget.items[i],
                                                  isSelected: activeIndex == i,
                                                  isPressed:
                                                      _pressedIndex == i,
                                                  replayTrigger:
                                                      _replayCounters[i] ?? 0,
                                                  activeColor: accent,
                                                  unselectedColor:
                                                      unselectedColor,
                                                  onTapDown: () =>
                                                      _handlePointerDown(i),
                                                  onTapUp: () {
                                                    _handlePointerCancel();
                                                    _triggerTabTap(i);
                                                  },
                                                  onTapCancel:
                                                      _handlePointerCancel,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: OriginTokens.floatingSplitGap),

            // 2. 右侧：独立悬浮 48dp 正圆记账按钮（+）
            _OriginStandaloneAddButton(
              key: widget.centerButtonKey,
              onTap: widget.onCenterTap,
              onDoubleTap: widget.onCenterDoubleTap,
              onLongPressStart: widget.onCenterLongPressStart,
              onLongPressMoveUpdate: widget.onCenterLongPressMoveUpdate,
              onLongPressEnd: widget.onCenterLongPressEnd,
              primaryColor: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginFloatingNavItem extends StatelessWidget {
  final OriginBottomNavItem item;
  final bool isSelected;
  final bool isPressed;
  final int replayTrigger;
  final Color activeColor;
  final Color unselectedColor;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _OriginFloatingNavItem({
    required this.item,
    required this.isSelected,
    required this.isPressed,
    required this.replayTrigger,
    required this.activeColor,
    required this.unselectedColor,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    final targetColor = isSelected ? activeColor : unselectedColor;
    // 对齐 OriginUI V2606A 校准：按住选中项时前景轻微放大，非选中按压时微缩
    final targetScale = isPressed
        ? (isSelected ? 1.08 : 0.94)
        : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: Center(
        child: AnimatedScale(
          scale: targetScale,
          duration: OriginTokens.pressDuration,
          curve: OriginTokens.enterCurve,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.animatedIcon != null)
                OriginAnimatedNavIcon(
                  icon: item.animatedIcon!,
                  selected: isSelected,
                  color: targetColor,
                  size: OriginTokens.floatingBarIconSize,
                  replayTrigger: replayTrigger,
                )
              else
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: OriginTokens.floatingBarIconSize,
                  color: targetColor,
                ),
              const SizedBox(height: 1.0),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textScaler: TextScaler.noScaling,
                style: OriginTokens.bottomBarTextStyle(color: targetColor)
                    .copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 右侧独立悬浮正圆记账按钮（48dp × 48dp）
class _OriginStandaloneAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final Color primaryColor;

  const _OriginStandaloneAddButton({
    super.key,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    required this.primaryColor,
  });

  @override
  State<_OriginStandaloneAddButton> createState() =>
      _OriginStandaloneAddButtonState();
}

class _OriginStandaloneAddButtonState extends State<_OriginStandaloneAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  Timer? _singleTapTimer;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: OriginTokens.pressDuration,
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _singleTapTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _handleTapUp() {
    _anim.forward();
    if (widget.onDoubleTap == null) {
      widget.onTap();
      return;
    }

    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 220)) {
      // 命中双击（拍照记账）
      _singleTapTimer?.cancel();
      _singleTapTimer = null;
      _lastTapTime = null;
      widget.onDoubleTap?.call();
    } else {
      // 首次点击，以最紧凑的 160ms 窗口等待潜在第二击，最大程度消除主操作延迟
      _lastTapTime = now;
      _singleTapTimer?.cancel();
      _singleTapTimer = Timer(const Duration(milliseconds: 160), () {
        _singleTapTimer = null;
        _lastTapTime = null;
        widget.onTap();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _anim.reverse();
      },
      onTapUp: (_) => _handleTapUp(),
      onTapCancel: () => _anim.forward(),
      onLongPressStart: (details) {
        _singleTapTimer?.cancel();
        _singleTapTimer = null;
        _lastTapTime = null;
        _anim.reverse();
        widget.onLongPressStart?.call(details);
      },
      onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
      onLongPressEnd: (details) {
        _anim.forward();
        widget.onLongPressEnd?.call(details);
      },
      child: ScaleTransition(
        scale: _anim,
        child: Container(
          width: OriginTokens.floatingBarHeight,
          height: OriginTokens.floatingBarHeight,
          decoration: BoxDecoration(
            color: widget.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withValues(alpha: 0.36),
                blurRadius: 14.0,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4.0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 24.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格 BeeCount 专属分体式底部导航栏适配器 (OriginBeeBottomBar)
///
/// 左侧悬浮胶囊承载三个核心页面：明细（账单）、洞察（统计）、资产（账户）；
/// 右侧独立悬浮正圆按钮承载：快速记账（点击抽屉 / 长按扇形菜单）。
class OriginBeeBottomBar extends StatelessWidget {
  final int currentIndex;
  final Color primaryColor;
  final bool isDark;
  final double bottomPadding;
  final String labelHome;
  final String labelInsights;
  final String labelAssets;
  final String labelMine;
  final String? avatarPath;
  final dynamic skin;
  final GlobalKey centerButtonKey;
  final ValueChanged<int> onTabTap;
  final VoidCallback onCenterTap;
  final VoidCallback? onCenterDoubleTap;
  final GestureLongPressStartCallback? onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback? onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback? onCenterLongPressEnd;

  const OriginBeeBottomBar({
    super.key,
    required this.currentIndex,
    required this.primaryColor,
    required this.isDark,
    required this.bottomPadding,
    required this.labelHome,
    required this.labelInsights,
    required this.labelAssets,
    required this.labelMine,
    this.avatarPath,
    this.skin,
    required this.centerButtonKey,
    required this.onTabTap,
    required this.onCenterTap,
    this.onCenterDoubleTap,
    this.onCenterLongPressStart,
    this.onCenterLongPressMoveUpdate,
    this.onCenterLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return OriginBottomNavBar(
      currentIndex: currentIndex,
      onTabSelected: onTabTap,
      primaryColor: primaryColor,
      skin: skin,
      centerButtonKey: centerButtonKey,
      onCenterTap: onCenterTap,
      onCenterDoubleTap: onCenterDoubleTap,
      onCenterLongPressStart: onCenterLongPressStart,
      onCenterLongPressMoveUpdate: onCenterLongPressMoveUpdate,
      onCenterLongPressEnd: onCenterLongPressEnd,
      items: [
        OriginBottomNavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          animatedIcon: OriginNavigationIconType.receipt,
          label: labelHome,
        ),
        OriginBottomNavItem(
          icon: Icons.pie_chart_outline_rounded,
          selectedIcon: Icons.pie_chart_rounded,
          animatedIcon: OriginNavigationIconType.insights,
          label: labelInsights,
        ),
        OriginBottomNavItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          animatedIcon: OriginNavigationIconType.assets,
          label: labelAssets,
        ),
      ],
    );
  }
}
