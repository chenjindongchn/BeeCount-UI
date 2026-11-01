import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../styles/origin_tokens.dart';
import 'origin_card.dart';

/// vivo OriginOS 风格次级指标项模型
class OriginHeroMetric {
  final String label;
  final String value;
  final String? unit;
  final VoidCallback? onTap;
  final Color? valueColor;

  const OriginHeroMetric({
    required this.label,
    required this.value,
    this.unit,
    this.onTap,
    this.valueColor,
  });
}

/// vivo OriginOS 风格顶级数据看板大卡片 (OriginHeroCard)
///
/// 遵循全局定制与统一视觉规范：
/// 1. 圆角统一采用 19.0dp (`OriginTokens.heroCardRadius`)；
/// 2. 背景色默认绑定主题色 (`primaryColor`)，支持传入自定义颜色；
/// 3. 文字与图标色彩依据主题色明暗自动自适应深浅亮度，确保最佳可读性；
/// 4. 上半部核心内容：标题行（标题+单位+眼睛图标+操作按钮）、32sp Bold 核心大数字、次级指标双栏（18sp Bold）；
/// 5. 支持嵌入式中间内容（如进度条）与可选底部特殊挂件（如明细页专属月预算条）。
class OriginHeroCard extends ConsumerWidget {
  final String title;
  final String? unit;
  final String mainAmount;
  final bool hideAmounts;
  final VoidCallback? onToggleHideAmounts;
  final Widget? action;
  final Widget? middleChild;
  final List<OriginHeroMetric> metrics;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final Widget? bottomChild;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const OriginHeroCard({
    super.key,
    required this.title,
    this.unit,
    required this.mainAmount,
    this.hideAmounts = false,
    this.onToggleHideAmounts,
    this.action,
    this.middleChild,
    this.metrics = const [],
    this.color,
    this.radius = OriginTokens.heroCardRadius,
    this.onTap,
    this.bottomChild,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePrimary = Theme.of(context).primaryColor;
    final Color effectiveColor =
        color ?? ref.watch(primaryColorProvider) ?? themePrimary;
    final isPrimaryLight =
        ThemeData.estimateBrightnessForColor(effectiveColor) == Brightness.light;

    // 自适应文字颜色体系
    final mainTextColor =
        isPrimaryLight ? const Color(0xFF1D1D1F) : Colors.white;
    final subTextColor = isPrimaryLight
        ? const Color(0xFF1D1D1F).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.75);

    final effectivePadding = padding ??
        const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 16.0);

    return OriginCard(
      color: effectiveColor,
      padding: EdgeInsets.zero,
      radius: radius,
      margin: margin,
      onTap: onTap,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 上半部分核心指标主区域
          Padding(
            padding: effectivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部标题行与控制按钮
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        color: subTextColor,
                      ),
                    ),
                    if (unit != null && unit!.isNotEmpty) ...[
                      const SizedBox(width: 2.0),
                      Text(
                        '($unit)',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                    ],
                    if (onToggleHideAmounts != null) ...[
                      const SizedBox(width: 6.0),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggleHideAmounts,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            hideAmounts
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18.0,
                            color: subTextColor,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: 6.0),

                // 核心大数字展示 (32.0sp Bold)
                Text(
                  hideAmounts ? '****' : mainAmount,
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                    color: mainTextColor,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),

                // 中间定制内容（如预算进度条）
                if (middleChild != null) ...[
                  const SizedBox(height: 12.0),
                  middleChild!,
                ],

                // 次级指标双栏/多栏行 (18.0sp Bold)
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Row(
                    children: metrics.map((m) {
                      Widget item = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: subTextColor,
                                ),
                              ),
                              if (m.unit != null && m.unit!.isNotEmpty) ...[
                                const SizedBox(width: 2.0),
                                Text(
                                  '(${m.unit})',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            hideAmounts ? '****' : m.value,
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: m.valueColor ?? mainTextColor,
                            ),
                          ),
                        ],
                      );

                      if (m.onTap != null) {
                        item = GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: m.onTap,
                          child: item,
                        );
                      }

                      return Expanded(child: item);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // 2. 可选底部挂件（例如明细页的月预算磨砂小条，无则不渲染）
          if (bottomChild != null) bottomChild!,
        ],
      ),
    );
  }
}
