import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'origin_bottom_sheet.dart';

/// 打开 vivo OriginOS 风格账户偏好设置抽屉（兼容旧方法调用）
void showAccountPreferencesSheet(BuildContext context, WidgetRef ref) {
  showOriginAccountPreferencesSheet(context, ref);
}
