import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../styles/origin_tokens.dart';

/// OriginOS 风格自定义记账数字键盘（紧凑精致版）
///
/// 严格参照用户提供的参考设计：
/// - 按键高度紧凑（44dp）
/// - 数字字体优雅纤细（20sp，w400/w500）
/// - 纯净微浅底色，柔和圆角（10dp）
/// - 右下角「保存」按钮跟随软件设置的主题色，左下角浅灰「再记一笔」
class OriginKeypad extends StatelessWidget {
  const OriginKeypad({
    super.key,
    required this.onDigit,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onDecimal,
    required this.onSave,
    required this.onSaveAndContinue,
    this.saveLabel = '保存',
    this.continueLabel = '再记一笔',
    this.keyHeight = 44.0,
  });

  final ValueChanged<String> onDigit;
  final ValueChanged<String> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onDecimal;
  final VoidCallback onSave;
  final VoidCallback onSaveAndContinue;
  final String saveLabel;
  final String continueLabel;
  final double keyHeight;

  Widget _buildKey({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color? backgroundColor,
    bool isSave = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 默认按键底色：日间极纯净浅灰 #F8F9FA，夜间 #262629
    final defaultBg = isDark ? const Color(0xFF262629) : const Color(0xFFF8F9FA);
    // 保存按钮底色：挂钩软件设置中的主题色
    final saveBg = OriginTokens.primary(context);

    final bg = backgroundColor ?? (isSave ? saveBg : defaultBg);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 3.0),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            onLongPress: onLongPress != null
                ? () {
                    HapticFeedback.mediumImpact();
                    onLongPress();
                  }
                : null,
            child: SizedBox(
              height: keyHeight,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final numTextColor = isDark ? Colors.white : const Color(0xFF1F1F24);
    final opBgColor = isDark ? const Color(0xFF2E2E33) : const Color(0xFFEEF0F4);
    final subActionBgColor = isDark ? const Color(0xFF29292D) : const Color(0xFFF0F1F4);

    const digitStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.3,
    );
    const opStyle = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w400,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: 7  8  9  ⌫
          Row(
            children: [
              _buildKey(
                context: context,
                child: Text('7', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('7'),
              ),
              _buildKey(
                context: context,
                child: Text('8', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('8'),
              ),
              _buildKey(
                context: context,
                child: Text('9', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('9'),
              ),
              _buildKey(
                context: context,
                backgroundColor: opBgColor,
                child: Icon(Icons.backspace_outlined, size: 19, color: numTextColor),
                onTap: onBackspace,
                onLongPress: onClear,
              ),
            ],
          ),
          // Row 2: 4  5  6  -
          Row(
            children: [
              _buildKey(
                context: context,
                child: Text('4', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('4'),
              ),
              _buildKey(
                context: context,
                child: Text('5', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('5'),
              ),
              _buildKey(
                context: context,
                child: Text('6', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('6'),
              ),
              _buildKey(
                context: context,
                backgroundColor: opBgColor,
                child: Text('-', style: opStyle.copyWith(color: numTextColor)),
                onTap: () => onOperator('-'),
              ),
            ],
          ),
          // Row 3: 1  2  3  +
          Row(
            children: [
              _buildKey(
                context: context,
                child: Text('1', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('1'),
              ),
              _buildKey(
                context: context,
                child: Text('2', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('2'),
              ),
              _buildKey(
                context: context,
                child: Text('3', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('3'),
              ),
              _buildKey(
                context: context,
                backgroundColor: opBgColor,
                child: Text('+', style: opStyle.copyWith(color: numTextColor)),
                onTap: () => onOperator('+'),
              ),
            ],
          ),
          // Row 4: 再记一笔  0  .  保存
          Row(
            children: [
              _buildKey(
                context: context,
                backgroundColor: subActionBgColor,
                child: Text(
                  continueLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: numTextColor.withValues(alpha: 0.65),
                  ),
                ),
                onTap: onSaveAndContinue,
              ),
              _buildKey(
                context: context,
                child: Text('0', style: digitStyle.copyWith(color: numTextColor)),
                onTap: () => onDigit('0'),
              ),
              _buildKey(
                context: context,
                child: Text('.', style: digitStyle.copyWith(color: numTextColor)),
                onTap: onDecimal,
              ),
              _buildKey(
                context: context,
                isSave: true,
                child: Text(
                  saveLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
                onTap: onSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
