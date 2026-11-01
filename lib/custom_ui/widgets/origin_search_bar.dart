import 'package:flutter/material.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格胶囊搜索输入栏 (OriginSearchBar)
///
/// 遵循蓝河工具箱与 vivo 视觉规范：
/// 1. 胶囊高度固定 32.0dp，圆角 16.0dp (OriginTokens.searchBarHeight / searchBarRadius)；
/// 2. 背景为细腻中性灰卡片底色（浅色 #F8F9FA，深色 #2A2A2A）；
/// 3. 前缀 16dp 搜索放大镜，右侧支持动态感知的一键清空胶囊图标；
/// 4. 键盘回车动作默认为 TextInputAction.search。
class OriginSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool autofocus;
  final bool enabled;
  final bool clearable;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;

  const OriginSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = '搜索',
    this.autofocus = false,
    this.enabled = true,
    this.clearable = true,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.backgroundColor,
    this.height = OriginTokens.searchBarHeight,
    this.borderRadius = OriginTokens.searchBarRadius,
  });

  @override
  State<OriginSearchBar> createState() => _OriginSearchBarState();
}

class _OriginSearchBarState extends State<OriginSearchBar> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  bool _internalControllerCreated = false;
  bool _internalFocusNodeCreated = false;
  bool _showClear = false;

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

    _effectiveController.addListener(_handleTextChange);
    _showClear = widget.clearable && _effectiveController.text.isNotEmpty;
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
      _showClear = widget.clearable && _effectiveController.text.isNotEmpty;
    }

    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.dispose();
        _internalFocusNodeCreated = false;
      }

      if (widget.focusNode == null) {
        _effectiveFocusNode = FocusNode();
        _internalFocusNodeCreated = true;
      } else {
        _effectiveFocusNode = widget.focusNode!;
      }
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    if (_internalFocusNodeCreated) {
      _effectiveFocusNode.dispose();
    }
    if (_internalControllerCreated) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  void _handleTextChange() {
    final shouldShow = widget.clearable && _effectiveController.text.isNotEmpty;
    if (mounted && _showClear != shouldShow) {
      setState(() {
        _showClear = shouldShow;
      });
    }
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fillBg = widget.backgroundColor ?? OriginTokens.cardSecondary(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 16.0,
            color: OriginTokens.textTertiary(context),
          ),
          const SizedBox(width: 6.0),
          Expanded(
            child: TextField(
              controller: _effectiveController,
              focusNode: _effectiveFocusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: 13.0,
                color: OriginTokens.textPrimary(context),
                letterSpacing: -0.2,
              ),
              cursorColor: primaryColor,
              cursorWidth: 1.5,
              cursorRadius: const Radius.circular(2.0),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  fontSize: 13.0,
                  color: OriginTokens.textTertiary(context),
                  letterSpacing: -0.2,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_showClear && widget.enabled)
            GestureDetector(
              onTap: _handleClear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Icon(
                  Icons.cancel,
                  size: 16.0,
                  color: OriginTokens.textTertiary(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
