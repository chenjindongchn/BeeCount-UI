import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';

void main() {
  testWidgets('OriginMoreButton 点击后展开的菜单应紧贴在按钮下方，不应产生远距离偏离', (tester) async {
    // 模拟具有 50dp 状态栏的屏幕环境
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2.0;
    tester.view.padding = const FakeViewPadding(top: 50.0, bottom: 34.0, left: 0, right: 0);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 50.0), // 模拟顶栏在状态栏下方
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: OriginMoreButton(
                  items: [
                    OriginMenuItem(
                      title: '选项 1',
                      onTap: () {},
                    ),
                    OriginMenuItem(
                      title: '选项 2',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 获取 OriginMoreButton 的全局坐标
    final buttonFinder = find.byType(OriginMoreButton);
    expect(buttonFinder, findsOneWidget);
    final buttonRect = tester.getRect(buttonFinder);

    // 点击按钮展开菜单
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // 检查菜单项已显示
    final itemFinder = find.text('选项 1');
    expect(itemFinder, findsOneWidget);

    // 查找弹出的菜单滚动容器（卡片内部）
    final menuScrollTopLeft = tester.getTopLeft(find.byType(SingleChildScrollView));
    final menuTextTopLeft = tester.getTopLeft(find.text('选项 1'));

    // 修复前：菜单 Y 坐标会累加两次状态栏高度（buttonRect.bottom + 50 + 4），
    // 导致卡片距离 buttonRect.bottom 超过 50dp，文字距离超过 70dp；
    // 修复后：
    // - 菜单卡片顶部刚好是 buttonRect.bottom + 4.0dp，加上 4.0dp 内边距后 SingleChildScrollView 为 8.0dp；
    // - 第一个选项文字距离按钮底部约为 21.5dp。
    final cardDistanceToButton = menuScrollTopLeft.dy - buttonRect.bottom;
    final textDistanceToButton = menuTextTopLeft.dy - buttonRect.bottom;
    
    // 验证菜单卡片紧贴按钮底部（4.0dp 边距 + 4.0dp 内边距 = 8.0dp）
    expect(
      cardDistanceToButton,
      closeTo(8.0, 0.5),
      reason: '菜单容器应紧贴在两个点按钮下方 4.0dp 处',
    );
    expect(
      textDistanceToButton,
      lessThan(25.0),
      reason: '选项文字应紧随菜单卡片自然呈现，不应相隔过远',
    );
  });
}
