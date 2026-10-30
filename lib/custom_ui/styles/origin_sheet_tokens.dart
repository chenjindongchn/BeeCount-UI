import 'package:flutter/material.dart';

/// OriginUI 底部抽屉设计 Token
///
/// 数值与动效来源：蓝河工具箱 `OriginUI/docs/15-bottom-sheet.md`（vivo OriginOS 反编译真值）。
/// 后续 OriginUI 规范若更新，只需同步修改本文件即可全工程生效。
class OriginSheetTokens {
  OriginSheetTokens._();

  /// 顶部圆角半径（vigour_layout_corner_Radius = 30dp）
  static const double cornerRadius = 30.0;

  /// 入场动效时长：卡片 400ms 自底向上滑出，遮罩在前 200ms 淡入
  static const Duration enterDuration = Duration(milliseconds: 400);
  static const Duration scrimEnterDuration = Duration(milliseconds: 200);

  /// 退场动效时长：遮罩与卡片同步 200ms 下滑淡出
  static const Duration exitDuration = Duration(milliseconds: 200);

  /// 入场曲线：PathInterpolator(0.28, 0.85, 0.36, 1.0)
  static const Curve enterCurve = Cubic(0.28, 0.85, 0.36, 1.0);

  /// 退场曲线：(0.25, 0.1, 0.25, 1.0)
  static const Curve exitCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  /// 手势拖拽关闭阈值：下滑位移超过 100dp 或向下速度超过 700dp/s 触发退出
  static const double dismissDistance = 100.0;
  static const double dismissVelocity = 700.0;

  /// 卡片背景色：延续 vivo 第一性原理，采用纯色不透明卡片底，不使用高开销模糊
  /// 日间 #FFFFFF / 夜间 #1E1E1E
  static Color cardColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFFFFFFF);

  /// 遮罩蒙层（Scrim）：日间 30% alpha（#4D000000），夜间 60% alpha（#99000000）
  static Color scrimColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0x99000000)
          : const Color(0x4D000000);
}
