import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/widgets/origin_text_field.dart';
import 'package:beecount/custom_ui/widgets/origin_amount_field.dart';
import 'package:beecount/custom_ui/widgets/origin_search_bar.dart';

void main() {
  group('OriginTextField 测试', () {
    testWidgets('正常输入、占位提示与一键清空功能', (tester) async {
      final controller = TextEditingController(text: '初始文本');
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginTextField(
              controller: controller,
              hintText: '请输入内容',
              clearable: true,
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('初始文本'), findsOneWidget);
      // 应显示清空图标
      final clearIcon = find.byIcon(Icons.cancel);
      expect(clearIcon, findsOneWidget);

      // 点击清空
      await tester.tap(clearIcon);
      await tester.pump();

      expect(controller.text, isEmpty);
      expect(cleared, isTrue);
    });

    testWidgets('错误状态正确展示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OriginTextField(
              hintText: '用户名',
              errorText: '名称已存在',
            ),
          ),
        ),
      );

      expect(find.text('名称已存在'), findsOneWidget);
    });
  });

  group('OriginAmountField 测试', () {
    testWidgets('货币符号展示、仅允许数字和小数点两位', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginAmountField(
              controller: controller,
              currencySymbol: '¥',
              clearable: true,
            ),
          ),
        ),
      );

      expect(find.text('¥'), findsOneWidget);

      // 尝试输入合法金额
      await tester.enterText(find.byType(TextField), '123.45');
      await tester.pump();
      expect(controller.text, '123.45');

      // 尝试输入多于两位小数（应被限制）
      await tester.enterText(find.byType(TextField), '123.456');
      await tester.pump();
      expect(controller.text, '123.45');

      // 清空
      final clearBtn = find.byIcon(Icons.cancel);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump();
      expect(controller.text, isEmpty);
    });
  });

  group('OriginSearchBar 测试', () {
    testWidgets('搜索框尺寸规格、前缀放大镜与搜索提交', (tester) async {
      final controller = TextEditingController();
      String submittedQuery = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginSearchBar(
              controller: controller,
              hintText: '搜索账单明细',
              onSubmitted: (q) => submittedQuery = q,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('搜索账单明细'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '餐饮');
      await tester.pump();
      expect(controller.text, '餐饮');

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(submittedQuery, '餐饮');
    });
  });
}
