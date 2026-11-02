import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格胶囊搜索输入栏 (OriginSearchBar)
///
/// 遵循蓝河工具箱 `OriginUI/docs/16-search-bar.md` 与官方源码 `OriginSearchBar.kt` 真值规范：
/// 1. 【几何真值】
///    - 胶囊高度固定 32.0dp，圆角 16.0dp (OriginTokens.searchBarHeight / searchBarRadius)；
///    - 左侧 13.0dp 内缩 + 14.0dp 细线放大镜矢量图标；
///    - 图标与输入区域间隔 8.0dp，输入与提示字号 14.0sp；
///    - 右侧 24.0dp 触控区清除小叉，文字非空时 150ms 平滑淡入淡出。
/// 2. 【交互状态机】
///    - 静止态 (Inactive)：无焦点且无文本，胶囊撑满或自然排列；
///    - 激活态 (Active)：获焦或文本非空时，右侧“取消”按钮以 200ms FastOutSlowIn 曲线平滑淡入滑入；
///    - 点击“取消”：清空文本、失焦收起键盘，并触发 onCancel 回调，平滑退出激活态。
/// 3. 【色彩与暗色模式】
///    - 背景：日间 #EAEAEA 浅灰实底，夜间 #303030 深灰实底；
///    - 提示与图标：日间 #7C7C7C，夜间 #80FFFFFF；
///    - 光标与取消按钮：当前主题强调色 (OriginTokens.primary)。
class OriginSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool autofocus;
  final bool enabled;
  final bool clearable;
  final bool showCancelWhenFocused;
  final String cancelText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final VoidCallback? onCancel;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget? leading;

  const OriginSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = '搜索',
    this.autofocus = false,
    this.enabled = true,
    this.clearable = true,
    this.showCancelWhenFocused = false,
    this.cancelText = '取消',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onCancel,
    this.backgroundColor,
    this.height = OriginTokens.searchBarHeight,
    this.borderRadius = OriginTokens.searchBarRadius,
    this.padding,
    this.leading,
  });

  @override
  State<OriginSearchBar> createState() => _OriginSearchBarState();
}

class _OriginSearchBarState extends State<OriginSearchBar> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  bool _internalControllerCreated = false;
  bool _internalFocusNodeCreated = false;
  bool _hasText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _effectiveController = TextEditingController();
      _internalControllerCreated = true;
    } else {
      _effectiveController = widget.controller!;
    }

    if (widget.focusNode == null) {
      _effectiveFocusNode = FocusNode();
      _internalFocusNodeCreated = true;
    } else {
      _effectiveFocusNode = widget.focusNode!;
    }

    _hasText = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_handleTextChange);
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(OriginSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _effectiveController.removeListener(_handleTextChange);
        _effectiveController.dispose();
        _internalControllerCreated = false;
      } else {
        oldWidget.controller!.removeListener(_handleTextChange);
      }

      if (widget.controller == null) {
        _effectiveController = TextEditingController();
        _internalControllerCreated = true;
      } else {
        _effectiveController = widget.controller!;
      }
      _effectiveController.addListener(_handleTextChange);
      _hasText = _effectiveController.text.isNotEmpty;
    }

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.removeListener(_handleFocusChange);
        _effectiveFocusNode.dispose();
        _internalFocusNodeCreated = false;
      } else {
        oldWidget.focusNode!.removeListener(_handleFocusChange);
      }

      if (widget.focusNode == null) {
        _effectiveFocusNode = FocusNode();
        _internalFocusNodeCreated = true;
      } else {
        _effectiveFocusNode = widget.focusNode!;
      }
      _effectiveFocusNode.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (_internalFocusNodeCreated) {
      _effectiveFocusNode.dispose();
    }
    if (_internalControllerCreated) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  void _handleTextChange() {
    final nowHasText = _effectiveController.text.isNotEmpty;
    if (mounted && _hasText != nowHasText) {
      setState(() {
        _hasText = nowHasText;
      });
    }
  }

  void _handleFocusChange() {
    final nowFocused = _effectiveFocusNode.hasFocus;
    if (mounted && _isFocused != nowFocused) {
      setState(() {
        _isFocused = nowFocused;
      });
    }
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  void _handleCancel() {
    _effectiveController.clear();
    _effectiveFocusNode.unfocus();
    widget.onChanged?.call('');
    widget.onClear?.call();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fillBg = widget.backgroundColor ?? OriginTokens.searchBarBackground(context);
    final hintColor = OriginTokens.searchBarHint(context);
    final primaryColor = OriginTokens.primary(context);
    final isCancelVisible = widget.showCancelWhenFocused && (_isFocused || _hasText);

    Widget searchBarContent = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.leading ??
              Icon(
                Icons.search_rounded,
                size: 14.0,
                color: hintColor,
              ),
          const SizedBox(width: 8.0),
          Expanded(
            child: TextField(
              controller: _effectiveController,
              focusNode: _effectiveFocusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textPrimary(context),
                letterSpacing: -0.2,
                height: 1.25,
              ),
              cursorColor: primaryColor,
              cursorWidth: 1.5,
              cursorRadius: const Radius.circular(2.0),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 14.0,
                  color: hintColor,
                  letterSpacing: -0.2,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: (_hasText && widget.enabled && widget.clearable) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            child: (_hasText && widget.enabled && widget.clearable)
                ? GestureDetector(
                    onTap: _handleClear,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 24.0,
                      height: 24.0,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.cancel,
                        size: 16.0,
                        color: hintColor,
                      ),
                    ),
                  )
                : const SizedBox(width: 24.0, height: 24.0),
          ),
        ],
      ),
    );

    Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: searchBarContent),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          child: isCancelVisible
              ? GestureDetector(
                  onTap: _handleCancel,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      widget.cancelText,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    if (widget.padding != null) {
      return Padding(
        padding: widget.padding!,
        child: row,
      );
    }
    return row;
  }
}

/// vivo OriginOS 风格胶囊筛选小标签 (OriginFilterChip)
///
/// 遵循 `OriginUI/docs/16-search-bar.md` 与 Token 规范：
/// - 高度 30.0dp，圆角 15.0dp；
/// - 未选底色：日间 #F1F1F1，夜间 #2A2A2A；
/// - 选中底色：日间 #DEEAFF，夜间 #1A3060；
/// - 支持前缀图标、删除/清除尾部按钮。
class OriginFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final Color? customBackground;

  const OriginFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.leading,
    this.trailing,
    this.onTap,
    this.onDeleted,
    this.customBackground,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);

    final bg = customBackground ??
        (selected
            ? OriginTokens.chipSelectedBackground(context)
            : OriginTokens.chipBackground(context));

    final textColor = selected
        ? (isDark ? const Color(0xFF8FB9FF) : primaryColor)
        : OriginTokens.textPrimary(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OriginTokens.chipRadius),
        child: Ink(
          height: OriginTokens.chipHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(OriginTokens.chipRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: OriginTokens.chipHorizontalPadding,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 4.0),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4.0),
                trailing!,
              ] else if (onDeleted != null) ...[
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: onDeleted,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.close_rounded,
                    size: 13.0,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
