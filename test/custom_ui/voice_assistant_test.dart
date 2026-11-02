import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/widgets/voice/origin_voice_edge_glow.dart';
import 'package:beecount/custom_ui/widgets/voice/origin_voice_wave_visualizer.dart';

void main() {
  group('AI 语音助手特效组件测试', () {
    testWidgets('OriginVoiceEdgeGlow 渲染测试与振幅响应', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginVoiceEdgeGlow(
              amplitude: 0.75,
              primaryColor: Colors.blueAccent,
              isProcessing: false,
            ),
          ),
        ),
      );

      expect(find.byType(OriginVoiceEdgeGlow), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // 验证动画推进 500ms 依然正常刷新绘制
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('OriginVoiceWaveVisualizer 录音态与思考中双形态渲染', (tester) async {
      // 1. 录音态（声浪）
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginVoiceWaveVisualizer(
              amplitude: 0.5,
              primaryColor: Color(0xFF00E5FF),
              isProcessing: false,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(OriginVoiceWaveVisualizer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // 2. 思考中（旋转极光环态）
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginVoiceWaveVisualizer(
              amplitude: 0.0,
              primaryColor: Color(0xFF7C4DFF),
              isProcessing: true,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });
  });
}
