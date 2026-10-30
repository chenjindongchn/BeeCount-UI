import 'dart:math' as math;
import 'package:flutter/material.dart';

/// vivo OriginOS / 蓝河工具箱风格底部导航动态图标类型
enum OriginNavigationIconType {
  /// 明细（账单票据：外框摇摆回弹 + 内部 3 行圆点与横线错峰打印刷出）
  receipt,

  /// 洞察（扇形统计：主扇盘顺时针扫掠张开 + 右上独立切片对角弹射分离再回吸）
  insights,

  /// 资产（账户皮夹：右侧磁吸搭扣滑开 + 顶部银行卡向上抽出翘起再塞回锁合）
  assets,
}

/// 蓝河工具箱 `OriginAnimatedNavigationIcon.kt` 同款动态导航图标组件
///
/// 核心特性：
/// 1. 700ms 统一线性时钟驱动全局缩放包络 (`1.0 -> 0.0 -> 1.20x -> 1.0`) 与透明度包络；
/// 2. 130ms 轮廓态 (`filled = false`) 到实心镂空态 (`filled = true`) 平滑过渡；
/// 3. 图标弹出后 (`t = 0.26 ~ 0.98`) 内部独立零件执行专属二级物理动效；
/// 4. 支持首次静止渲染、切换 Tab 自动播放、点击当前已选 Tab 重播 (`replayTrigger`)，连点不打断当前播放。
class OriginAnimatedNavIcon extends StatefulWidget {
  final OriginNavigationIconType icon;
  final bool selected;
  final Color color;
  final double size;

  /// 每次递增时，若当前处于选中状态且未在播放中，则触发原地重播动效
  final int replayTrigger;

  const OriginAnimatedNavIcon({
    super.key,
    required this.icon,
    required this.selected,
    required this.color,
    this.size = 20.0,
    this.replayTrigger = 0,
  });

  @override
  State<OriginAnimatedNavIcon> createState() => _OriginAnimatedNavIconState();
}

class _OriginAnimatedNavIconState extends State<OriginAnimatedNavIcon>
    with TickerProviderStateMixin {
  late final AnimationController _clockController;
  late final AnimationController _fillController;

  @override
  void initState() {
    super.initState();
    // 700ms 主时钟：初始静止在 1.0
    _clockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1.0,
    );
    // 130ms 轮廓/实心切换时钟
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  /// 复刻蓝河工具箱 `OriginNavigationIconAnimationState.replay()`：
  /// 仅在选中状态且当前未处于播放途中时从 0 -> 1 播放 700ms，快速连点保持当前动效不断帧。
  void _replay() {
    if (!widget.selected || _clockController.isAnimating) return;
    _clockController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant OriginAnimatedNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entered = widget.selected && !oldWidget.selected;

    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _fillController.forward();
      } else {
        _fillController.reverse();
      }
    }

    if (!widget.selected) {
      _clockController.stop();
      _clockController.value = 1.0;
    } else if (entered) {
      _replay();
    } else if (widget.replayTrigger != oldWidget.replayTrigger) {
      _replay();
    }
  }

  @override
  void dispose() {
    _clockController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_clockController, _fillController]),
      builder: (context, _) {
        final t = _clockController.value;
        final scale = _OriginNavMotionMath.navigationIconScale(t);
        final alpha = _OriginNavMotionMath.iconAlpha(t).clamp(0.0, 1.0);

        return Opacity(
          opacity: alpha,
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _OriginAnimatedNavIconPainter(
                  icon: widget.icon,
                  progress: t,
                  fill: _fillController.value,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 1:1 复刻蓝河工具箱 `OriginAnimatedNavigationIcon.kt` 的缓动曲线与数学函数
class _OriginNavMotionMath {
  _OriginNavMotionMath._();

  static const Cubic shrinkEase = Cubic(0.42, 0.0, 1.0, 1.0);
  static const Cubic popEase = Cubic(0.14, 0.0, 0.45, 1.0);
  static const Cubic settleEase = Cubic(0.11, 0.0, 0.42, 1.0);
  static const Cubic partEase = Cubic(0.25, 0.0, 0.35, 1.0);
  static const Cubic rotationEase = Cubic(0.23, 0.01, 0.45, 1.0);

  static double segment(double t, double start, double end) {
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }

  static double navigationIconScale(double t) {
    const s1 = 167.0 / 651.0;
    const s2 = 184.0 / 651.0;
    const s3 = 401.0 / 651.0;
    if (t < s1) {
      return 1.0 - shrinkEase.transform(segment(t, 0.0, s1));
    }
    if (t < s2) {
      return 0.0;
    }
    if (t < s3) {
      return 1.2 * popEase.transform(segment(t, s2, s3));
    }
    return 1.2 - 0.2 * settleEase.transform(segment(t, s3, 1.0));
  }

  static double iconAlpha(double t) {
    const s1 = 167.0 / 651.0;
    const s2 = 184.0 / 651.0;
    const s3 = 401.0 / 651.0;
    if (t < s1) {
      return 1.0 - shrinkEase.transform(segment(t, 0.0, s1));
    }
    if (t < s2) {
      return 0.0;
    }
    return popEase.transform(segment(t, s2, s3));
  }

  static double navigationProfileWave(double t, double start) {
    if (t <= start || t >= 1.0) return 0.0;
    final u = (t - start) / (1.0 - start);
    return 2.4 *
        (1.0 - math.exp(-16.0 * u)) *
        math.exp(-2.4 * u) *
        math.sin(2.0 * math.pi * 1.05 * u) *
        (1.0 - u) *
        (1.0 - u);
  }
}

class _OriginAnimatedNavIconPainter extends CustomPainter {
  final OriginNavigationIconType icon;
  final double progress;
  final double fill;
  final Color color;

  const _OriginAnimatedNavIconPainter({
    required this.icon,
    required this.progress,
    required this.fill,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 24.0, size.height / 24.0);

    switch (icon) {
      case OriginNavigationIconType.receipt:
        _paintReceipt(canvas, progress, fill, color);
        break;
      case OriginNavigationIconType.insights:
        _paintInsights(canvas, progress, fill, color);
        break;
      case OriginNavigationIconType.assets:
        _paintAssets(canvas, progress, fill, color);
        break;
    }

    canvas.restore();
  }

  /// 1. 绘制【明细】动态图标：
  /// - 锯齿底账单外框三段式俯仰摇摆回正；
  /// - 内部 3 行「圆点 + 账目横线」在 t=0.30~0.95 依次 Q 弹跳出并从左向右刷出。
  void _paintReceipt(Canvas canvas, double t, double fill, Color color) {
    final uTilt = _OriginNavMotionMath.segment(t, 0.27, 0.92);
    double rotDeg = 0.0;
    double dyBody = 0.0;
    if (t >= 0.18 && t < 0.98) {
      if (uTilt < 0.4) {
        final p = _OriginNavMotionMath.partEase.transform(
          _OriginNavMotionMath.segment(uTilt, 0.0, 0.4),
        );
        rotDeg = -9.0 + 15.0 * p;
        dyBody = 1.0 - 1.9 * p;
      } else if (uTilt < 0.72) {
        final p = _OriginNavMotionMath.partEase.transform(
          _OriginNavMotionMath.segment(uTilt, 0.4, 0.72),
        );
        rotDeg = 6.0 - 8.5 * p;
        dyBody = -0.9 + 1.1 * p;
      } else {
        final p = _OriginNavMotionMath.partEase.transform(
          _OriginNavMotionMath.segment(uTilt, 0.72, 1.0),
        );
        rotDeg = -2.5 * (1.0 - p);
        dyBody = 0.2 * (1.0 - p);
      }
    }

    canvas.save();
    canvas.translate(12.0, 12.0 + dyBody);
    canvas.rotate(rotDeg * math.pi / 180.0);
    canvas.translate(-12.0, -12.0);

    final bodyPath = Path()
      ..moveTo(5.0, 6.2)
      ..quadraticBezierTo(5.0, 4.0, 7.2, 4.0)
      ..lineTo(16.8, 4.0)
      ..quadraticBezierTo(19.0, 4.0, 19.0, 6.2)
      ..lineTo(19.0, 19.6)
      ..lineTo(16.67, 17.9)
      ..lineTo(14.33, 19.6)
      ..lineTo(12.0, 17.9)
      ..lineTo(9.67, 19.6)
      ..lineTo(7.33, 17.9)
      ..lineTo(5.0, 19.6)
      ..close();

    const rows = [
      (y: 8.2, xEnd: 16.0, startT: 0.30, endT: 0.60),
      (y: 11.4, xEnd: 16.0, startT: 0.45, endT: 0.78),
      (y: 14.6, xEnd: 13.6, startT: 0.60, endT: 0.95),
    ];

    void drawInternalRows(Canvas c, Paint dotPaint, Paint linePaint) {
      final popAt06 = _OriginNavMotionMath.popEase.transform(0.6);
      for (final row in rows) {
        double prog = 1.0;
        double dotScale = 1.0;
        double rowShiftY = 0.0;

        if (t >= 0.18 && t < 0.99) {
          final raw = _OriginNavMotionMath.segment(t, row.startT, row.endT);
          final eased = _OriginNavMotionMath.popEase.transform(raw);
          final overshoot = raw > 0.6
              ? 1.0 + 0.16 * math.sin(((raw - 0.6) / 0.4) * math.pi)
              : (eased / popAt06);
          prog = raw <= 0.02 ? 0.0 : overshoot.clamp(0.0, 1.16);
          if (raw <= 0.02) {
            dotScale = 0.0;
          } else if (raw < 0.5) {
            dotScale = _OriginNavMotionMath.popEase.transform(
                  _OriginNavMotionMath.segment(raw, 0.0, 0.5),
                ) *
                1.25;
          } else {
            dotScale = 1.25 -
                0.25 *
                    _OriginNavMotionMath.settleEase.transform(
                      _OriginNavMotionMath.segment(raw, 0.5, 1.0),
                    );
          }
          rowShiftY = (1.0 - eased) * 1.6;
        }

        if (dotScale > 0.02) {
          c.drawCircle(
            Offset(8.0, row.y + rowShiftY),
            0.92 * dotScale,
            dotPaint,
          );
        }
        if (prog > 0.03) {
          const x0 = 10.5;
          final curX1 = x0 + (row.xEnd - x0) * prog;
          c.drawLine(
            Offset(x0, row.y + rowShiftY),
            Offset(curX1, row.y + rowShiftY),
            linePaint,
          );
        }
      }
    }

    // 1) 实心镂空态绘制 (saveLayer + BlendMode.clear)
    if (fill > 0.01) {
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * fill);
      canvas.drawPath(bodyPath, fillPaint);

      final clearDotPaint = Paint()
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.clear;
      final clearLinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.clear;
      drawInternalRows(canvas, clearDotPaint, clearLinePaint);
      canvas.restore();
    }

    // 2) 轮廓态绘制
    if (fill < 0.99) {
      final strokeAlpha = (color.a * (1.0 - fill)).clamp(0.0, 1.0);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: strokeAlpha);
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: strokeAlpha);

      canvas.drawPath(bodyPath, strokePaint);
      drawInternalRows(canvas, dotPaint, strokePaint);
    }

    canvas.restore();
  }

  /// 2. 绘制【洞察】动态图标：
  /// - 左下 270° 主扇盘从 45° 顺时针动态扫掠展开至 270° 并旋转归位；
  /// - 右上 90° 独立统计切片沿 45° 对角线向右上大幅弹射飞出分离，随后磁吸回位。
  void _paintInsights(Canvas canvas, double t, double fill, Color color) {
    // A. 左下 270° 主扇盘
    double sweepDeg = 270.0;
    double baseRotDeg = 0.0;
    if (t >= 0.18 && t < 0.99) {
      final sweepProg = _OriginNavMotionMath.rotationEase.transform(
        _OriginNavMotionMath.segment(t, 0.26, 0.78),
      );
      sweepDeg = 45.0 + 225.0 * sweepProg;
      final rotProg = _OriginNavMotionMath.rotationEase.transform(
        _OriginNavMotionMath.segment(t, 0.26, 0.85),
      );
      baseRotDeg = -45.0 * (1.0 - rotProg);
    }

    canvas.save();
    canvas.translate(11.0, 13.0);
    canvas.rotate(baseRotDeg * math.pi / 180.0);
    canvas.translate(-11.0, -13.0);

    final mainPiePath = Path()
      ..moveTo(11.0, 13.0)
      ..arcTo(
        Rect.fromCircle(center: const Offset(11.0, 13.0), radius: 7.2),
        0.0,
        sweepDeg * math.pi / 180.0,
        false,
      )
      ..close();

    if (fill > 0.01) {
      canvas.drawPath(
        mainPiePath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: color.a * fill),
      );
    }
    if (fill < 0.99) {
      canvas.drawPath(
        mainPiePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: color.a * (1.0 - fill)),
      );
    }
    canvas.restore();

    // B. 右上角 90° 独立切片
    double sliceOffset = 0.0;
    double sliceScale = 1.0;
    double sliceRotDeg = 0.0;
    if (t >= 0.18 && t < 0.99) {
      final uSlice = _OriginNavMotionMath.segment(t, 0.34, 0.98);
      if (uSlice < 0.46) {
        final p = _OriginNavMotionMath.popEase.transform(
          _OriginNavMotionMath.segment(uSlice, 0.0, 0.46),
        );
        sliceOffset = 3.5 * p;
        sliceScale = 0.85 + 0.30 * p;
        sliceRotDeg = 16.0 * p;
      } else if (uSlice < 0.80) {
        final p = _OriginNavMotionMath.partEase.transform(
          _OriginNavMotionMath.segment(uSlice, 0.46, 0.80),
        );
        sliceOffset = 3.5 - 3.9 * p;
        sliceScale = 1.15 - 0.17 * p;
        sliceRotDeg = 16.0 - 21.0 * p;
      } else {
        final p = _OriginNavMotionMath.settleEase.transform(
          _OriginNavMotionMath.segment(uSlice, 0.80, 1.0),
        );
        sliceOffset = -0.4 * (1.0 - p);
        sliceScale = 0.98 + 0.02 * p;
        sliceRotDeg = -5.0 * (1.0 - p);
      }
    }

    final pivotX = 13.2 + sliceOffset * 0.72;
    final pivotY = 10.8 - sliceOffset * 0.72;

    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(sliceRotDeg * math.pi / 180.0);
    canvas.scale(sliceScale, sliceScale);
    canvas.translate(-pivotX, -pivotY);

    final slicePath = Path()
      ..moveTo(pivotX, pivotY)
      ..arcTo(
        Rect.fromCircle(center: Offset(pivotX, pivotY), radius: 6.8),
        -math.pi / 2.0,
        math.pi / 2.0,
        false,
      )
      ..close();

    if (fill > 0.01) {
      canvas.drawPath(
        slicePath,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: color.a * fill),
      );
    }
    if (fill < 0.99) {
      canvas.drawPath(
        slicePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.65
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: color.a * (1.0 - fill)),
      );
    }
    canvas.restore();
  }

  /// 3. 绘制【资产】动态图标：
  /// - 部件 1（顶部银行卡）：从皮夹顶部槽位向上大幅弹出翘起（露出卡面横线）再塞回槽位；
  /// - 部件 2（右侧磁吸圆珠搭扣）：先向右滑开解锁，等卡片塞回后向左扣合锁紧；
  /// - 部件 3（皮夹主包身）：随卡片塞回产生 navigationProfileWave 阻尼挤压回弹。
  void _paintAssets(Canvas canvas, double t, double fill, Color color) {
    final bodyWave = _OriginNavMotionMath.navigationProfileWave(t, 0.30);
    double cardLiftY = 0.0;
    double cardTiltDeg = 0.0;
    double claspSlideX = 0.0;

    if (t >= 0.18 && t < 0.99) {
      final u = _OriginNavMotionMath.segment(t, 0.32, 0.98);
      if (u < 0.46) {
        final p = _OriginNavMotionMath.popEase.transform(
          _OriginNavMotionMath.segment(u, 0.0, 0.46),
        );
        cardLiftY = -3.4 * p;
        cardTiltDeg = -9.5 * p;
        claspSlideX = 2.6 * p;
      } else if (u < 0.80) {
        final p = _OriginNavMotionMath.partEase.transform(
          _OriginNavMotionMath.segment(u, 0.46, 0.80),
        );
        cardLiftY = -3.4 + 3.8 * p;
        cardTiltDeg = -9.5 + 11.5 * p;
        claspSlideX = 2.6 - 3.0 * p;
      } else {
        final p = _OriginNavMotionMath.settleEase.transform(
          _OriginNavMotionMath.segment(u, 0.80, 1.0),
        );
        cardLiftY = 0.4 * (1.0 - p);
        cardTiltDeg = 2.0 * (1.0 - p);
        claspSlideX = -0.4 * (1.0 - p);
      }
    }

    final cardStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // --- 部件 1：顶部可抽出的银行卡 ---
    canvas.save();
    canvas.translate(11.5, 8.2 + cardLiftY);
    canvas.rotate(cardTiltDeg * math.pi / 180.0);
    canvas.translate(-11.5, -8.2);

    final cardPath = Path()
      ..moveTo(6.0, 9.2)
      ..lineTo(6.0, 6.2)
      ..quadraticBezierTo(6.0, 4.5, 7.7, 4.5)
      ..lineTo(15.7, 4.5)
      ..quadraticBezierTo(17.4, 4.5, 17.4, 6.2)
      ..lineTo(17.4, 9.2);
    canvas.drawPath(cardPath, cardStrokePaint);

    if (cardLiftY < -0.6) {
      canvas.drawLine(
        const Offset(8.4, 6.7),
        const Offset(12.6, 6.7),
        cardStrokePaint,
      );
    }
    canvas.restore();

    // --- 部件 2 & 3：皮夹包身 + 右侧可开合磁吸搭扣 ---
    canvas.save();
    canvas.translate(12.0, 14.5 - 0.38 * bodyWave);
    canvas.scale(1.0 + 0.022 * bodyWave, 1.0 - 0.024 * bodyWave);
    canvas.translate(-12.0, -14.5);

    final cx = 13.6 + claspSlideX;
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.8, 8.2, 15.6, 11.2),
      const Radius.circular(2.8),
    );
    final claspRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx, 11.4, 6.6, 4.8),
      const Radius.circular(2.2),
    );

    // 1) 实心镂空态绘制
    if (fill > 0.01) {
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: color.a * fill);

      // 实心主包身
      canvas.drawRRect(bodyRRect, fillPaint);

      // 镂空出右侧搭扣凹槽外框
      canvas.drawRRect(
        claspRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.75
          ..blendMode = BlendMode.clear,
      );

      // 绘制实心搭扣块
      canvas.drawRRect(claspRRect, fillPaint);

      // 镂空内部锁珠圆点
      canvas.drawCircle(
        Offset(cx + 2.4, 13.8),
        1.15,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.clear,
      );
      canvas.restore();
    }

    // 2) 轮廓态绘制
    if (fill < 0.99) {
      canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
      final strokeAlpha = (color.a * (1.0 - fill)).clamp(0.0, 1.0);
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.65
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: strokeAlpha);

      canvas.drawRRect(bodyRRect, strokePaint);

      // 擦除搭扣内部重叠的包身右边框
      canvas.drawRRect(
        claspRRect,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.clear,
      );

      // 绘制搭扣轮廓与锁珠圆点
      canvas.drawRRect(claspRRect, strokePaint);
      canvas.drawCircle(
        Offset(cx + 2.4, 13.8),
        1.05,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: strokeAlpha),
      );
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OriginAnimatedNavIconPainter oldDelegate) {
    return oldDelegate.icon != icon ||
        oldDelegate.progress != progress ||
        oldDelegate.fill != fill ||
        oldDelegate.color != color;
  }
}
