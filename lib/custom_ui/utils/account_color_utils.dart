import 'package:flutter/material.dart';

/// 根据内置账户类型（account.type）获取明细页面展示颜色
///
/// 映射规范：
/// - 微信 (wechat)：绿色
/// - 支付宝 (alipay)：蓝色
/// - 银行卡 (bank_card)：浅蓝色
/// - 信用卡 (credit_card)：紫色
/// - 现金 (cash)：金色
/// - 其他 (other 及其他类型)：灰色
Color getAccountTypeColor(String? type) {
  switch (type) {
    case 'wechat':
      return const Color(0xFF07C160); // 微信绿
    case 'alipay':
      return const Color(0xFF1677FF); // 支付宝蓝
    case 'bank_card':
      return const Color(0xFF3890E6); // 银行卡浅蓝
    case 'credit_card':
      return const Color(0xFF7C4DFF); // 信用卡紫
    case 'cash':
      return const Color(0xFFE5A600); // 现金金
    default:
      return const Color(0xFF8C8C8C); // 其他灰
  }
}
