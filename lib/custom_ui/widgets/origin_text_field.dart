import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格通用文本输入框 (OriginTextField)
///
/// 遵循 OriginUI 交互与排版规范：
/// 1. 默认形态为次级容器背景卡片（浅色 #F8F9FA，深色 #2A2A2A），圆角 12dp；
/// 2. 聚焦时显示 1.2dp 主题品牌色平滑描边，失焦时无边框；
/// 3. 支持内置一键清空按钮（clearable: true）、前缀/后缀小图标、密码切换与错误高亮；
/// 4. 提供 `.compact` 紧凑胶囊构造函数，适合抽屉、对话框或小空间内嵌。
class OriginTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool clearable;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final EdgeInsetsGeometry? contentPadding;
  final Color? backgroundColor;
  final double borderRadius;
  final bool isDense;
  final bool showCounter;

  const OriginTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.clearable = false,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.contentPadding,
    this.backgroundColor,
    this.borderRadius = OriginTokens.cardRadius,
    this.isDense = false,
    this.showCounter = false,
  });

  /// 紧凑型输入框（用于抽屉、弹窗、筛选栏等小高度场景）
  const OriginTextField.compact({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.clearable = false,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.backgroundColor,
    this.borderRadius = 17.0,
    this.isDense = true,
    this.showCounter = false,
  });

  @override
  State<OriginTextField> createState() => _OriginTextFieldState();
}

class _OriginTextFieldState extends State<OriginTextField> {
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
  void didUpdateWidget(OriginTextField oldWidget) {
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
    final theme = Theme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final primaryColor = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;

    // 背景底色
    final fillBg = widget.backgroundColor ?? OriginTokens.cardSecondary(context);

    // 默认文字样式
    final defaultTextStyle = TextStyle(
      fontSize: 14.5,
      color: OriginTokens.textPrimary(context),
      letterSpacing: -0.2,
    );

    // 默认占位符样式
    final defaultHintStyle = TextStyle(
      fontSize: 14.0,
      color: OriginTokens.textTertiary(context),
      letterSpacing: -0.2,
    );

    // 边框逻辑
    InputBorder border;
    if (hasError) {
      border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: errorColor, width: 1.2),
      );
    } else if (_isFocused) {
      border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide(color: primaryColor, width: 1.2),
      );
    } else {
      border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        borderSide: BorderSide.none,
      );
    }

    // 后缀组件合成（清空按钮 + 外部传入 suffixIcon）
    Widget? finalSuffix;
    if (_showClear && widget.enabled && !widget.readOnly) {
      final clearBtn = GestureDetector(
        onTap: _handleClear,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            Icons.cancel,
            size: 18.0,
            color: OriginTokens.textTertiary(context),
          ),
        ),
      );

      if (widget.suffixIcon != null) {
        finalSuffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            clearBtn,
            widget.suffixIcon!,
          ],
        );
      } else {
        finalSuffix = clearBtn;
      }
    } else {
      finalSuffix = widget.suffixIcon;
    }

    final fieldWidget = TextField(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      autofocus: widget.autofocus,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      buildCounter: widget.showCounter
          ? null
          : (_, {required currentLength, required isFocused, maxLength}) =>
              null,
      style: widget.style ?? defaultTextStyle,
      cursorColor: primaryColor,
      cursorRadius: const Radius.circular(2.0),
      cursorWidth: 1.8,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        isDense: widget.isDense,
        filled: true,
        fillColor: fillBg,
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        counterText: widget.showCounter ? null : '',
        labelStyle: TextStyle(
          fontSize: 13.0,
          color: OriginTokens.textSecondary(context),
        ),
        hintText: widget.hintText,
        hintStyle: widget.hintStyle ?? defaultHintStyle,
        helperText: widget.helperText,
        helperStyle: TextStyle(
          fontSize: 12.0,
          color: OriginTokens.textTertiary(context),
        ),
        errorText: widget.errorText,
        errorStyle: TextStyle(
          fontSize: 12.0,
          color: errorColor,
        ),
        prefixIcon: widget.prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: widget.prefixIcon,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36.0,
          minHeight: 36.0,
        ),
        suffixIcon: finalSuffix,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36.0,
          minHeight: 36.0,
        ),
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: border,
        focusedErrorBorder: border,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide.none,
        ),
      ),
    );

    return fieldWidget;
  }
}
