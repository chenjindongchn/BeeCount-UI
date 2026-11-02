import 'dart:math' as math;
import 'package:flutter/material.dart';

/// vivo 蓝心小V × iOS Siri × Gemini 屏幕全域边缘极光流光特效
///
/// 唤醒时在屏幕边缘渲染顺畅流动的多彩渐变霓虹光晕，并随麦克风振幅律动呼吸。
class OriginVoiceEdgeGlow extends StatefulWidget {
  /// 实时音量振幅归一化值 (0.0 ~ 1.0)
  final double amplitude;

  /// 主题强调色
  final Color primaryColor;

  /// 是否正在处理/思考中
  final bool isProcessing;

  const OriginVoiceEdgeGlow({
    super.key,
    required this.amplitude,
    required this.primaryColor,
    this.isProcessing = false,
  });

  @override
  State<OriginVoiceEdgeGlow> createState() => _OriginVoiceEdgeGlowState();
}

class _OriginVoiceEdgeGlowState extends State<OriginVoiceEdgeGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _EdgeGlowPainter(
            progress: _rotationController.value,
            amplitude: widget.amplitude,
            primaryColor: widget.primaryColor,
            isProcessing: widget.isProcessing,
          ),
        );
      },
    );
  }
}

class _EdgeGlowPainter extends CustomPainter {
  final double progress;
  final double amplitude;
  final Color primaryColor;
  final bool isProcessing;

  _EdgeGlowPainter({
    required this.progress,
    required this.amplitude,
    required this.primaryColor,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 基础流动角度与速度（思考中流动更快）
    final speedMultiplier = isProcessing ? 2.2 : 1.0;
    final angle = (progress * speedMultiplier * 2 * math.pi) % (2 * math.pi);

    // 动态光晕内渗宽度：随音量放大 (基础 32dp，最大 56dp)
    final glowWidth = (32.0 + (amplitude * 24.0)).clamp(28.0, 64.0);

    // 极光多色环：融合蓝心青、极光紫、灵动粉、暖琥珀与当前主色
    final colors = [
      primaryColor.withValues(alpha: 0.9),
      const Color(0xFF00E5FF).withValues(alpha: 0.85), // 灵动青
      const Color(0xFF7C4DFF).withValues(alpha: 0.9),  // 极光深紫
      const Color(0xFFFF4081).withValues(alpha: 0.85), // 霓虹玫粉
      const Color(0xFFFFAB40).withValues(alpha: 0.8),  // 琥珀微光
      primaryColor.withValues(alpha: 0.9),
    ];

    // 呼吸透明度因子 (0.75 ~ 1.0)
    final breath = 0.8 + 0.2 * math.sin(progress * 2 * math.pi);
    final totalAlpha = (0.7 + amplitude * 0.3) * breath;

    // 使用沿中心旋转的扫描渐变 SweepGradient
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: colors,
      transform: GradientRotation(angle),
    );

    final borderPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowWidth * 0.65);

    // 绘制边缘弥散发光层
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect.deflate(glowWidth * 0.35),
      borderPaint..color = borderPaint.color.withValues(alpha: totalAlpha.clamp(0.0, 1.0)),
    );

    // 底部再额外增强一抹高光律动微弧（类似 Siri / 蓝心小V 呼出时底部的聚光）
    final bottomGlowHeight = 120.0 + amplitude * 60.0;
    final bottomRect = Rect.fromLTWH(
      0,
      size.height - bottomGlowHeight,
      size.width,
      bottomGlowHeight,
    );

    final bottomGradient = RadialGradient(
      center: const Alignment(0.0, 1.1),
      radius: 0.85,
      colors: [
        primaryColor.withValues(alpha: (0.35 + amplitude * 0.25).clamp(0.0, 0.7)),
        const Color(0xFF7C4DFF).withValues(alpha: (0.2 + amplitude * 0.2).clamp(0.0, 0.5)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final bottomPaint = Paint()
      ..shader = bottomGradient.createShader(bottomRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);

    canvas.drawRect(bottomRect, bottomPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EdgeGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isProcessing != isProcessing;
  }
}
