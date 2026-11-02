import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Gemini 四色（固定，经典灵动科技感）
class GeminiVoiceColors {
  GeminiVoiceColors._();

  static const Color blue = Color(0xFF4285F4);
  static const Color purple = Color(0xFF9B72CB);
  static const Color pink = Color(0xFFD96570);
  static const Color yellow = Color(0xFFF4B400);

  static const List<Color> flow = [blue, purple, pink, yellow, blue];

  /// 失败态灰阶
  static const List<Color> grey = [
    Color(0xFF8E8E93),
    Color(0xFFAEAEB2),
    Color(0xFF8E8E93),
    Color(0xFFAEAEB2),
    Color(0xFF8E8E93),
  ];
}

/// 光场视觉模式
enum GeminiArcMode { listening, processing, success, failure }

/// Gemini 底部无边界流动极光光雾（去除突兀硬弧线，与背景柔和交融）
class GeminiGlowArc extends StatefulWidget {
  final double reveal;
  final double amplitude;
  final GeminiArcMode mode;
  final bool reduceMotion;

  const GeminiGlowArc({
    super.key,
    required this.reveal,
    required this.amplitude,
    this.mode = GeminiArcMode.listening,
    this.reduceMotion = false,
  });

  @override
  State<GeminiGlowArc> createState() => _GeminiGlowArcState();
}

class _GeminiGlowArcState extends State<GeminiGlowArc>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// 渐变流动相位
  double _flow = 0;

  /// 时间轴
  double _time = 0;

  /// 平滑振幅
  double _amp = 0;

  /// 成功亮闪
  double _flash = 0;

  /// 失败褪灰
  double _grey = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant GeminiGlowArc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == GeminiArcMode.success &&
        oldWidget.mode != GeminiArcMode.success) {
      _flash = 1.0;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    final speed = widget.mode == GeminiArcMode.processing ? 0.55 : 0.22;
    if (!widget.reduceMotion) {
      _flow = (_flow + dt * speed) % 1.0;
    }
    _time += dt;

    // 振幅平滑滤波
    final target = widget.amplitude.clamp(0.0, 1.0);
    final k = target > _amp ? 12.0 : 4.0;
    _amp += (target - _amp) * (1 - math.exp(-k * dt));

    if (_flash > 0) _flash = math.max(0, _flash - dt * 2.2);
    final greyTarget = widget.mode == GeminiArcMode.failure ? 1.0 : 0.0;
    _grey += (greyTarget - _grey) * (1 - math.exp(-6 * dt));

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FluidAuroraPainter(
        reveal: widget.reveal.clamp(0.0, 1.0),
        flow: _flow,
        time: _time,
        amp: _amp,
        flash: _flash,
        grey: _grey,
        showParticles: !widget.reduceMotion,
      ),
    );
  }
}

/// 纯粹的流体极光发光场渲染器（绝无生硬切边与硬描边弧线）
class _FluidAuroraPainter extends CustomPainter {
  final double reveal;
  final double flow;
  final double time;
  final double amp;
  final double flash;
  final double grey;
  final bool showParticles;

  _FluidAuroraPainter({
    required this.reveal,
    required this.flow,
    required this.time,
    required this.amp,
    required this.flash,
    required this.grey,
    required this.showParticles,
  });

  static const int _particleCount = 18;

  Color _tint(Color c, double alpha) {
    final lerped = Color.lerp(c, const Color(0xFF8E8E93), grey)!;
    return lerped.withValues(alpha: alpha.clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0 || size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final brightness = (1 + flash * 0.5);
    final totalAlpha = reveal * brightness;

    // 1. 底层大范围轻雾光（从底部平滑向顶部消散，无任何切割感）
    final baseRect = Rect.fromLTWH(0, h * 0.25, w, h * 0.75);
    final baseGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        _tint(GeminiVoiceColors.blue, 0.28 * totalAlpha),
        _tint(GeminiVoiceColors.purple, 0.16 * totalAlpha),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final basePaint = Paint()
      ..shader = baseGradient.createShader(baseRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 32);
    canvas.drawRect(baseRect, basePaint);

    // 2. 四色流体极光光斑（有机起伏，随振幅呼吸放大，交织融合）
    final orbs = [
      (GeminiVoiceColors.blue, 0.18, 0.85, 1.3, 0.0),
      (GeminiVoiceColors.purple, 0.42, 0.78, 1.8, 1.5),
      (GeminiVoiceColors.pink, 0.68, 0.82, 1.5, 3.1),
      (GeminiVoiceColors.yellow, 0.88, 0.86, 2.1, 4.4),
    ];

    for (final orb in orbs) {
      final (color, relX, relY, speed, phaseOffset) = orb;

      // 横向微幅缓动漂移
      final driftX = math.sin(time * speed * 0.6 + phaseOffset) * 24.0;
      final cx = (relX * w + driftX).clamp(0.0, w);

      // 纵向随音量振幅向上涌动（说话时光斑涌得更高更活跃）
      final surge = amp * 42.0 + math.sin(time * speed + phaseOffset) * 12.0;
      final cy = h * relY - surge;

      // 动态光晕半径（80dp ~ 150dp）
      final radius = (90.0 + amp * 55.0);
      final orbRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

      final orbPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            _tint(color, (0.48 + amp * 0.25) * totalAlpha),
            _tint(color, (0.22 + amp * 0.15) * totalAlpha),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(orbRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 42.0 + amp * 18.0);

      canvas.drawCircle(Offset(cx, cy), radius, orbPaint);
    }

    // 3. 星尘：从光雾中轻盈向上浮动消散
    if (showParticles) {
      final dotPaint = Paint();
      for (var i = 0; i < _particleCount; i++) {
        final seedX = _hash(i * 3 + 1);
        final seedSpeed = _hash(i * 3 + 2);
        final seedPhase = _hash(i * 3 + 3);
        final period = 3.0 + seedSpeed * 2.5;
        final t = ((time / period) + seedPhase) % 1.0;

        final x = seedX * w + math.sin(time * 0.9 + i) * 8;
        final y = h * (0.85 - t * 0.45);
        final alpha = math.sin(t * math.pi) * 0.65 * reveal * (1 - grey * 0.6);
        if (alpha <= 0.01) continue;

        dotPaint
          ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
        canvas.drawCircle(Offset(x, y), 0.9 + seedSpeed * 1.2, dotPaint);
      }
    }
  }

  double _hash(int n) {
    final v = math.sin(n * 12.9898 + 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _FluidAuroraPainter old) => true;
}
