import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/styles/origin_tokens.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/custom_ui/widgets/origin_scaffold.dart';

void main() {
  testWidgets('验证 OriginLargeTopAppBar 与 OriginSmallTopAppBar 的 actions 右边距均统一为 OriginTokens.cardMargin', (tester) async {
    final keyLarge = GlobalKey();
    final keySmall = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: OriginLargeTopAppBar(
                  title: '大标题',
                  actions: [
                    OriginMoreButton(
                      key: keyLarge,
                      items: [
                        OriginMenuItem(title: '菜单项', onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 100,
                child: OriginSmallTopAppBar(
                  title: '小标题',
                  actions: [
                    OriginMoreButton(
                      key: keySmall,
                      items: [
                        OriginMenuItem(title: '菜单项', onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final largeBox = tester.getRect(find.byKey(keyLarge));
    final smallBox = tester.getRect(find.byKey(keySmall));

    // 屏幕宽度默认为 800.0
    expect(largeBox.width, equals(40.0));
    expect(smallBox.width, equals(40.0));

    // 验证两个按钮的右边缘距离屏幕右边缘完全一致，且均等于 OriginTokens.cardMargin (20.0)
    final screenWidth = 800.0;
    final largeRightMargin = screenWidth - largeBox.right;
    final smallRightMargin = screenWidth - smallBox.right;

    expect(largeRightMargin, equals(OriginTokens.cardMargin));
    expect(smallRightMargin, equals(OriginTokens.cardMargin));
    expect(largeBox.right, equals(smallBox.right));
  });
}
