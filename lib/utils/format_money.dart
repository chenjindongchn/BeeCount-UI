import 'currencies.dart';
import 'format_utils.dart';

/// 全局金额千分位开关（纯函数默认 true 与上游一致；App 启动时由 thousandSeparatorProvider 默认关闭）
bool globalUseThousandSeparator = true;

/// 全局货币符号显示开关（默认 false：不显示 ¥ / $ 等货币符号；开启为 true：显示货币符号）
bool globalShowCurrencySymbol = false;

/// Shared by App bindings and AmountText. Currency selection, locale and
/// compact preference are resolved by the host; presentation packages only
/// receive the final display text.
String formatDisplayAmount(double value,
    {String? currencyCode,
    bool? showCurrency,
    bool useCompactFormat = false,
    bool isChineseLocale = true,
    bool signed = true,
    int decimals = 2,
    bool? useThousandSeparator}) {
  final shouldShowCurrency = showCurrency ?? globalShowCurrencySymbol;
  if ((shouldShowCurrency || useCompactFormat) && currencyCode != null) {
    var formatted =
        formatBalance(value, currencyCode, isChineseLocale: isChineseLocale, showCurrency: shouldShowCurrency);
    final symbol = getCurrencySymbol(currencyCode.toUpperCase());
    if (!shouldShowCurrency && symbol.isNotEmpty) {
      // Negative compact values start with the sign before the currency.
      formatted = formatted.replaceFirst(symbol, '').trimLeft();
    }
    if (useCompactFormat) return formatted;
    final plain = formatMoneyCompact(value,
        maxDecimals: decimals,
        signed: signed,
        useThousandSeparator: useThousandSeparator);
    return shouldShowCurrency ? '$symbol$plain' : plain;
  }
  return formatMoneyCompact(value,
      maxDecimals: decimals,
      signed: signed,
      useThousandSeparator: useThousandSeparator);
}

// 金额格式：最多保留2位小数，移除多余0和末尾小数点，支持根据开关添加千分号
String formatMoneyCompact(double v,
    {int maxDecimals = 2,
    bool signed = false,
    bool trimZeros = true,
    bool? useThousandSeparator}) {
  final useSeparator = useThousandSeparator ?? globalUseThousandSeparator;

  String formatWithSeparator(double value) {
    String s = value.abs().toStringAsFixed(maxDecimals);

    // 分离整数和小数部分
    final parts = s.split('.');
    final intPart = parts[0];
    String decPart = parts.length > 1 ? parts[1] : '';

    // 移除小数部分末尾的0
    if (trimZeros) decPart = decPart.replaceFirst(RegExp(r'0+$'), '');

    // 添加千分号（仅在开启千分位开关时插入逗号）
    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (useSeparator && i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    // 组合结果
    if (decPart.isEmpty) {
      return buffer.toString();
    } else {
      return '${buffer.toString()}.$decPart';
    }
  }

  if (signed) {
    // 使用显式符号时，分别处理符号和数值
    final sign = v < 0 ? '-' : '+';
    return '$sign${formatWithSeparator(v)}';
  } else {
    // 不使用显式符号时，保留数值的自然符号
    final sign = v < 0 ? '-' : '';
    return '$sign${formatWithSeparator(v)}';
  }
}

