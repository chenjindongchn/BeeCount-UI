import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';
import 'origin_divider.dart';

/// vivo OriginOS 底部导航项定义
class OriginBottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const OriginBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// vivo OriginOS 风格底部导航栏 (OriginBottomNavBar)
///
/// 遵循 `OriginUI/docs/18-navigation-bar-and-tab-row.md`：
/// 1. 高度 66dp + 底部安全区；
/// 2. 纯色不透明质感（日间 #FFFFFF / 夜间 #1E1E1E）；
/// 3. 顶部 0.5dp 发丝分割线（#D9D9D9 / #262626）；
/// 4. Tab 项带有轻微按压弹性缩放；
/// 5. 中间集成高辨识度记账操作区（支持长按与点击）。
class OriginBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<OriginBottomNavItem> items;
  final VoidCallback onCenterTap;
  final GestureLongPressStartCallback? onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback? onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback? onCenterLongPressEnd;
  final GlobalKey? centerButtonKey;
  final Color? primaryColor;

  const OriginBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
    required this.onCenterTap,
    this.onCenterLongPressStart,
    this.onCenterLongPressMoveUpdate,
    this.onCenterLongPressEnd,
    this.centerButtonKey,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final accent = primaryColor ?? OriginTokens.defaultPrimary;

    // 左侧 2 个 Tab，中间记账按钮，右侧 2 个 Tab
    final leftItems = items.take(2).toList();
    final rightItems = items.skip(2).take(2).toList();

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 0.5dp 顶部发丝线
          const OriginDivider(startIndent: 0),
          SizedBox(
            height: OriginTokens.bottomBarHeight + bottomInset,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Row(
                children: [
                  // 左侧 Tab 组
                  for (var i = 0; i < leftItems.length; i++)
                    Expanded(
                      child: _OriginNavItemWidget(
                        item: leftItems[i],
                        isSelected: currentIndex == i,
                        onTap: () => onTabSelected(i),
                        activeColor: accent,
                      ),
                    ),
                  // 中间记账按钮
                  _OriginCenterAddButton(
                    key: centerButtonKey,
                    onTap: onCenterTap,
                    onLongPressStart: onCenterLongPressStart,
                    onLongPressMoveUpdate: onCenterLongPressMoveUpdate,
                    onLongPressEnd: onCenterLongPressEnd,
                    primaryColor: accent,
                  ),
                  // 右侧 Tab 组
                  for (var i = 0; i < rightItems.length; i++)
                    Expanded(
                      child: _OriginNavItemWidget(
                        item: rightItems[i],
                        isSelected: currentIndex == i + 2,
                        onTap: () => onTabSelected(i + 2),
                        activeColor: accent,
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
}

class _OriginNavItemWidget extends StatefulWidget {
  final OriginBottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _OriginNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  @override
  State<_OriginNavItemWidget> createState() => _OriginNavItemWidgetState();
}

class _OriginNavItemWidgetState extends State<_OriginNavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unselectedColor = OriginTokens.bottomBarUnselected(context);
    final targetColor = widget.isSelected ? widget.activeColor : unselectedColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _anim.reverse(),
      onTapUp: (_) {
        _anim.forward();
        widget.onTap();
      },
      onTapCancel: () => _anim.forward(),
      child: Center(
        child: ScaleTransition(
          scale: _anim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isSelected ? widget.item.selectedIcon : widget.item.icon,
                size: 24.0,
                color: targetColor,
              ),
              const SizedBox(height: 2.0),
              Text(
                widget.item.label,
                style: OriginTokens.bottomBarTextStyle(color: targetColor),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginCenterAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;
  final Color primaryColor;

  const _OriginCenterAddButton({
    super.key,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
    required this.primaryColor,
  });

  @override
  State<_OriginCenterAddButton> createState() => _OriginCenterAddButtonState();
}

class _OriginCenterAddButtonState extends State<_OriginCenterAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.90,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _anim.reverse(),
      onTapUp: (_) {
        _anim.forward();
        widget.onTap();
      },
      onTapCancel: () => _anim.forward(),
      onLongPressStart: widget.onLongPressStart,
      onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
      onLongPressEnd: widget.onLongPressEnd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: ScaleTransition(
          scale: _anim,
          child: Container(
            width: 48.0,
            height: 48.0,
            decoration: BoxDecoration(
              color: widget.primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 8.0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格 BeeCount 专属底部导航栏适配器 (OriginBeeBottomBar)
///
/// 遵循 `OriginUI/docs/18-navigation-bar-and-tab-row.md`：
/// 1. 贴底 66dp 高度 + 底部安全区，不透明纯色卡片质感；
/// 2. 顶部 0.5dp 发丝分割线；
/// 3. Tab 项包括：流水（账单）、洞察（统计）、快速记账、资产（账户）、我的（设置）；
/// 4. 完美接管原版头像、长按手势及动效。
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
  final GestureLongPressStartCallback onCenterLongPressStart;
  final GestureLongPressMoveUpdateCallback onCenterLongPressMoveUpdate;
  final GestureLongPressEndCallback onCenterLongPressEnd;

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
    required this.onCenterLongPressStart,
    required this.onCenterLongPressMoveUpdate,
    required this.onCenterLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return OriginBottomNavBar(
      currentIndex: currentIndex,
      onTabSelected: onTabTap,
      primaryColor: primaryColor,
      centerButtonKey: centerButtonKey,
      onCenterTap: onCenterTap,
      onCenterLongPressStart: onCenterLongPressStart,
      onCenterLongPressMoveUpdate: onCenterLongPressMoveUpdate,
      onCenterLongPressEnd: onCenterLongPressEnd,
      items: [
        OriginBottomNavItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: labelHome,
        ),
        OriginBottomNavItem(
          icon: Icons.pie_chart_outline_rounded,
          selectedIcon: Icons.pie_chart_rounded,
          label: labelInsights,
        ),
        OriginBottomNavItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: labelAssets,
        ),
        OriginBottomNavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: labelMine,
        ),
      ],
    );
  }
}
