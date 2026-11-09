import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../../providers.dart';
import '../../utils/category_utils.dart';
import '../../utils/format_money.dart';
import '../pages/custom_category_detail_page.dart';
import '../styles/origin_tokens.dart';

/// vivo 钱包风格多色分类占比环形图组件 (OriginAnalyticsPie)
///
/// 严格还原 vivo 钱包“收支报表 / 支出分类构成”设计规范：
/// 1. 多色圆环：每个分类拥有鲜明且质感的专属色彩，扇区微间隙分割；
/// 2. 动态折线引导标注 (Leader Callout Line)：从当前选中的扇区向外引出折线标注分类名称与百分比；
/// 3. 环心聚焦：中央大字展现选中分类的金额，下方副标题说明分类及币种；
/// 4. 丝滑动画：加载与切换周期时具有从 12 点钟顺时针展开的扫过生长动画，切换分类平滑过渡；
/// 5. 交互图例列表：环形图下方展示分类占比条目，支持点击扇区或列表双向联动。
class OriginAnalyticsPie extends ConsumerStatefulWidget {
  const OriginAnalyticsPie({
    super.key,
    required this.data,
    this.type = 'expense',
    this.scope = 'month',
    this.month,
  });

  final AnalyticsResult data;
  final String type;
  final String scope;
  final DateTime? month;

  @override
  ConsumerState<OriginAnalyticsPie> createState() => _OriginAnalyticsPieState();
}

class _OriginAnalyticsPieState extends ConsumerState<OriginAnalyticsPie>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sweepAnimation;
  int _selectedIndex = 0;

  // vivo 钱包风格高质感对比色系调色板
  static const List<Color> _paletteTemplates = [
    Color(0xFF3366FF), // 0: 经典宝蓝
    Color(0xFFFF7D00), // 1: 活力暖橙
    Color(0xFF00B0FF), // 2: 清澈天蓝
    Color(0xFF8E44AD), // 3: 典雅罗兰紫
    Color(0xFFFF4081), // 4: 珊瑚玫红
    Color(0xFF2ECC71), // 5: 翡翠鲜绿
    Color(0xFFFFB300), // 6: 亮琥珀黄
    Color(0xFF00BFA5), // 7: 薄荷青
    Color(0xFF7E57C2), // 8: 浅紫
    Color(0xFF78909C), // 9: 雅致蓝灰 (其他兜底)
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(covariant OriginAnalyticsPie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.scope != widget.scope ||
        oldWidget.type != widget.type) {
      _selectedIndex = 0;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Color> _buildPalette(Color primaryColor, int count) {
    final colors = <Color>[primaryColor];
    for (var i = 1; i < count; i++) {
      final candidate = _paletteTemplates[i % _paletteTemplates.length];
      if (candidate.toARGB32() == primaryColor.toARGB32()) {
        colors.add(_paletteTemplates[(i + 1) % _paletteTemplates.length]);
      } else {
        colors.add(candidate);
      }
    }
    return colors;
  }

  void _openCategoryDetail(int categoryId, String categoryName) {
    final m = widget.month ?? DateTime.now();
    final periodLabel = widget.scope == 'all'
        ? null
        : widget.scope == 'year'
            ? '${m.year}'
            : '${m.year}.${m.month.toString().padLeft(2, '0')}';

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CustomCategoryDetailPage(
          categoryId: categoryId,
          categoryName: categoryName,
          startDate: widget.scope == 'all' ? null : widget.data.start,
          endDate: widget.scope == 'all' ? null : widget.data.end,
          periodLabel: periodLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hide = ref.watch(hideAmountsProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sorted = List<AnalyticsCategory>.of(widget.data.categories)
      ..sort((a, b) => b.total.compareTo(a.total));
    final positive = sorted.where((c) => c.total > 0).toList();

    if (positive.isEmpty || widget.data.total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Text(
            l.commonEmpty,
            style: TextStyle(
              fontSize: 12,
              color: OriginTokens.textSecondary(context),
            ),
          ),
        ),
      );
    }

    // 分类展示聚合逻辑：若大于 7 个分类，取前 6 项，其余聚合为“其它”
    final List<({String name, double total, AnalyticsCategory? raw, Color color})>
        items = [];
    final maxSegments = 6;
    final int effectiveCount =
        positive.length > 7 ? maxSegments + 1 : positive.length;
    final palette = _buildPalette(primaryColor, effectiveCount);

    if (positive.length <= 7) {
      for (var i = 0; i < positive.length; i++) {
        final cat = positive[i];
        items.add((
          name: CategoryUtils.getDisplayName(cat.name, context),
          total: cat.total,
          raw: cat,
          color: palette[i],
        ));
      }
    } else {
      for (var i = 0; i < maxSegments; i++) {
        final cat = positive[i];
        items.add((
          name: CategoryUtils.getDisplayName(cat.name, context),
          total: cat.total,
          raw: cat,
          color: palette[i],
        ));
      }
      final otherTotal =
          positive.skip(maxSegments).fold<double>(0, (sum, c) => sum + c.total);
      if (otherTotal > 0) {
        items.add((
          name: l.v4InsightsOtherCategories,
          total: otherTotal,
          raw: null,
          color: const Color(0xFF9E9E9E),
        ));
      }
    }

    if (_selectedIndex >= items.length) {
      _selectedIndex = 0;
    }

    final selectedItem = items[_selectedIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        // 环形图自适应直径
        final double chartDiameter = (maxWidth * 0.54).clamp(172.0, 206.0);
        final double chartHeight = chartDiameter + 28.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部 Donut Chart 环形图与折线标注区域
            Center(
              child: SizedBox(
                width: maxWidth,
                height: chartHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 自定义绘制多色环形与指示折线
                    AnimatedBuilder(
                      animation: _sweepAnimation,
                      builder: (context, _) {
                        return GestureDetector(
                          onTapUp: (details) {
                            final localOffset = details.localPosition;
                            final center = Offset(
                              maxWidth / 2,
                              chartHeight / 2,
                            );
                            final dx = localOffset.dx - center.dx;
                            final dy = localOffset.dy - center.dy;
                            final distance = math.sqrt(dx * dx + dy * dy);
                            final outerR = chartDiameter / 2;
                            final innerR = outerR * 0.62;

                            // 仅响应在圆环区域的点击
                            if (distance >= innerR - 8 &&
                                distance <= outerR + 12) {
                              var touchAngle = math.atan2(dy, dx);
                              // 转换到以顶部 12点钟(-pi/2) 为起始的顺时针角度 [0, 2*pi)
                              touchAngle += math.pi / 2;
                              if (touchAngle < 0) touchAngle += 2 * math.pi;

                              double currentAngle = 0.0;
                              for (var i = 0; i < items.length; i++) {
                                final segAngle = (items[i].total /
                                        widget.data.total) *
                                    2 *
                                    math.pi;
                                if (touchAngle >= currentAngle &&
                                    touchAngle <= currentAngle + segAngle) {
                                  if (_selectedIndex != i) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedIndex = i);
                                  }
                                  break;
                                }
                                currentAngle += segAngle;
                              }
                            }
                          },
                          child: CustomPaint(
                            size: Size(maxWidth, chartHeight),
                            painter: _VivoDonutChartPainter(
                              items: items,
                              total: widget.data.total,
                              selectedIndex: _selectedIndex,
                              animationProgress: _sweepAnimation.value,
                              diameter: chartDiameter,
                              isDark: isDark,
                            ),
                          ),
                        );
                      },
                    ),

                    // 环心数据聚焦（大字金额 + 分类名称）
                    IgnorePointer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: child,
                            ),
                            child: Text(
                              hide
                                  ? '****'
                                  : formatMoneyCompact(
                                      selectedItem.total,
                                      trimZeros: false,
                                      signed: false,
                                    ),
                              key: ValueKey(
                                  'pie-amt-${selectedItem.name}-${selectedItem.total}'),
                              style: TextStyle(
                                fontSize: chartDiameter < 180 ? 20.0 : 22.5,
                                fontWeight: FontWeight.w700,
                                color: OriginTokens.textPrimary(context),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Text(
                              '${selectedItem.name} (元)',
                              key: ValueKey('pie-lbl-${selectedItem.name}'),
                              style: TextStyle(
                                fontSize: 11.0,
                                color: OriginTokens.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 2. 下方分类占比明细与颜色标注列表 (对齐 vivo 钱包样式)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 0.5,
                color: isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0x0F000000),
                indent: 14,
                endIndent: 14,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final fraction = widget.data.total > 0
                    ? (item.total / widget.data.total)
                    : 0.0;
                final pctStr = '${(fraction * 100).toStringAsFixed(1)}%';

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10.0),
                    onTap: () {
                      if (item.raw?.id != null) {
                        HapticFeedback.lightImpact();
                        _openCategoryDetail(item.raw!.id!, item.raw!.name);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                      child: Row(
                        children: [
                          // 对应扇区颜色小方圆角指示块
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // 分类名称与进度胶囊
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 13.0,
                                        color: OriginTokens.textPrimary(context),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      pctStr,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: OriginTokens.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                // 占比横条进度
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: Container(
                                    height: 3.5,
                                    width: double.infinity,
                                    color: isDark
                                        ? const Color(0x1AFFFFFF)
                                        : const Color(0xFFEEEEEE),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: fraction.clamp(0.01, 1.0),
                                      child: Container(color: item.color),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // 金额与跳转进入详情箭头
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                hide
                                    ? '****'
                                    : (widget.type == 'income' ? '+' : '-') +
                                        formatMoneyCompact(
                                          item.total,
                                          signed: false,
                                          trimZeros: false,
                                        ),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: OriginTokens.textPrimary(context),
                                ),
                              ),
                              if (item.raw?.id != null) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: OriginTokens.textSecondary(context),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// 仿 vivo 钱包多色 Donut Chart 画笔 (包含扇区、微间距、突出高亮与引出折线标注)
class _VivoDonutChartPainter extends CustomPainter {
  _VivoDonutChartPainter({
    required this.items,
    required this.total,
    required this.selectedIndex,
    required this.animationProgress,
    required this.diameter,
    required this.isDark,
  });

  final List<({String name, double total, AnalyticsCategory? raw, Color color})>
      items;
  final double total;
  final int selectedIndex;
  final double animationProgress;
  final double diameter;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty || total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseOuterRadius = diameter / 2;
    // 环宽约占半径的 36%，通透精致
    final ringWidth = baseOuterRadius * 0.36;
    final baseInnerRadius = baseOuterRadius - ringWidth;

    // 起始角：从 12 点钟位置开始 (-pi / 2)
    const double startOffsetAngle = -math.pi / 2;
    // 当前全局动画能画到的最大总弧度
    final double maxSweep = 2 * math.pi * animationProgress;

    double accumulatedAngle = 0.0;
    Offset? leaderStartPt;
    Offset? leaderKneePt;
    Offset? leaderEndPt;
    Color? selectedColor;
    String? leaderText;
    bool isLeaderOnRight = true;

    // 1. 遍历绘制每个扇区
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final itemFraction = item.total / total;
      final fullSweepAngle = itemFraction * 2 * math.pi;

      if (accumulatedAngle >= maxSweep) break;

      // 根据动画进度截断当前扇区的绘制弧度
      final availableSweep = math.min(fullSweepAngle, maxSweep - accumulatedAngle);
      if (availableSweep <= 0) break;

      final isSelected = i == selectedIndex;
      // 选中项稍向外扩张 2.5dp，带来自然立体感
      final double outerR =
          isSelected ? baseOuterRadius + 2.5 : baseOuterRadius;
      final double innerR =
          isSelected ? baseInnerRadius - 1.0 : baseInnerRadius;

      final startAngle = startOffsetAngle + accumulatedAngle;

      // 扇区间保留微小间隙 (约 1.5dp)
      const double gapRadius = 0.012;
      double adjustedStartAngle = startAngle;
      double adjustedSweepAngle = availableSweep;

      if (items.length > 1 && availableSweep > gapRadius * 2) {
        adjustedStartAngle += gapRadius;
        adjustedSweepAngle -= gapRadius * 2;
      }

      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = item.color;

      // 构造扇形环 Path
      final path = Path();
      path.arcTo(
        Rect.fromCircle(center: center, radius: outerR),
        adjustedStartAngle,
        adjustedSweepAngle,
        false,
      );
      path.arcTo(
        Rect.fromCircle(center: center, radius: innerR),
        adjustedStartAngle + adjustedSweepAngle,
        -adjustedSweepAngle,
        false,
      );
      path.close();

      canvas.drawPath(path, paint);

      // 计算选中扇区的折线引出线标注参数
      if (isSelected) {
        selectedColor = item.color;
        final midAngle = startAngle + availableSweep / 2;
        // 如果是单项 100% 占比，固定引出向右下 45 度角（如 vivo 钱包参考图）
        final effectiveAngle =
            items.length == 1 ? (math.pi / 4) : midAngle;

        isLeaderOnRight = math.cos(effectiveAngle) >= -0.15;

        // 起点：扇区外径外侧 2dp
        final p0Radius = outerR + 2.0;
        leaderStartPt = Offset(
          center.dx + math.cos(effectiveAngle) * p0Radius,
          center.dy + math.sin(effectiveAngle) * p0Radius,
        );

        // 拐点：外向延伸约 14dp
        final p1Radius = outerR + 15.0;
        final rawKnee = Offset(
          center.dx + math.cos(effectiveAngle) * p1Radius,
          center.dy + math.sin(effectiveAngle) * p1Radius,
        );

        // 保证拐点不会超出画布上下边界
        final clampedKneeY =
            rawKnee.dy.clamp(14.0, size.height - 14.0);
        leaderKneePt = Offset(rawKnee.dx, clampedKneeY);

        // 水平终点：向左或向右水平延伸 30dp
        const double hLen = 30.0;
        final endX = isLeaderOnRight
            ? math.min(leaderKneePt.dx + hLen, size.width - 6.0)
            : math.max(leaderKneePt.dx - hLen, 6.0);
        leaderEndPt = Offset(endX, leaderKneePt.dy);

        final pct = (itemFraction * 100).toStringAsFixed(1);
        leaderText = '${item.name} $pct%';
      }

      accumulatedAngle += fullSweepAngle;
    }

    // 2. 绘制 vivo 钱包风格指示折线与文字标注
    if (animationProgress > 0.4 &&
        leaderStartPt != null &&
        leaderKneePt != null &&
        leaderEndPt != null &&
        leaderText != null &&
        selectedColor != null) {
      final lineProgress =
          ((animationProgress - 0.4) / 0.6).clamp(0.0, 1.0);
      final lineAlpha = (lineProgress * 255).toInt();

      final linePaint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..color = selectedColor.withAlpha(lineAlpha);

      // 绘制第一段：起点到拐点
      final currentKnee = Offset.lerp(leaderStartPt, leaderKneePt, lineProgress)!;
      canvas.drawLine(leaderStartPt, currentKnee, linePaint);

      // 绘制第二段：拐点到水平端点
      if (lineProgress > 0.6) {
        final hProgress = ((lineProgress - 0.6) / 0.4).clamp(0.0, 1.0);
        final currentEnd = Offset.lerp(leaderKneePt, leaderEndPt, hProgress)!;
        canvas.drawLine(leaderKneePt, currentEnd, linePaint);

        // 水平线末端上方绘制标注文字
        if (hProgress > 0.5) {
          final textSpan = TextSpan(
            text: leaderText,
            style: TextStyle(
              fontSize: 10.0,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFF333333),
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          )..layout();

          final textX = isLeaderOnRight
              ? leaderKneePt.dx + 4.0
              : leaderEndPt.dx;
          final textY = leaderKneePt.dy - textPainter.height - 2.0;

          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VivoDonutChartPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.items != items ||
      oldDelegate.total != total ||
      oldDelegate.isDark != isDark;
}
