import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// vivo OriginOS 风格开关 (OriginSwitch)
///
/// 严格遵循蓝河工具箱 `OriginUI/docs/01-switch-and-dark-mode.md` 与 vivo 框架源码
/// `com.android.internal.widget.VivoMoveSwitch.java` 运行时硬证据与设计规范：
///
/// 1. 【几何真值】
///    - 画布总宽 44.0dp，总高 26.0dp，触摸热区居中并支持外部布局约束；
///    - 开启态实心胶囊轨道：高度 14.0dp，圆角 7.0dp，随动画自左向右饱满展开；
///    - 关闭态空心描边轨道：高度 22.0dp，描边 2.72dp，圆角 11.0dp，开启时向右收缩淡出；
///    - 滑块位移中心点：关闭态 11.0dp（贴合左边缘 0dp），开启态 31.5dp（贴合右边缘 44dp）；
///    - 滑块外半径：关闭态 11.0dp（外径 22dp），开启态 12.5dp（外径 25dp）；
///    - 滑块彩色外环：笔宽 3.0dp。
///
/// 2. 【立体光效阴影 (Luminescent Glow Shadow)】
///    - 开启态滑块下方投射同色微光晕（模糊半径 6.5dp，Y 偏移 1.5dp），赋予原子悬浮感；
///    - 浅色模式下附带极微物理阴影，层次分明。
///
/// 3. 【按压“方圆”手感 (Square-Circle Feedback)】
///    - 按压时滑块不缩放，圆角由正圆向圆角方收缩（关闭态 6.0dp，开启态 8.0dp）；
///    - 伴随系统轻触振动反馈（HapticFeedback.lightImpact）。
///
/// 4. 【主题色动态接入】
///    - [activeColor] 默认直接读取 `Theme.of(context).colorScheme.primary`，
///      自动同步应用设置里的主题强调色，支持实时换肤。
class OriginSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final bool enabled;

  const OriginSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.enabled = true,
  });

  @override
  State<OriginSwitch> createState() => _OriginSwitchState();
}

class _OriginSwitchState extends State<OriginSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // 对齐 VivoMoveSwitch: anim_Duration = 250ms, PathInterpolator(0.2, 0.4, 0.2, 1.0)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.2, 0.4, 0.2, 1.0),
    );
  }

  @override
  void didUpdateWidget(covariant OriginSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled || widget.onChanged == null) return;
    HapticFeedback.lightImpact();
    widget.onChanged!(!widget.value);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled || widget.onChanged == null) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themePrimary =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;

    // 状态取色（严格对齐 OriginUI 规范）
    final Color ringOnColor = themePrimary;
    final Color ringOffColor =
        isDark ? const Color(0xFF5A5A5A) : const Color(0xFFCCCCCC);

    // 开启态实心轨道背景色（日间 26% alpha，夜间 38% alpha）
    final Color trackOnColor = themePrimary.withValues(
      alpha: isDark ? 0.38 : 0.26,
    );
    final Color trackOutlineColor =
        isDark ? const Color(0xFF383838) : const Color(0xFFE2E2E2);

    return Semantics(
      toggled: widget.value,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(44.0, 26.0),
                painter: _OriginSwitchPainter(
                  progress: _animation.value,
                  isPressed: _isPressed,
                  enabled: widget.enabled,
                  isDark: isDark,
                  ringOnColor: ringOnColor,
                  ringOffColor: ringOffColor,
                  trackOnColor: trackOnColor,
                  trackOutlineColor: trackOutlineColor,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// vivo MoveSwitch 逐像素 Canvas 绘制器
class _OriginSwitchPainter extends CustomPainter {
  final double progress; // 0.0 (关闭) ~ 1.0 (开启)
  final bool isPressed;
  final bool enabled;
  final bool isDark;
  final Color ringOnColor;
  final Color ringOffColor;
  final Color trackOnColor;
  final Color trackOutlineColor;

  _OriginSwitchPainter({
    required this.progress,
    required this.isPressed,
    required this.enabled,
    required this.isDark,
    required this.ringOnColor,
    required this.ringOffColor,
    required this.trackOnColor,
    required this.trackOutlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bgWidth = 44.0;
    final cy = size.height / 2.0;
    final bgRadio = progress.clamp(0.0, 1.0);

    // -------------------------------------------------------------------------
    // 1. 开启态实心胶囊轨道：高度 14dp，两端半圆 r=7dp，随 bgRadio 自左向右展开
    // -------------------------------------------------------------------------
    const bgOnHeight = 14.0;
    const onTrackR = bgOnHeight / 2.0;
    final onTrackWidth = (bgRadio < 0.5 ? 0.5 : bgRadio) * bgWidth;
    final onTrackAlpha = bgRadio < 0.5 ? bgRadio * 2.0 : 1.0;

    if (onTrackAlpha > 0.001) {
      final onTrackPaint = Paint()
        ..color = trackOnColor.withValues(
            alpha: trackOnColor.a * onTrackAlpha * (enabled ? 1.0 : 0.5))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.0, cy - onTrackR, onTrackWidth, bgOnHeight),
          const Radius.circular(onTrackR),
        ),
        onTrackPaint,
      );
    }

    // -------------------------------------------------------------------------
    // 2. 关闭态空心描边轨道：高度 22dp，描边 2.72dp，开启时向右收缩并淡出
    // -------------------------------------------------------------------------
    const bgOffHeight = 22.0;
    const bgOffLineWidth = 2.72;
    final offTrackAlpha = 1.0 - bgRadio;
    const halfStroke = bgOffLineWidth / 2.0;
    final offTrackLeft =
        halfStroke + (bgRadio <= 0.5 ? bgRadio : 0.5) * bgWidth;
    const offTrackRight = bgWidth - halfStroke;
    const offHalfHeight = bgOffHeight / 2.0;

    if (offTrackAlpha > 0.001 && offTrackRight > offTrackLeft) {
      final offTrackPaint = Paint()
        ..color = trackOutlineColor.withValues(
            alpha: trackOutlineColor.a * offTrackAlpha * (enabled ? 1.0 : 0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = bgOffLineWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            offTrackLeft,
            cy - offHalfHeight + halfStroke,
            offTrackRight - offTrackLeft,
            bgOffHeight - bgOffLineWidth,
          ),
          const Radius.circular(offHalfHeight),
        ),
        offTrackPaint,
      );
    }

    // -------------------------------------------------------------------------
    // 3. 滑块（Thumb）几何真值
    // x = ring_off_r + ratio * ((bg_width - ring_off_r) - ring_on_r)
    // -------------------------------------------------------------------------
    const ringOffR = 11.0; // 11.0
    const ringOnR = 12.5; // 12.5
    const ringLineWidth = 3.0; // 3.0

    final curRingR = ringOffR + (ringOnR - ringOffR) * bgRadio;
    final innerRadius = curRingR - ringLineWidth / 2.0;
    final thumbCenterX =
        ringOffR + bgRadio * ((bgWidth - ringOffR) - ringOnR);

    // -------------------------------------------------------------------------
    // 3.1 开启态立体光晕阴影 (Luminescent Glow Shadow)
    // -------------------------------------------------------------------------
    if (bgRadio > 0.01 && enabled) {
      final glowMaxAlpha = isDark ? 0.45 : 0.28;
      final currentGlowAlpha = glowMaxAlpha * bgRadio;

      final glowPaint = Paint()
        ..color = ringOnColor.withValues(alpha: currentGlowAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.5);

      canvas.drawCircle(
        Offset(thumbCenterX, cy + 1.5),
        innerRadius,
        glowPaint,
      );

      // 浅色模式下的微弱物理投影
      if (!isDark) {
        final physShadowPaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.08 * bgRadio)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

        canvas.drawCircle(
          Offset(thumbCenterX, cy + 1.0),
          innerRadius,
          physShadowPaint,
        );
      }
    }

    // -------------------------------------------------------------------------
    // 3.2 按压“方圆”手感（仅改变圆角，不改变位移）
    // -------------------------------------------------------------------------
    const pressedRadiusOff = 6.0;
    const pressedRadiusOn = 8.0;
    final pressedTargetRadius =
        pressedRadiusOff + (pressedRadiusOn - pressedRadiusOff) * bgRadio;

    // 当按压时，圆角向方圆收缩
    final normalCorner = innerRadius;
    final pressedCorner = pressedTargetRadius - ringLineWidth / 2.0;
    final corner = isPressed ? pressedCorner : normalCorner;

    final thumbRect = Rect.fromCenter(
      center: Offset(thumbCenterX, cy),
      width: innerRadius * 2.0,
      height: innerRadius * 2.0,
    );

    // 滑块主体填充色
    final Color thumbFillColor = isDark
        ? const Color(0xFF000000)
        : (bgRadio > 0.5
            ? const Color(0xFFFFFFFF)
            : const Color(0xCCFFFFFF));

    final thumbFillPaint = Paint()
      ..color = thumbFillColor.withValues(alpha: enabled ? 1.0 : 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, Radius.circular(corner)),
      thumbFillPaint,
    );

    // 滑块外环彩色描边
    final currentRingColor =
        Color.lerp(ringOffColor, ringOnColor, bgRadio)!;
    final ringPaint = Paint()
      ..color = currentRingColor.withValues(alpha: enabled ? 1.0 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringLineWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, Radius.circular(corner)),
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OriginSwitchPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPressed != isPressed ||
        oldDelegate.enabled != enabled ||
        oldDelegate.isDark != isDark ||
        oldDelegate.ringOnColor != ringOnColor ||
        oldDelegate.ringOffColor != ringOffColor ||
        oldDelegate.trackOnColor != trackOnColor ||
        oldDelegate.trackOutlineColor != trackOutlineColor;
  }
}
