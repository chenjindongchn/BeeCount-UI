import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/origin_tokens.dart';
import 'origin_divider.dart';

/// vivo OriginOS 页面脚手架与标题栏系统 (OriginScaffold & OriginTopAppBar)
///
/// 遵循 `OriginUI/docs/02-top-app-bar-and-scaffold.md`：
/// 1. 规避双重 Inset 叠加 Bug：顶部由 AppBar 消费状态栏，底部保证有列表滑至末尾的安全边距；
/// 2. 大标题（84dp/22sp SemiBold）与紧凑小标题（56dp/15sp Medium）；
/// 3. 日间 #F4F4F6 浅灰 / 夜间 #000000 纯黑底色；
/// 4. 发丝分割线（0.5dp）优雅分离；
/// 5. 支持标题展开下拉指示标记（showDropdown）与标题点击反馈（onTitleTap）。
class OriginScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  const OriginScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? OriginTokens.pageBackground(context),
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// vivo OriginOS 官方规范大标题栏 (OriginLargeTopAppBar)
///
/// 最小高度 84dp + 状态栏高度，页面主标题 22sp SemiBold。
/// 支持传入 [showDropdown] 展示右侧展开标记，以及 [onTitleTap] 响应点击（附带轻触觉反馈）。
class OriginLargeTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showDivider;
  final Color? backgroundColor;
  final VoidCallback? onTitleTap;
  final bool showDropdown;

  const OriginLargeTopAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showDivider = false,
    this.backgroundColor,
    this.onTitleTap,
    this.showDropdown = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(OriginTokens.largeTitleHeight);

  Widget _buildTitleWidget(BuildContext context) {
    final titleText = Text(
      title,
      style: OriginTokens.largeTitleStyle(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!showDropdown && onTitleTap == null) {
      return titleText;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: titleText),
        if (showDropdown) ...[
          const SizedBox(width: 4.0),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20.0,
            color: OriginTokens.textSecondary(context),
          ),
        ],
      ],
    );

    if (onTitleTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTitleTap!();
        },
        child: content,
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bg = backgroundColor ?? OriginTokens.pageBackground(context);

    return Container(
      color: bg,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OriginTokens.cardMargin),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 8.0),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleWidget(context),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3.0),
                          Text(
                            subtitle!,
                            style: OriginTokens.subtitleStyle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
          if (showDivider) const OriginDivider(startIndent: 0),
        ],
      ),
    );
  }
}

/// vivo OriginOS 官方规范紧凑标题栏 (OriginSmallTopAppBar)
///
/// 高度 56dp + 状态栏高度，标题 15sp Medium，居中或居左。
/// 支持传入 [showDropdown] 展示右侧展开标记，以及 [onTitleTap] 响应点击。
class OriginSmallTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showDivider;
  final Color? backgroundColor;
  final bool centerTitle;
  final VoidCallback? onTitleTap;
  final bool showDropdown;

  const OriginSmallTopAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.showDivider = false,
    this.backgroundColor,
    this.centerTitle = true,
    this.onTitleTap,
    this.showDropdown = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(OriginTokens.smallTitleHeight);

  Widget _buildMiddle(BuildContext context) {
    final titleText = Text(
      title,
      style: OriginTokens.smallTitleStyle(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!showDropdown && onTitleTap == null) {
      return titleText;
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centerTitle ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: titleText),
        if (showDropdown) ...[
          const SizedBox(width: 4.0),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18.0,
            color: OriginTokens.textSecondary(context),
          ),
        ],
      ],
    );

    if (onTitleTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTitleTap!();
        },
        child: content,
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bg = backgroundColor ?? OriginTokens.pageBackground(context);

    return Container(
      color: bg,
      padding: EdgeInsets.only(top: statusBarHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: NavigationToolbar(
              leading: leading,
              middle: _buildMiddle(context),
              trailing: actions != null ? Row(mainAxisSize: MainAxisSize.min, children: actions!) : null,
              centerMiddle: centerTitle,
            ),
          ),
          if (showDivider) const OriginDivider(startIndent: 0),
        ],
      ),
    );
  }
}
