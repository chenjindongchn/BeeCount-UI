import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// OriginOS 风格自定义记账数字键盘
///
/// 键位布局严格遵循参考设计：
///   7       8    9    ⌫
///   4       5    6    -
///   1       2    3    +
///   再记一笔  0    .    保存
///
/// 特性：
/// - 纯净扁平卡片无生硬边框
/// - 触感微震动反馈 (HapticFeedback.lightImpact)
/// - 右下角醒目保存主色按钮，左下角「再记一笔」快捷操作
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

  Widget _buildKey({
    required BuildContext context,
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color? backgroundColor,
    bool isPrimary = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF28282C) : const Color(0xFFF3F4F6);
    final bg = backgroundColor ?? (isPrimary ? Theme.of(context).colorScheme.primary : defaultBg);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
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
              height: 52,
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

    final numTextColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
    final opBgColor = isDark ? const Color(0xFF333338) : const Color(0xFFE5E7EB);
    final subActionBgColor = isDark ? const Color(0xFF2E3035) : const Color(0xFFE9EBEF);

    const digitStyle = TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    );
    const opStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                child: Icon(Icons.backspace_outlined, size: 21, color: numTextColor),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: numTextColor.withValues(alpha: 0.85),
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
                isPrimary: true,
                child: Text(
                  saveLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
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
