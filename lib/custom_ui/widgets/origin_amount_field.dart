import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格金额/数字专用输入框 (OriginAmountField)
///
/// 专用于记账、预算设置、资产调整等大数字输入场景：
/// 1. 左侧大字号货币符号（¥ / $ / € 等），支持与数值自适应对齐；
/// 2. 加粗等宽大字号（默认 24sp~28sp），视觉焦点突出；
/// 3. 内置数字键盘与仅限两位小数输入格式化器（^\d*\.?\d{0,2}）；
/// 4. 支持卡片包裹模式（带背景、圆角与聚焦微光）与无边框纯净内嵌模式。
class OriginAmountField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String currencySymbol;
  final String hintText;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final bool showBackground;
  final double fontSize;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Color? backgroundColor;
  final double borderRadius;
  final bool clearable;

  const OriginAmountField({
    super.key,
    this.controller,
    this.focusNode,
    this.currencySymbol = '¥',
    this.hintText = '0.00',
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.showBackground = true,
    this.fontSize = 24.0,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.backgroundColor,
    this.borderRadius = OriginTokens.cardRadius,
    this.clearable = false,
  });

  @override
  State<OriginAmountField> createState() => _OriginAmountFieldState();
}

class _OriginAmountFieldState extends State<OriginAmountField> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  bool _internalControllerCreated = false;
  bool _internalFocusNodeCreated = false;
  bool _isFocused = false;
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

    _effectiveFocusNode.addListener(_handleFocusChange);
    _effectiveController.addListener(_handleTextChange);
    _showClear = widget.clearable && _effectiveController.text.isNotEmpty;
  }

  @override
  void didUpdateWidget(OriginAmountField oldWidget) {
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
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _effectiveController.removeListener(_handleTextChange);
    if (_internalFocusNodeCreated) {
      _effectiveFocusNode.dispose();
    }
    if (_internalControllerCreated) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    final fillBg = widget.backgroundColor ?? OriginTokens.cardSecondary(context);

    final inputWidget = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.currencySymbol.isNotEmpty) ...[
          Text(
            widget.currencySymbol,
            style: TextStyle(
              fontSize: widget.fontSize * 0.85,
              fontWeight: FontWeight.bold,
              color: OriginTokens.textPrimary(context),
            ),
          ),
          const SizedBox(width: 8.0),
        ],
        Expanded(
          child: TextField(
            controller: _effectiveController,
            focusNode: _effectiveFocusNode,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.bold,
              color: OriginTokens.textPrimary(context),
              letterSpacing: -0.5,
            ),
            cursorColor: primaryColor,
            cursorRadius: const Radius.circular(2.0),
            cursorWidth: 2.0,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.bold,
                color: OriginTokens.textTertiary(context),
                letterSpacing: -0.5,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_showClear && widget.enabled && !widget.readOnly)
          GestureDetector(
            onTap: _handleClear,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.cancel,
                size: 20.0,
                color: OriginTokens.textTertiary(context),
              ),
            ),
          ),
      ],
    );

    if (!widget.showBackground) {
      return inputWidget;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: fillBg,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: _isFocused ? primaryColor : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: inputWidget,
    );
  }
}
