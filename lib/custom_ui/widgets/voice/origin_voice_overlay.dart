import 'package:beecount_ui/beecount_ui.dart' show showBeeToast;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/voice_billing_providers.dart';
import 'gemini_glow_arc.dart';
import 'origin_voice_session.dart';

/// Gemini 风格纯净底部光弧语音记账唤醒层
///
/// 视觉特性：
/// 1. 彻底去除悬浮胶囊微岛与内部线条，消除容器突兀感；
/// 2. 底部保留 Gemini 经典四色流动柔和半圆光弧与星尘粒子；
/// 3. 光弧中心上方浮空纯净大字号识别文本，空气感极佳；
/// 4. 录音/识别/后处理全部委托给 [OriginVoiceSession]。
class OriginVoiceOverlay extends ConsumerStatefulWidget {
  final String audioPath;
  final AudioRecorder recorder;
  final VoiceTriggerMode triggerMode;
  final int silenceTimeoutMs;

  const OriginVoiceOverlay({
    super.key,
    required this.audioPath,
    required this.recorder,
    required this.triggerMode,
    required this.silenceTimeoutMs,
  });

  @override
  ConsumerState<OriginVoiceOverlay> createState() => _OriginVoiceOverlayState();
}

class _OriginVoiceOverlayState extends ConsumerState<OriginVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  late final CurvedAnimation _reveal;
  OriginVoiceSession? _session;
  OriginVoicePhase? _lastPhase;
  bool _wasHolding = false;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _reveal = CurvedAnimation(
      parent: _revealController,
      curve: const Cubic(0.2, 0.9, 0.3, 1.0),
      reverseCurve: Curves.easeInCubic,
    );
    _revealController.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_session != null) return;
    _session = OriginVoiceSession(
      ref: ref,
      l10n: AppLocalizations.of(context),
      recorder: widget.recorder,
      audioPath: widget.audioPath,
      triggerMode: widget.triggerMode,
      silenceTimeoutMs: widget.silenceTimeoutMs,
      onEnd: _onSessionEnd,
      onToast: (msg) {
        if (mounted) showBeeToast(context, msg);
      },
    )..addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session?.begin();
    });
  }

  void _onSessionChanged() {
    final s = _session!;
    if (s.phase != _lastPhase) {
      if (s.phase == OriginVoicePhase.success) HapticFeedback.mediumImpact();
      _lastPhase = s.phase;
    }
    if (s.isHolding && !_wasHolding) HapticFeedback.selectionClick();
    _wasHolding = s.isHolding;
    if (mounted) setState(() {});
  }

  Future<void> _onSessionEnd(OriginVoiceEnd end) async {
    // 成功后停留让用户看到识别结果，失败后停留展示提示
    await Future.delayed(Duration(milliseconds: end.success ? 800 : 700));
    await _exit(toast: end.message);
  }

  Future<void> _exit({String? toast}) async {
    if (_exiting || !mounted) return;
    _exiting = true;
    await _revealController.reverse();
    if (!mounted) return;
    if (toast != null) showBeeToast(context, toast);
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    final s = _session;
    if (s == null || !s.canCancel || _exiting) return;
    await s.cancel();
    await _exit();
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    _reveal.dispose();
    _revealController.dispose();
    super.dispose();
  }

  String? _caption(AppLocalizations l10n, OriginVoiceSession s) {
    switch (s.phase) {
      case OriginVoicePhase.waitingHold:
        return null;
      case OriginVoicePhase.starting:
        return s.isHoldToTalk ? null : l10n.voiceRecordingPreparing;
      case OriginVoicePhase.listening:
        if (s.isHoldToTalk) return l10n.voiceRecordingReleaseToFinish;
        return s.hasSpoken
            ? l10n.voiceRecordingAutoHintSpoken
            : l10n.voiceRecordingAutoHintWaiting;
      case OriginVoicePhase.processing:
        return s.recognizedText ?? l10n.voiceRecordingProcessing;
      case OriginVoicePhase.success:
        return l10n.voiceRecordingSuccess;
      case OriginVoicePhase.failure:
        return s.failureMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) => OriginVoiceOverlayView(
        reveal: _reveal.value,
        phase: s.phase,
        amplitude: s.amplitude,
        isHoldToTalk: s.isHoldToTalk,
        isHolding: s.isHolding,
        caption: _caption(l10n, s),
        typewriter: s.recognizedText != null &&
            _caption(l10n, s) == s.recognizedText,
        holdHintLabel: l10n.voiceRecordingHoldToTalk,
        onCancel: _cancel,
        onIslandTap: s.isHoldToTalk ? null : s.stopAndProcess,
        onHoldStart: s.isHoldToTalk ? s.holdStart : null,
        onHoldEnd: s.isHoldToTalk ? s.holdEnd : null,
      ),
    );
  }
}

/// 纯展示层（无逻辑，便于测试与预览）
class OriginVoiceOverlayView extends StatelessWidget {
  final double reveal;
  final OriginVoicePhase phase;
  final double amplitude;
  final bool isHoldToTalk;
  final bool isHolding;
  final String? caption;
  final bool typewriter;
  final String holdHintLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onIslandTap;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  const OriginVoiceOverlayView({
    super.key,
    required this.reveal,
    required this.phase,
    required this.amplitude,
    required this.isHoldToTalk,
    required this.isHolding,
    required this.caption,
    required this.holdHintLabel,
    this.typewriter = false,
    this.onCancel,
    this.onIslandTap,
    this.onHoldStart,
    this.onHoldEnd,
  });

  GeminiArcMode get _arcMode => switch (phase) {
        OriginVoicePhase.processing => GeminiArcMode.processing,
        OriginVoicePhase.success => GeminiArcMode.success,
        OriginVoicePhase.failure => GeminiArcMode.failure,
        _ => GeminiArcMode.listening,
      };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final bottomInset = media.padding.bottom;
    final reduceMotion = media.disableAnimations;
    final r = reveal.clamp(0.0, 1.0);

    // 文字位置位于底部光弧核心黄金区域
    final textBottom = bottomInset + h * 0.16;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底部 → 顶部柔和环境光渐变压暗，点击空白处取消
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32 * r),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),

          // 2. 底部流体半圆光弧（核心发光组件）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: h * 0.5,
            child: IgnorePointer(
              child: RepaintBoundary(
                child: GeminiGlowArc(
                  reveal: r,
                  amplitude: amplitude,
                  mode: _arcMode,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
          ),

          // 3. 浮空识别文本与状态排版（纯净无胶囊遮挡）
          // 3. 浮空识别文本与状态排版（纯净单排文本，无冗余第二排）
          Positioned(
            left: 32,
            right: 32,
            bottom: textBottom,
            child: Opacity(
              opacity: r,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: phase == OriginVoicePhase.listening && !isHoldToTalk
                    ? onIslandTap
                    : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Caption(
                      text: caption,
                      typewriter: typewriter && !reduceMotion,
                    ),
                    if (isHoldToTalk) ...[
                      const SizedBox(height: 16),
                      _HoldGestureButton(
                        isHolding: isHolding,
                        label: holdHintLabel,
                        onHoldStart: onHoldStart,
                        onHoldEnd: onHoldEnd,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 纯净浮空环境文本
class _Caption extends StatelessWidget {
  final String? text;
  final bool typewriter;

  const _Caption({
    required this.text,
    required this.typewriter,
  });

  @override
  Widget build(BuildContext context) {
    final t = text;
    const style = TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Color(0x88000000),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    );

    Widget child;
    if (t == null || t.isEmpty) {
      child = const SizedBox(key: ValueKey('empty'), height: 25);
    } else if (typewriter) {
      final ms = (t.characters.length * 28).clamp(200, 1200);
      child = TweenAnimationBuilder<double>(
        key: ValueKey('tw:$t'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: ms),
        builder: (context, v, _) {
          final n = (t.characters.length * v).round();
          return Text(
            t.characters.take(n).toString(),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        },
      );
    } else {
      child = Text(
        t,
        key: ValueKey(t),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.2), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 按住说话轻量透明手势触控条
class _HoldGestureButton extends StatelessWidget {
  final bool isHolding;
  final String label;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;

  const _HoldGestureButton({
    required this.isHolding,
    required this.label,
    this.onHoldStart,
    this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        HapticFeedback.lightImpact();
        onHoldStart?.call();
      },
      onPointerUp: (_) {
        HapticFeedback.mediumImpact();
        onHoldEnd?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isHolding
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isHolding ? 0.6 : 0.25),
            width: 1.0,
          ),
          boxShadow: isHolding
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 16,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_rounded,
              size: 16,
              color: isHolding ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              isHolding ? '松开 结束录音' : label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isHolding ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
