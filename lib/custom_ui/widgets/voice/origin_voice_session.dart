import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../providers/ai_chat_providers.dart';
import '../../../providers/voice_billing_providers.dart';
import '../../../services/billing/post_processor.dart';
import '../../../services/data/tag_seed_service.dart';
import '../../../services/system/logger_service.dart';

/// 语音会话阶段
enum OriginVoicePhase {
  /// 按住说话模式：等待用户按下
  waitingHold,

  /// 录音启动中（recorder.start 在途）
  starting,

  /// 录音中
  listening,

  /// AI 识别中
  processing,

  /// 记账成功
  success,

  /// 失败 / 未听到 / 超时
  failure,
}

/// 会话结束结果（由 UI 负责退场动画 + 提示）
class OriginVoiceEnd {
  final bool success;
  final String message;
  const OriginVoiceEnd({required this.success, required this.message});
}

/// 语音记账会话控制器（纯逻辑，不含任何 UI）
///
/// 【上游同步说明】
/// 上游录音状态机写在私有类 `_VoiceRecordingDialogState`
/// （`lib/utils/voice_billing_helper.dart`）中，无 Provider 可复用，
/// 因此此处保留一份逐项对齐的副本：阈值常量、按住说话守卫、
/// 静音检测、最长录音保护、AI 调用与后处理顺序均与上游一致。
///
/// 对齐基线：上游 commit ce01d69dacb954c1e014a6065fd0378f10521ed8。
/// 每次 rebase 后执行：
///   git diff ce01d69d HEAD -- lib/utils/voice_billing_helper.dart
/// 若 `_VoiceRecordingDialogState` 有变化，同步到本文件即可，UI 无需改动。
class OriginVoiceSession extends ChangeNotifier {
  // ===== 与上游一致的阈值常量 =====
  static const int kStartSilenceTimeoutSec = 3;
  static const int kMaxRecordingSec = 60;
  static const double kSoundThreshold = 0.58;
  static const int kConsecutiveSoundFrames = 5;
  static const int kMinHoldMs = 500;

  final WidgetRef ref;
  final AppLocalizations l10n;
  final AudioRecorder recorder;
  final String audioPath;
  final VoiceTriggerMode triggerMode;
  final int silenceTimeoutMs;

  /// 会话结束回调（成功 / 失败），UI 负责退场与提示
  final ValueChanged<OriginVoiceEnd> onEnd;

  /// 不结束会话的瞬时提示（如“录音过短”）
  final ValueChanged<String> onToast;

  OriginVoiceSession({
    required this.ref,
    required this.l10n,
    required this.recorder,
    required this.audioPath,
    required this.triggerMode,
    required this.silenceTimeoutMs,
    required this.onEnd,
    required this.onToast,
  }) : _phase = triggerMode == VoiceTriggerMode.holdToTalk
            ? OriginVoicePhase.waitingHold
            : OriginVoicePhase.starting;

  OriginVoicePhase _phase;
  double _amplitude = 0.0;
  bool _hasSpoken = false;
  bool _isHolding = false;
  bool _isStarting = false;
  int _duration = 0;
  String? _recognizedText;
  String? _failureMessage;

  DateTime? _lastSoundTime;
  DateTime? _recordStartTime;
  int _consecutiveSoundCount = 0;
  Timer? _durationTimer;
  Timer? _amplitudeTimer;
  Timer? _silenceTimer;
  bool _disposed = false;
  bool _ended = false;

  OriginVoicePhase get phase => _phase;
  double get amplitude => _amplitude;
  bool get hasSpoken => _hasSpoken;
  bool get isHolding => _isHolding;
  int get duration => _duration;
  String? get recognizedText => _recognizedText;
  String? get failureMessage => _failureMessage;
  bool get isHoldToTalk => triggerMode == VoiceTriggerMode.holdToTalk;
  bool get isRecording => _phase == OriginVoicePhase.listening;

  /// 是否允许用户取消（识别中 / 已结束不允许，与上游一致）
  bool get canCancel =>
      _phase != OriginVoicePhase.processing &&
      _phase != OriginVoicePhase.success &&
      _phase != OriginVoicePhase.failure;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// 会话入口：自动检测模式立即录音；按住说话模式等待按下
  void begin() {
    if (!isHoldToTalk) _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: audioPath,
      );
      if (_disposed) return;
      final now = DateTime.now();
      _phase = OriginVoicePhase.listening;
      _lastSoundTime = now;
      _recordStartTime = now;
      _notify();

      _startDurationTimer();
      _startAmplitudeMonitoring();
      // 仅自动检测模式跑静音检测；按住说话靠松手结束
      if (!isHoldToTalk) _startSilenceDetection();
    } catch (e) {
      if (_disposed) return;
      _isHolding = false;
      _fail(l10n.voiceRecordingFailed(e.toString()));
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || !isRecording) {
        timer.cancel();
        return;
      }
      _duration++;
      _notify();
      // 最长录音保护（两模式共用）
      if (_duration >= kMaxRecordingSec) {
        timer.cancel();
        if (_hasSpoken || isHoldToTalk) {
          stopAndProcess();
        } else {
          _stopTimers();
          _safeStop();
          _fail(l10n.voiceRecordingNoSpeech);
        }
      }
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (_disposed || !isRecording) {
        timer.cancel();
        return;
      }
      try {
        final amp = await recorder.getAmplitude();
        if (_disposed || !isRecording) {
          timer.cancel();
          return;
        }
        final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
        // 视觉振幅：针对人声自然声压（-48dB ~ -10dB）进行高灵敏动态拉伸
        final visualAmp = ((amp.current + 48) / 38).clamp(0.0, 1.0);
        _amplitude = visualAmp;

        if (normalized > kSoundThreshold) {
          _consecutiveSoundCount++;
          if (_consecutiveSoundCount >= kConsecutiveSoundFrames) {
            _lastSoundTime = DateTime.now();
            if (!_hasSpoken) {
              _hasSpoken = true;
              logger.info('VoiceRecording', '检测到用户开始说话');
            }
          }
        } else {
          _consecutiveSoundCount = 0;
        }
        _notify();
      } catch (_) {
        // 与上游一致：忽略振幅读取错误
      }
    });
  }

  void _startSilenceDetection() {
    final startTime = DateTime.now();
    _silenceTimer?.cancel();
    _silenceTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_disposed || !isRecording) {
        timer.cancel();
        return;
      }
      final now = DateTime.now();
      if (!_hasSpoken) {
        if (now.difference(startTime).inSeconds >= kStartSilenceTimeoutSec) {
          timer.cancel();
          _stopTimers();
          _safeStop();
          _fail(l10n.voiceRecordingNoSpeech);
        }
      } else {
        final lastSound = _lastSoundTime;
        if (lastSound != null &&
            now.difference(lastSound).inMilliseconds >= silenceTimeoutMs) {
          timer.cancel();
          stopAndProcess();
        }
      }
    });
  }

  /// 按住说话：按下开始录音
  Future<void> holdStart() async {
    if (!isHoldToTalk) return;
    // 守卫覆盖「启动中」窗口，避免并发 start()
    if (isRecording || _phase == OriginVoicePhase.processing || _isStarting) {
      return;
    }
    if (_phase != OriginVoicePhase.waitingHold) return;
    _isStarting = true;
    _isHolding = true;
    _phase = OriginVoicePhase.starting;
    _notify();
    try {
      await _startRecording();
    } finally {
      _isStarting = false;
    }
    // 竞态：启动期间用户已松手，丢弃 orphan 录音
    if (!_isHolding && isRecording) {
      await _discardRecording();
      onToast(l10n.voiceRecordingTooShort);
    }
  }

  /// 按住说话：松手结束
  Future<void> holdEnd() async {
    if (!_isHolding) return;
    _isHolding = false;
    _notify();
    if (!isRecording) return;

    final start = _recordStartTime;
    final tooShort = start != null &&
        DateTime.now().difference(start).inMilliseconds < kMinHoldMs;
    if (tooShort) {
      await _discardRecording();
      onToast(l10n.voiceRecordingTooShort);
      return;
    }
    await stopAndProcess();
  }

  /// 丢弃当前录音，回到等待按下状态（按住说话误触场景）
  Future<void> _discardRecording() async {
    _stopTimers();
    _hasSpoken = false;
    _duration = 0;
    _amplitude = 0;
    if (!_disposed && !_ended) {
      _phase = OriginVoicePhase.waitingHold;
      _notify();
    }
    await _safeStop();
    await _deleteAudio();
  }

  /// 结束录音并送 AI 识别（自动模式点击微岛 / 静音到时 / 松手）
  Future<void> stopAndProcess() async {
    if (!isRecording) return;
    _stopTimers();
    _phase = OriginVoicePhase.processing;
    _amplitude = 0;
    _notify();

    try {
      await recorder.stop();
      if (_disposed) return;
      final audioFile = File(audioPath);
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        throw Exception(l10n.voiceRecordingNoLedger);
      }

      logger.info('VoiceRecording', '调用 AiBookkeeper.fromAudio');
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
      if (_disposed) return;

      if (response.recognizedText != null) {
        _recognizedText = response.recognizedText;
        logger.info('VoiceRecording', '识别文字: ${response.recognizedText}');
        _notify();
      }

      if (!response.result.success) {
        _fail(response.recognizedText != null
            ? l10n.voiceRecordingNoInfoDetected(response.recognizedText!)
            : l10n.voiceRecordingNoInfo);
        return;
      }

      await PostProcessor.run(ref, ledgerId: currentLedger.id, tags: true);
      if (_disposed) return;

      final toast = response.result.isMulti
          ? '${l10n.voiceRecordingSuccess} × ${response.result.savedCount}'
          : l10n.voiceRecordingSuccess;
      // 多币种降级提示：缺汇率已按 1:1 暂记
      final unconverted = response.result.unconvertedCurrencies;
      final message = unconverted.isEmpty
          ? toast
          : '$toast\n${l10n.aiBillingRateMissingHint(unconverted.join('、'))}';

      _phase = OriginVoicePhase.success;
      _notify();
      _end(OriginVoiceEnd(success: true, message: message));
    } catch (e) {
      if (_disposed) return;
      _fail(l10n.voiceRecordingRecognizeFailed(e.toString()));
    } finally {
      await _deleteAudio();
    }
  }

  /// 用户取消（点击空白处）
  Future<void> cancel() async {
    if (!canCancel) return;
    _ended = true;
    _stopTimers();
    await _safeStop();
    await _deleteAudio();
  }

  void _fail(String message) {
    _failureMessage = message;
    _phase = OriginVoicePhase.failure;
    _notify();
    _end(OriginVoiceEnd(success: false, message: message));
  }

  void _end(OriginVoiceEnd end) {
    if (_ended) return;
    _ended = true;
    onEnd(end);
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _amplitudeTimer?.cancel();
    _silenceTimer?.cancel();
  }

  Future<void> _safeStop() async {
    try {
      await recorder.stop();
    } catch (_) {}
  }

  Future<void> _deleteAudio() async {
    try {
      await File(audioPath).delete();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimers();
    // 与上游一致：会话销毁时释放录音器
    recorder.dispose();
    super.dispose();
  }
}
