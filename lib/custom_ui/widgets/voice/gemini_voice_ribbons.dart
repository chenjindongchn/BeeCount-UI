import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'gemini_glow_arc.dart';

/// 丝带视觉模式
enum GeminiRibbonMode { listening, processing, success, failure }

/// Gemini 四色流体丝带
///
/// - listening：4 条正弦丝带随振幅起伏，安静时 2dp 微幅波动；
/// - processing：丝带汇成一条平线，高光左右扫动；
/// - success：丝带淡出，收拢成 ✓；
/// - failure：平线褪灰。
class GeminiVoiceRibbons extends StatefulWidget {
  final double amplitude;
  final GeminiRibbonMode mode;
  final bool reduceMotion;

  const GeminiVoiceRibbons({
    super.key,
    required this.amplitude,
    required this.mode,
    this.reduceMotion = false,
  });

  @override
  State<GeminiVoiceRibbons> createState() => _GeminiVoiceRibbonsState();
}

class _GeminiVoiceRibbonsState extends State<GeminiVoiceRibbons>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  double _amp = 0;

  /// 丝带 → 平线 汇聚进度
  double _merge = 0;

  /// ✓ 绘制进度
  double _check = 0;

  /// 褪灰进度
  double _grey = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  double _approach(double cur, double target, double k, double dt) =>
      cur + (target - cur) * (1 - math.exp(-k * dt));

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (!widget.reduceMotion) _time += dt;

    final mode = widget.mode;
    final target = mode == GeminiRibbonMode.listening
        ? widget.amplitude.clamp(0.0, 1.0)
        : 0.0;
    _amp = _approach(_amp, target, target > _amp ? 16 : 5, dt);
    _merge = _approach(
        _merge, mode == GeminiRibbonMode.listening ? 0 : 1, 9, dt);
    if (mode == GeminiRibbonMode.success) {
      _check = math.min(1, _check + dt / 0.36);
    } else {
      _check = 0;
    }
    _grey = _approach(_grey, mode == GeminiRibbonMode.failure ? 1 : 0, 6, dt);
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
      painter: _RibbonsPainter(
        time: _time,
        amp: _amp,
        merge: _merge,
        check: _check,
        grey: _grey,
        processing: widget.mode == GeminiRibbonMode.processing,
      ),
    );
  }
}

class _RibbonsPainter extends CustomPainter {
  final double time;
  final double amp;
  final double merge;
  final double check;
  final double grey;
  final bool processing;

  _RibbonsPainter({
    required this.time,
    required this.amp,
    required this.merge,
    required this.check,
    required this.grey,
    required this.processing,
  });

  // 每条丝带：颜色、频率、速度、相位偏移、振幅系数
  static const _ribbons = [
    (GeminiVoiceColors.blue, 1.6, 2.4, 0.0, 1.0),
    (GeminiVoiceColors.purple, 2.2, -1.9, 1.3, 0.82),
    (GeminiVoiceColors.pink, 1.2, 1.6, 2.6, 0.7),
    (GeminiVoiceColors.yellow, 2.8, -2.8, 3.9, 0.55),
  ];

  Color _tint(Color c) => Color.lerp(c, const Color(0xFF9E9E9E), grey)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final cy = size.height / 2;
    final ribbonsAlpha = (1 - check).clamp(0.0, 1.0);

    if (ribbonsAlpha > 0) {
      for (final r in _ribbons) {
        final (color, freq, speed, offset, factor) = r;
        // 安静时 2dp，说话时最高约 16dp；汇聚时压成平线
        final a = (2.0 + amp * 14.0) * factor * (1 - merge);
        final path = Path();
        const step = 2.0;
        for (double x = 0; x <= w; x += step) {
          final nx = x / w;
          // 两端收拢的窗函数
          final window = math.sin(nx * math.pi);
          final y = cy +
              math.sin(nx * freq * 2 * math.pi + time * speed + offset) *
                  a *
                  window;
          if (x == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        final paint = Paint()
          ..color = _tint(color).withValues(alpha: 0.9 * ribbonsAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, paint);
      }
    }

    // 识别中：平线上的高光左右扫动
    if (processing && merge > 0.5) {
      final t = (math.sin(time * 2.6) + 1) / 2; // 0~1 往返
      final cx = w * (0.1 + 0.8 * t);
      final shimmer = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(
            center: Offset(cx, cy), width: w * 0.35, height: 10))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: w * 0.35, height: 6),
          shimmer);
    }

    // 成功：✓ 逐笔绘制
    if (check > 0) {
      final s = size.height * 0.42;
      final p1 = Offset(w / 2 - s * 0.55, cy + s * 0.02);
      final p2 = Offset(w / 2 - s * 0.12, cy + s * 0.42);
      final p3 = Offset(w / 2 + s * 0.62, cy - s * 0.45);
      final len1 = (p2 - p1).distance;
      final len2 = (p3 - p2).distance;
      final drawn = Curves.easeOutCubic.transform(check) * (len1 + len2);

      final path = Path()..moveTo(p1.dx, p1.dy);
      if (drawn <= len1) {
        final q = Offset.lerp(p1, p2, drawn / len1)!;
        path.lineTo(q.dx, q.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final q = Offset.lerp(p2, p3, (drawn - len1) / len2)!;
        path.lineTo(q.dx, q.dy);
      }
      final paint = Paint()
        ..shader = const LinearGradient(colors: [
          GeminiVoiceColors.blue,
          GeminiVoiceColors.purple,
          GeminiVoiceColors.pink,
        ]).createShader(Rect.fromPoints(p1, p3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonsPainter old) => true;
}
