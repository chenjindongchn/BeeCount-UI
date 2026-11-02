import 'dart:math' as math;
import 'package:flutter/material.dart';

/// vivo 蓝心小V × Siri 风格动态贝塞尔流体极光声浪 (OriginVoiceWaveVisualizer)
///
/// 具备双形态：
/// 1. 聆听/录音态：3 层相位错落的平滑贝塞尔水波，波峰随振幅（amplitude）实时涌动，中心带有呼吸光核；
/// 2. 思考/解析态：声浪收束转为极光光环（Aurora Shimmer Ring），伴随顺畅旋转与流光扩散。
class OriginVoiceWaveVisualizer extends StatefulWidget {
  /// 归一化实时音量振幅 (0.0 ~ 1.0)
  final double amplitude;

  /// 主题主色
  final Color primaryColor;

  /// 是否进入 AI 思考/解析状态
  final bool isProcessing;

  /// 画布高度，默认 110dp
  final double height;

  const OriginVoiceWaveVisualizer({
    super.key,
    required this.amplitude,
    required this.primaryColor,
    this.isProcessing = false,
    this.height = 110.0,
  });

  @override
  State<OriginVoiceWaveVisualizer> createState() =>
      _OriginVoiceWaveVisualizerState();
}

class _OriginVoiceWaveVisualizerState extends State<OriginVoiceWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  // 平滑滤波振幅（避免麦克风离散帧跳变）
  double _smoothedAmplitude = 0.0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant OriginVoiceWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 缓动平滑滤波 (Lerp: 65% 老值 + 35% 新值)
    _smoothedAmplitude =
        _smoothedAmplitude * 0.65 + widget.amplitude * 0.35;
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return CustomPaint(
            painter: _WaveAndOrbPainter(
              phase: _waveController.value * 2 * math.pi,
              amplitude: _smoothedAmplitude,
              primaryColor: widget.primaryColor,
              isProcessing: widget.isProcessing,
            ),
          );
        },
      ),
    );
  }
}

class _WaveAndOrbPainter extends CustomPainter {
  final double phase;
  final double amplitude;
  final Color primaryColor;
  final bool isProcessing;

  _WaveAndOrbPainter({
    required this.phase,
    required this.amplitude,
    required this.primaryColor,
    required this.isProcessing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    if (isProcessing) {
      _paintProcessingRing(canvas, size);
    } else {
      _paintFluidWaves(canvas, size);
    }
  }

  /// 绘制聆听状态下的多层贝塞尔流体声浪与中央脉冲光核
  void _paintFluidWaves(Canvas canvas, Size size) {
    final centerY = size.height * 0.55;
    final width = size.width;

    // 1. 绘制中心微光呼吸光核 (Glowing Orb)
    final orbRadius = 18.0 + (amplitude * 28.0);
    final orbRect = Rect.fromCircle(
      center: Offset(width * 0.5, centerY),
      radius: orbRadius,
    );
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.6 + amplitude * 0.3),
          const Color(0xFF00E5FF).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(orbRect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0 + amplitude * 12.0);
    canvas.drawCircle(Offset(width * 0.5, centerY), orbRadius, orbPaint);

    // 2. 绘制 3 层极光波形
    // 波 1: 灵动青 (前层主波)
    _drawSingleWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitudeFactor: (8.0 + amplitude * 36.0),
      frequency: 1.8,
      phaseOffset: phase,
      strokeColor: const Color(0xFF00E5FF),
      fillGradient: [
        const Color(0xFF00E5FF).withValues(alpha: 0.4),
        Colors.transparent,
      ],
      strokeWidth: 2.5,
    );

    // 波 2: 霓虹粉紫 (中层和声波)
    _drawSingleWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitudeFactor: (6.0 + amplitude * 28.0),
      frequency: 2.4,
      phaseOffset: -phase * 0.85 + 1.2,
      strokeColor: const Color(0xFFFF4081),
      fillGradient: [
        const Color(0xFFFF4081).withValues(alpha: 0.3),
        Colors.transparent,
      ],
      strokeWidth: 2.0,
    );

    // 波 3: 主题色极光波 (后层基底波)
    _drawSingleWave(
      canvas: canvas,
      size: size,
      centerY: centerY,
      amplitudeFactor: (5.0 + amplitude * 22.0),
      frequency: 1.2,
      phaseOffset: phase * 0.6 + 2.4,
      strokeColor: primaryColor,
      fillGradient: [
        primaryColor.withValues(alpha: 0.25),
        Colors.transparent,
      ],
      strokeWidth: 1.8,
    );
  }

  /// 绘制单条平滑正弦波及其下方渐变遮罩
  void _drawSingleWave({
    required Canvas canvas,
    required Size size,
    required double centerY,
    required double amplitudeFactor,
    required double frequency,
    required double phaseOffset,
    required Color strokeColor,
    required List<Color> fillGradient,
    required double strokeWidth,
  }) {
    final path = Path();
    final fillPath = Path();
    final width = size.width;
    const step = 4.0;

    fillPath.moveTo(0, size.height);

    for (double x = 0; x <= width; x += step) {
      // 两端渐隐的窗函数衰减 (Hanning Window 式衰减)，让波浪两端收拢在边缘
      final normalizedX = x / width;
      final window = math.sin(normalizedX * math.pi);

      final y = centerY +
          math.sin((normalizedX * frequency * 2 * math.pi) + phaseOffset) *
              amplitudeFactor *
              window;

      if (x == 0) {
        path.moveTo(x, y);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(width, size.height);
    fillPath.close();

    // 绘制填充渐变光影
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fillGradient,
      ).createShader(Rect.fromLTWH(0, centerY - amplitudeFactor, width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 绘制发光波形轮廓线条
    final strokePaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);
    canvas.drawPath(path, strokePaint);
  }

  /// 绘制思考中状态下的 Gemini / Siri 极光旋转光环
  void _paintProcessingRing(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    const ringRadius = 26.0;

    // 1. 中心微光
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.5),
          const Color(0xFF00E5FF).withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 40))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, 36, corePaint);

    // 2. 旋转的多彩极光环
    final sweepColors = [
      primaryColor,
      const Color(0xFF00E5FF),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF4081),
      primaryColor,
    ];

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: math.pi * 2,
      colors: sweepColors,
      transform: GradientRotation(phase * 1.5),
    );

    final ringPaint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromCircle(center: center, radius: ringRadius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);

    // 绘制有缺口的动态灵动光弧
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ringRadius),
      phase * 1.5,
      math.pi * 1.4,
      false,
      ringPaint,
    );

    // 3. 伴随轨道卫星小光点
    final orbitX = center.dx + math.cos(phase * 2.0) * (ringRadius + 7);
    final orbitY = center.dy + math.sin(phase * 2.0) * (ringRadius + 7);
    final dotPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
    canvas.drawCircle(Offset(orbitX, orbitY), 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WaveAndOrbPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isProcessing != isProcessing;
  }
}
