import 'package:flutter/material.dart';

/// vivo OriginOS 视觉与交互规范设计系统 Token (OriginTokens)
///
/// 遵循蓝河工具箱 `OriginUI/docs/` 全套反编译真值与实测规范：
/// - 01/24: 浅色与深色设置页中性色
/// - 02: 标题栏与页面骨架 (大标题 84dp/22sp, 紧凑 56dp/15sp)
/// - 13: 卡片圆角 (12dp)、边距 (20dp) 与发丝分割线 (0.5dp / #D9D9D9)
/// - 15: 底部抽屉 (30dp 圆角, Cubic(0.28, 0.85, 0.36, 1.0))
/// - 18: 底部导航栏与胶囊分段选择器 (36dp 高度, 18dp 圆角)
class OriginTokens {
  OriginTokens._();

  // ===========================================================================
  // 1. 核心几何真值 (Dimensions)
  // ===========================================================================

  /// 分组卡片圆角半径（系统设置与真机标准：12.0dp）
  static const double cardRadius = 12.0;

  /// 分组卡片外侧横向边距（系统设置真机标准：20.0dp）
  static const double cardMargin = 20.0;

  /// 卡片内边距（通常为 16.0dp 或 20.0dp）
  static const double cardInnerPadding = 16.0;

  /// 底部抽屉圆角（vigour_layout_corner_Radius = 30.0dp）
  static const double sheetRadius = 30.0;

  /// 大胶囊按钮高度与圆角（高度 46dp, 圆角 23dp）
  static const double buttonHeight = 46.0;
  static const double buttonRadius = 23.0;

  /// 紧凑小按钮高度与圆角（高度 30dp, 圆角 15dp）
  static const double smallButtonHeight = 30.0;
  static const double smallButtonRadius = 15.0;

  /// 胶囊分段选择器高度与圆角（高度 36dp, 圆角 18dp, 内缩 3dp）
  static const double tabSelectorHeight = 36.0;
  static const double tabSelectorRadius = 18.0;
  static const double tabSelectorPadding = 3.0;

  /// 搜索框胶囊高度与圆角（高度 32dp, 圆角 16dp）
  static const double searchBarHeight = 32.0;
  static const double searchBarRadius = 16.0;

  /// 发丝分割线厚度（1 物理像素，真机标定 0.5dp）
  static const double hairline = 0.5;

  /// 大标题栏最小高度（不含状态栏：84.0dp）
  static const double largeTitleHeight = 84.0;

  /// 紧凑标题栏高度（不含状态栏：56.0dp）
  static const double smallTitleHeight = 56.0;

  /// 底部导航栏主体高度（不含虚拟按键/手势条安全区：66.0dp）
  static const double bottomBarHeight = 66.0;

  /// 悬浮胶囊导航栏高度（紧凑校准：48.0dp，圆角 24.0dp，内部药丸 40.0dp，距手势条上移至 28.0dp）
  static const double floatingBarHeight = 48.0;
  static const double floatingBarRadius = 24.0;
  static const double floatingPillHeight = 40.0;
  static const double floatingPillRadius = 20.0;
  static const double floatingBarPaddingH = 4.0;
  static const double floatingBarPaddingV = 4.0;
  static const double floatingBarHorizontalMargin = 36.0;
  static const double floatingBarBottomMargin = 28.0;
  static const double floatingSplitGap = 10.0;
  static const double floatingBarIconSize = 20.0;

  // ===========================================================================
  // 2. 色彩系统 (Colors & Dark Mode)
  // ===========================================================================

  /// 页面背景中性色（浅色 #F4F4F6，深色 #000000 纯黑）
  static Color pageBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF000000)
          : const Color(0xFFF4F4F6);

  /// 卡片背景色（浅色 #FFFFFF 纯白，深色 #202020）
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF202020)
          : const Color(0xFFFFFFFF);

  /// 卡片内二级容器底色（用于次级卡片或标签容器）
  static Color cardSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A2A)
          : const Color(0xFFF8F9FA);

  /// 一级主文字色（浅色 #1A1A1A / 深色 #E9E9E9）
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFE9E9E9)
          : const Color(0xFF1A1A1A);

  /// 二级辅助信息色（浅色 #666666 / 深色 #A6A6A6）
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFA6A6A6)
          : const Color(0xFF666666);

  /// 三级辅助说明/箭头颜色（浅色 #909090 / 深色 #909090）
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF909090)
          : const Color(0xFF909090);

  /// 说明文字 (Summary Text)
  static Color summaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFB1B1B1)
          : const Color(0xFF787878);

  /// 列表发丝分割线颜色（浅色 #D9D9D9 / 深色 #262626）
  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF262626)
          : const Color(0xFFD9D9D9);

  /// 分段胶囊外框背景（浅色 #EAEAEA / 深色 #262626）
  static Color tabRowBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF262626)
          : const Color(0xFFEAEAEA);

  /// 分段胶囊滑动药丸背景（浅色 #FFFFFF 伴微投影 / 深色 #383838）
  static Color tabPillBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF383838)
          : const Color(0xFFFFFFFF);

  /// 底部导航未选图标与文字颜色（浅色 #757575 / 深色 #8C8C8C）
  static Color bottomBarUnselected(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8C8C8C)
          : const Color(0xFF757575);

  /// 悬浮胶囊导航栏磨砂底色（对齐 OriginColors.navigationBarFloatingBackground）
  static Color floatingBarBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xE6282828)
          : const Color(0xEBFFFFFF);

  /// 悬浮胶囊导航栏发丝柔光描边
  static Color floatingBarBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0x26FFFFFF)
          : const Color(0x14000000);

  /// 悬浮胶囊导航栏内部选中药丸颜色（对齐 OriginColors.navigationBarPillIndicator）
  static Color floatingPillIndicator(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xCC121212)
          : const Color(0xCCEDEDED);

  /// 主题强调色（直接挂钩软件设置中的主题色，不硬编码固定色值）
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  /// 默认主题强调色兜底常量（仅无 context 时备用）
  static const Color defaultPrimary = Color(0xFF0066FF);

  /// 收入强调色（默认翡翠绿）
  static const Color incomeGreen = Color(0xFF00B060);

  /// 支出强调色（默认赤红）
  static const Color expenseRed = Color(0xFFFF4D4F);

  // ===========================================================================
  // 3. 动效曲线与时长 (Motion Curves & Durations)
  // ===========================================================================

  /// 入场贝塞尔曲线：PathInterpolator(0.28, 0.85, 0.36, 1.0)
  static const Curve enterCurve = Cubic(0.28, 0.85, 0.36, 1.0);

  /// 退场贝塞尔曲线：Cubic(0.25, 0.1, 0.25, 1.0)
  static const Curve exitCurve = Cubic(0.25, 0.1, 0.25, 1.0);

  /// 快速响应动效（如胶囊移动、Tab切换）：FastOutSlowIn
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  /// 标准进场时长
  static const Duration enterDuration = Duration(milliseconds: 350);

  /// 标准退场时长
  static const Duration exitDuration = Duration(milliseconds: 200);

  /// 按压态回弹时长
  static const Duration pressDuration = Duration(milliseconds: 150);

  // ===========================================================================
  // 4. 文字样式体系 (Typography)
  // ===========================================================================

  /// 页面主大标题样式（22sp, SemiBold）
  static TextStyle largeTitleStyle(BuildContext context) => TextStyle(
        fontSize: 22.0,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
        letterSpacing: -0.3,
      );

  /// 紧凑顶栏标题样式（15sp, Medium）
  static TextStyle smallTitleStyle(BuildContext context) => TextStyle(
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
      );

  /// 辅助副标题样式（12sp, Regular）
  static TextStyle subtitleStyle(BuildContext context) => TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: textSecondary(context),
      );

  /// 卡片主标题（16sp, SemiBold）
  static TextStyle cardTitleStyle(BuildContext context) => TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
      );

  /// 正文内容（14sp, Regular）
  static TextStyle bodyStyle(BuildContext context) => TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        color: textPrimary(context),
      );

  /// 次级辅助文字（12sp, Regular）
  static TextStyle captionStyle(BuildContext context) => TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: textSecondary(context),
      );

  /// 分段器文本样式（14sp）
  static TextStyle segmentedTextStyle(BuildContext context,
          {required bool selected}) =>
      TextStyle(
        fontSize: 14.0,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? textPrimary(context) : textSecondary(context),
      );

  /// 底部导航文本样式（10sp, Medium）
  static TextStyle bottomBarTextStyle({required Color color}) => TextStyle(
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.2,
      );
}

/// 定制应用与品牌信息（物理隔离存放于 custom_ui，零上游冲突）
class OriginAppInfo {
  OriginAppInfo._();

  /// 软件正式名称
  static const String appName = '记账蓝盒';

  /// 软件测试版名称
  static const String appNameTest = '记账蓝盒测试版';

  /// 软件英文代号
  static const String appNameEn = 'BeeCount';
}
