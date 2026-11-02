import 'package:beecount_ui/beecount_ui.dart' show showBeeToast;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/voice_billing_providers.dart';
import 'gemini_glow_arc.dart';
import 'gemini_voice_island.dart';
import 'gemini_voice_ribbons.dart';
import 'origin_voice_session.dart';

/// Gemini 风格语音记账唤醒层（挂载入口）
///
/// 只负责：进退场动画、手势分发、提示展示；
/// 录音 / 识别逻辑全部委托给 [OriginVoiceSession]。
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
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 280),
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
    // 成功：等 ✓ 画完、光弧亮闪；失败：等光弧褪灰
    await Future.delayed(Duration(milliseconds: end.success ? 650 : 700));
    await _exit(toast: end.message);
  }

  Future<void> _exit({String? toast}) async {
    if (_exiting || !mounted) return;
    _exiting = true;
    await _revealController.reverse();
    if (!mounted) return;
    // 提示挂在 Navigator 的 Overlay 上，路由关闭后仍会显示
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
        return s.recognizedText;
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

/// 纯展示层（无逻辑，便于测试）
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

  GeminiRibbonMode get _ribbonMode => switch (phase) {
        OriginVoicePhase.processing => GeminiRibbonMode.processing,
        OriginVoicePhase.success => GeminiRibbonMode.success,
        OriginVoicePhase.failure => GeminiRibbonMode.failure,
        _ => GeminiRibbonMode.listening,
      };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final bottomInset = media.padding.bottom;
    final reduceMotion = media.disableAnimations;
    final r = reveal.clamp(0.0, 1.0);

    // 微岛晚 15% 进场，从 0.9 倍放大淡入
    final islandT = ((r - 0.15) / 0.85).clamp(0.0, 1.0);
    final islandBottom = bottomInset + h * 0.14;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底部 → 顶部渐变压暗（最高 35%），点击空白处取消
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35 * r),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.75],
                ),
              ),
            ),
          ),

          // 2. 底部光弧（独立重绘层，不拖累页面）
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

          // 3. 识别文字 / 状态
          Positioned(
            left: 32,
            right: 32,
            bottom: islandBottom + GeminiVoiceIsland.height + 18,
            child: IgnorePointer(
              child: Opacity(
                opacity: islandT,
                child: _Caption(
                  text: caption,
                  typewriter: typewriter && !reduceMotion,
                ),
              ),
            ),
          ),

          // 4. 悬浮微岛
          Positioned(
            left: 0,
            right: 0,
            bottom: islandBottom,
            child: Center(
              child: Opacity(
                opacity: islandT,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * islandT,
                  child: GeminiVoiceIsland(
                    amplitude: amplitude,
                    mode: _ribbonMode,
                    showHoldHint:
                        isHoldToTalk && phase == OriginVoicePhase.waitingHold,
                    holdHintLabel: holdHintLabel,
                    pressed: isHolding,
                    reduceMotion: reduceMotion,
                    onTap: onIslandTap,
                    onHoldStart: onHoldStart,
                    onHoldEnd: onHoldEnd,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态文字：切换时淡入上移；识别结果逐字出现
class _Caption extends StatelessWidget {
  final String? text;
  final bool typewriter;

  const _Caption({required this.text, required this.typewriter});

  static const _style = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
  );

  @override
  Widget build(BuildContext context) {
    final t = text;
    Widget child;
    if (t == null || t.isEmpty) {
      child = const SizedBox(key: ValueKey('empty'), height: 21);
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _style,
          );
        },
      );
    } else {
      child = Text(
        t,
        key: ValueKey(t),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _style,
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
