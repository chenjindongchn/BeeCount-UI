import 'package:flutter/material.dart';

/// 根据内置账户类型（account.type）获取明细页面展示颜色（基础日间版）
///
/// 映射规范：
/// - 微信 (wechat)：绿色
/// - 支付宝 (alipay)：蓝色
/// - 银行卡 (bank_card)：浅蓝色
/// - 信用卡 (credit_card)：紫色
/// - 现金 (cash)：金色
/// - 其他 (other 及其他类型)：灰色
Color getAccountTypeColor(String? type) {
  return getAccountTypeColorAdaptive(type, isDark: false);
}

/// 根据内置账户类型（account.type）与当前主题（是否深色模式）获取胶囊背景色
///
/// 夜间模式优化考量：
/// 1. 降低明度与荧光感，避免全黑/暗灰卡片背景下刺眼；
/// 2. 现金金色适当加深至暖金褐/暗金，确保内部纯白文字阅读清晰、符合无障碍对比度。
Color getAccountTypeColorAdaptive(String? type, {bool isDark = false}) {
  if (isDark) {
    switch (type) {
      case 'wechat':
        return const Color(0xFF0E7A43); // 夜间沉翠绿
      case 'alipay':
        return const Color(0xFF125EC4); // 夜间深海蓝
      case 'bank_card':
        return const Color(0xFF2066B3); // 夜间静谧蓝
      case 'credit_card':
        return const Color(0xFF5E35B1); // 夜间深雅紫
      case 'cash':
        return const Color(0xFFB37402); // 夜间暗金琥珀
      default:
        return const Color(0xFF525252); // 夜间炭灰
    }
  } else {
    switch (type) {
      case 'wechat':
        return const Color(0xFF07C160); // 微信绿
      case 'alipay':
        return const Color(0xFF1677FF); // 支付宝蓝
      case 'bank_card':
        return const Color(0xFF2E84E6); // 银行卡蓝
      case 'credit_card':
        return const Color(0xFF7C4DFF); // 信用卡紫
      case 'cash':
        return const Color(0xFFD48806); // 暖金褐（确保纯白文字可读）
      default:
        return const Color(0xFF8C8C8C); // 其他灰
    }
  }
}

/// 快捷根据 BuildContext 读取当前深浅模式并返回对应账户类型的胶囊颜色
Color getAccountPillColor(BuildContext context, String? type) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return getAccountTypeColorAdaptive(type, isDark: isDark);
}
