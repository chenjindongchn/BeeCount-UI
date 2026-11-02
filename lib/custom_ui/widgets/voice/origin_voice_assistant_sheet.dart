import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../providers/voice_billing_providers.dart';
import '../../../services/billing/post_processor.dart';
import '../../../services/data/tag_seed_service.dart';
import '../../../services/system/logger_service.dart';
import '../../styles/origin_tokens.dart';
import 'origin_voice_edge_glow.dart';
import 'origin_voice_wave_visualizer.dart';

/// vivo 蓝心小V × iOS 18 Siri 风格全域唤醒语音助手面板 (OriginVoiceAssistantSheet)
class OriginVoiceAssistantSheet extends ConsumerStatefulWidget {
  final String audioPath;
  final AudioRecorder recorder;
  final VoiceTriggerMode triggerMode;
  final int silenceTimeoutMs;

  const OriginVoiceAssistantSheet({
    super.key,
    required this.audioPath,
    required this.recorder,
    required this.triggerMode,
    required this.silenceTimeoutMs,
  });

  @override
  ConsumerState<OriginVoiceAssistantSheet> createState() =>
      _OriginVoiceAssistantSheetState();
}

class _OriginVoiceAssistantSheetState
    extends ConsumerState<OriginVoiceAssistantSheet>
    with SingleTickerProviderStateMixin {
  // 阈值常量
  static const int _kStartSilenceTimeoutSec = 3;
  static const int _kMaxRecordingSec = 60;
  static const double _kSoundThreshold = 0.58;
  static const int _kConsecutiveSoundFrames = 5;
  static const int _kMinHoldMs = 500;

  late final AnimationController _sheetAnimController;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _status;
  String? _recognizedText;
  int _duration = 0;
  double _amplitude = 0.0;
  DateTime? _lastSoundTime;
  bool _hasSpoken = false;
  int _consecutiveSoundCount = 0;
  Timer? _silenceTimer;
  Timer? _amplitudeTimer;

  bool _isHolding = false;
  bool _isStarting = false;
  DateTime? _recordStartTime;

  bool get _isHoldToTalk => widget.triggerMode == VoiceTriggerMode.holdToTalk;

  @override
  void initState() {
    super.initState();

    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    // Origin 物理弹簧阻尼入场曲线
    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sheetAnimController,
        curve: const Cubic(0.25, 0.95, 0.32, 1.0),
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOut,
    );

    _sheetAnimController.forward();
    HapticFeedback.mediumImpact();

    // 自动检测模式：进入即开始录音；长按模式等待按住
    if (!_isHoldToTalk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    _sheetAnimController.dispose();
    widget.recorder.dispose();
    super.dispose();
  }

  Future<void> _closeSheet({bool immediate = false}) async {
    if (!mounted) return;
    if (immediate) {
      Navigator.of(context).pop();
      return;
    }
    await _sheetAnimController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    try {
      await widget.recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: widget.audioPath,
      );

      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _isRecording = true;
        _status = l10n.voiceRecordingInProgress;
        _lastSoundTime = now;
        _recordStartTime = now;
      });

      _startTimer();
      _startAmplitudeMonitoring();
      if (!_isHoldToTalk) {
        _startSilenceDetection();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isHolding = false;
        _status = l10n.voiceRecordingFailed(e.toString());
      });
      if (_isHoldToTalk) {
        _showToast(l10n.voiceRecordingFailed(e.toString()));
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!_isRecording || !mounted) return;
      setState(() => _duration++);
      if (_duration >= _kMaxRecordingSec) {
        if (_hasSpoken || _isHoldToTalk) {
          _stopAndProcess();
        } else {
          final l10n = AppLocalizations.of(context);
          _closeSheet();
          _showToast(l10n.voiceRecordingNoSpeech);
        }
        return;
      }
      _startTimer();
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 80), (timer) async {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      try {
        final amp = await widget.recorder.getAmplitude();
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }

        final current = amp.current;
        final normalizedAmplitude = ((current + 60) / 60).clamp(0.0, 1.0);

        if (normalizedAmplitude > _kSoundThreshold) {
          _consecutiveSoundCount++;
          setState(() {
            _amplitude = normalizedAmplitude;
          });

          if (_consecutiveSoundCount >= _kConsecutiveSoundFrames) {
            _lastSoundTime = DateTime.now();
            if (!_hasSpoken) {
              setState(() => _hasSpoken = true);
              logger.info('OriginVoiceAssistant', '检测到开始说话');
            }
          }
        } else {
          _consecutiveSoundCount = 0;
          setState(() {
            _amplitude = _amplitude * 0.75;
          });
        }
      } catch (_) {}
    });
  }

  void _startSilenceDetection() {
    final startTime = DateTime.now();

    _silenceTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isRecording) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      if (!_hasSpoken) {
        if (now.difference(startTime).inSeconds >= _kStartSilenceTimeoutSec) {
          timer.cancel();
          if (mounted) {
            final l10n = AppLocalizations.of(context);
            _closeSheet();
            _showToast(l10n.voiceRecordingNoSpeech);
          }
        }
      } else {
        final lastSound = _lastSoundTime;
        if (lastSound != null &&
            now.difference(lastSound).inMilliseconds >=
                widget.silenceTimeoutMs) {
          timer.cancel();
          _stopAndProcess();
        }
      }
    });
  }

  Future<void> _onHoldStart() async {
    if (_isRecording || _isProcessing || _isStarting) return;
    HapticFeedback.selectionClick();
    _isStarting = true;
    setState(() => _isHolding = true);
    try {
      await _startRecording();
    } finally {
      _isStarting = false;
    }

    if (!_isHolding && _isRecording) {
      await _discardRecording();
      if (mounted) {
        _showToast(AppLocalizations.of(context).voiceRecordingTooShort);
      }
    }
  }

  Future<void> _onHoldEnd() async {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    if (!_isRecording) return;

    final start = _recordStartTime;
    final tooShort = start != null &&
        DateTime.now().difference(start).inMilliseconds < _kMinHoldMs;
    if (tooShort) {
      await _discardRecording();
      if (mounted) {
        _showToast(AppLocalizations.of(context).voiceRecordingTooShort);
      }
      return;
    }

    HapticFeedback.lightImpact();
    await _stopAndProcess();
  }

  Future<void> _discardRecording() async {
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();
    setState(() {
      _isRecording = false;
      _hasSpoken = false;
      _duration = 0;
      _amplitude = 0.0;
    });
    try {
      await widget.recorder.stop();
    } catch (_) {}
    try {
      await File(widget.audioPath).delete();
    } catch (_) {}
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;
    _silenceTimer?.cancel();
    _amplitudeTimer?.cancel();

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _status = l10n.voiceRecordingProcessing;
    });

    try {
      await widget.recorder.stop();
      final audioFile = File(widget.audioPath);
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        throw Exception(l10n.voiceRecordingNoLedger);
      }

      final bookkeeper = ref.read(aiBookkeeperProvider);
      final response = await bookkeeper.fromAudio(
        audio: audioFile,
        ledgerId: currentLedger.id,
        billingTypes: [
          TagSeedService.billingTypeVoice,
          TagSeedService.billingTypeAi,
        ],
        l10n: l10n,
      );

      if (!mounted) return;

      if (response.recognizedText != null) {
        setState(() {
          _recognizedText = response.recognizedText;
        });
      }

      if (!response.result.success) {
        await _closeSheet();
        final msg = response.recognizedText != null
            ? l10n.voiceRecordingNoInfoDetected(response.recognizedText!)
            : l10n.voiceRecordingNoInfo;
        _showToast(msg);
        return;
      }

      await PostProcessor.run(ref, ledgerId: currentLedger.id, tags: true);
      if (!mounted) return;

      // 成功状态反馈展示
      HapticFeedback.heavyImpact();
      setState(() {
        _isSuccess = true;
      });

      final toast = response.result.isMulti
          ? '${l10n.voiceRecordingSuccess} × ${response.result.savedCount}'
          : l10n.voiceRecordingSuccess;
      final unconverted = response.result.unconvertedCurrencies;
      final finalToast = unconverted.isEmpty
          ? toast
          : '$toast\n${l10n.aiBillingRateMissingHint(unconverted.join('、'))}';

      // 优雅延时后淡出退出并 Toast
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      await _closeSheet();
      _showToast(finalToast);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = l10n.voiceRecordingRecognizeFailed(e.toString());
      });
    } finally {
      try {
        await File(widget.audioPath).delete();
      } catch (_) {}
    }
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // 晶透背景与微发光边框颜色
    final sheetBg = isDark
        ? const Color(0xE61C1D24)
        : const Color(0xF2FFFFFF);
    final borderGlowColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 全局轻量暗化蒙层 (点击空白区收起取消)
          GestureDetector(
            onTap: () {
              if (!_isProcessing) {
                _discardRecording();
                _closeSheet();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
            ),
          ),

          // 2. 屏幕全景边缘流光 (Edge Aura Glow)
          OriginVoiceEdgeGlow(
            amplitude: _amplitude,
            primaryColor: primaryColor,
            isProcessing: _isProcessing,
          ),

          // 3. 底部超椭圆悬浮仓 (Origin Floating Capsule)
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 18,
            child: AnimatedBuilder(
              animation: _sheetAnimController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Opacity(
                    opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 22,
                    ),
                    decoration: BoxDecoration(
                      color: sheetBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: borderGlowColor,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: isDark ? 0.22 : 0.14),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 顶部操作栏：状态指示 / 录音时长 / 取消叉号
                        _buildTopHeader(l10n, primaryColor),

                        const SizedBox(height: 12),

                        // 识别文本气泡展示区
                        if (_recognizedText != null)
                          _buildRecognizedTextBlock(primaryColor),

                        // 核心声浪律动与光核可视化
                        OriginVoiceWaveVisualizer(
                          amplitude: _amplitude,
                          primaryColor: primaryColor,
                          isProcessing: _isProcessing,
                          height: 96,
                        ),

                        const SizedBox(height: 14),

                        // 底部交互按钮区（支持按住说话与自动完成）
                        _buildBottomControls(l10n, primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部状态条与关闭按钮
  Widget _buildTopHeader(AppLocalizations l10n, Color primaryColor) {
    String titleText;
    if (_isSuccess) {
      titleText = '✓ 记账完成';
    } else if (_isProcessing) {
      titleText = _status ?? l10n.voiceRecordingProcessing;
    } else if (_isRecording) {
      titleText = _hasSpoken
          ? l10n.voiceRecordingAutoHintSpoken
          : l10n.voiceRecordingAutoHintWaiting;
    } else {
      titleText = l10n.voiceRecordingHoldToTalk;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 动态状态胶囊
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess
                      ? const Color(0xFF00E676)
                      : (_isProcessing ? const Color(0xFF00E5FF) : primaryColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isRecording
                    ? '${_duration.toString().padLeft(2, '0')}s'
                    : 'AI 语音助理',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),

        // 居中说明标题
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              titleText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
        ),

        // 右上角关闭小叉号
        GestureDetector(
          onTap: () {
            if (!_isProcessing) {
              _discardRecording();
              _closeSheet();
            }
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: OriginTokens.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  /// 识别出的语音文本流光气泡
  Widget _buildRecognizedTextBlock(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote_rounded, size: 16, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _recognizedText!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: OriginTokens.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部交互按钮区
  Widget _buildBottomControls(AppLocalizations l10n, Color primaryColor) {
    if (_isProcessing || _isSuccess) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            _isSuccess ? '正在同步账单...' : 'AI 正在理解消费信息...',
            style: TextStyle(
              fontSize: 13,
              color: OriginTokens.textSecondary(context),
            ),
          ),
        ),
      );
    }

    if (_isHoldToTalk) {
      // 按住说话交互大按钮
      return GestureDetector(
        onLongPressStart: (_) => _onHoldStart(),
        onLongPressEnd: (_) => _onHoldEnd(),
        onLongPressCancel: () => _onHoldEnd(),
        child: AnimatedScale(
          scale: _isHolding ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHolding
                    ? [primaryColor, const Color(0xFF7C4DFF)]
                    : [
                        primaryColor.withValues(alpha: 0.18),
                        primaryColor.withValues(alpha: 0.12),
                      ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _isHolding
                    ? Colors.white.withValues(alpha: 0.4)
                    : primaryColor.withValues(alpha: 0.3),
                width: 1.2,
              ),
              boxShadow: _isHolding
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_rounded,
                  size: 22,
                  color: _isHolding ? Colors.white : primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  _isHolding
                      ? l10n.voiceRecordingReleaseToFinish
                      : l10n.voiceRecordingHoldToTalk,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isHolding ? Colors.white : primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // 自动静音检测模式：提供手动「说完了」胶囊
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isRecording ? _stopAndProcess : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 20),
              const SizedBox(width: 6),
              Text(
                l10n.commonFinish,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
