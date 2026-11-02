import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/widgets/voice/gemini_glow_arc.dart';
import 'package:beecount/custom_ui/widgets/voice/gemini_voice_island.dart';
import 'package:beecount/custom_ui/widgets/voice/gemini_voice_ribbons.dart';
import 'package:beecount/custom_ui/widgets/voice/origin_voice_overlay.dart';
import 'package:beecount/custom_ui/widgets/voice/origin_voice_session.dart';

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

OriginVoiceOverlayView _view({
  required OriginVoicePhase phase,
  double amplitude = 0.0,
  bool isHoldToTalk = false,
  bool isHolding = false,
  String? caption,
  bool typewriter = false,
  VoidCallback? onCancel,
  VoidCallback? onIslandTap,
  VoidCallback? onHoldStart,
  VoidCallback? onHoldEnd,
}) {
  return OriginVoiceOverlayView(
    reveal: 1.0,
    phase: phase,
    amplitude: amplitude,
    isHoldToTalk: isHoldToTalk,
    isHolding: isHolding,
    caption: caption,
    typewriter: typewriter,
    holdHintLabel: '按住说话',
    onCancel: onCancel,
    onIslandTap: onIslandTap,
    onHoldStart: onHoldStart,
    onHoldEnd: onHoldEnd,
  );
}

void main() {
  group('Gemini 语音唤醒层', () {
    testWidgets('聆听 → 说话 → 识别中 → 成功 → 失败 各状态渲染无异常', (tester) async {
      final states = <(OriginVoicePhase, double, String?)>[
        (OriginVoicePhase.listening, 0.0, '我在听…'),
        (OriginVoicePhase.listening, 0.9, '继续说…'),
        (OriginVoicePhase.processing, 0.0, '午饭麦当劳 38 块'),
        (OriginVoicePhase.success, 0.0, '午饭麦当劳 38 块'),
        (OriginVoicePhase.failure, 0.0, '未识别到记账信息'),
      ];
      for (final (phase, amp, caption) in states) {
        await tester.pumpWidget(
            _host(_view(phase: phase, amplitude: amp, caption: caption)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull, reason: '$phase');
        expect(find.byType(GeminiGlowArc), findsOneWidget);
        expect(find.byType(GeminiVoiceRibbons), findsOneWidget);
        expect(find.text(caption!), findsOneWidget);
      }
    });

    testWidgets('按住说话：等待时显示提示文字，按下/松开回调触发', (tester) async {
      var started = 0, ended = 0;
      await tester.pumpWidget(_host(_view(
        phase: OriginVoicePhase.waitingHold,
        isHoldToTalk: true,
        onHoldStart: () => started++,
        onHoldEnd: () => ended++,
      )));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('按住说话'), findsOneWidget);
      expect(find.byType(GeminiVoiceRibbons), findsNothing);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(GeminiVoiceIsland)));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      expect(started, 1);
      expect(ended, 1);
    });

    testWidgets('自动模式：点微岛结束、点空白处取消', (tester) async {
      var finished = 0, cancelled = 0;
      await tester.pumpWidget(_host(_view(
        phase: OriginVoicePhase.listening,
        onIslandTap: () => finished++,
        onCancel: () => cancelled++,
      )));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(GeminiVoiceIsland));
      await tester.pump();
      expect(finished, 1);

      await tester.tapAt(const Offset(20, 80));
      await tester.pump();
      expect(cancelled, 1);
    });

    testWidgets('识别结果逐字出现', (tester) async {
      const text = '午饭麦当劳三十八块';
      await tester.pumpWidget(_host(_view(
        phase: OriginVoicePhase.processing,
        caption: text,
        typewriter: true,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(text), findsNothing);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text(text), findsOneWidget);
    });

    testWidgets('减弱动态效果：直接显示完整文字且无异常', (tester) async {
      const text = '午饭麦当劳三十八块';
      await tester.pumpWidget(_host(
        _view(
          phase: OriginVoicePhase.processing,
          caption: text,
          typewriter: true,
        ),
        disableAnimations: true,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
