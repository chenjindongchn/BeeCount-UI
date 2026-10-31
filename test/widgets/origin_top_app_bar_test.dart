import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/widgets/origin_scaffold.dart';

void main() {
  group('OriginLargeTopAppBar 下拉与标题交互规范测试', () {
    testWidgets('当 showDropdown 为 true 时显示向下展开图标，点击触发 onTitleTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: OriginScaffold(
            appBar: OriginLargeTopAppBar(
              title: '默认账本',
              showDropdown: true,
              onTitleTap: () {
                tapped = true;
              },
            ),
            body: const SizedBox.shrink(),
          ),
        ),
      );

      // 验证标题文字存在
      expect(find.text('默认账本'), findsOneWidget);

      // 验证 OriginOS 规范的展开指示箭头存在
      final iconFinder = find.byIcon(Icons.keyboard_arrow_down_rounded);
      expect(iconFinder, findsOneWidget);

      // 点击标题区域
      await tester.tap(find.text('默认账本'));
      await tester.pumpAndSettle();

      // 验证回调已执行
      expect(tapped, isTrue);
    });

    testWidgets('当 showDropdown 为 false 且无 onTitleTap 时不展示展开箭头', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OriginScaffold(
            appBar: OriginLargeTopAppBar(
              title: '默认账本',
            ),
            body: SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('默认账本'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    });
  });
}
