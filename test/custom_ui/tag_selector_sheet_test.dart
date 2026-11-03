import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/tag_providers.dart';
import 'package:beecount/custom_ui/widgets/custom_tag_selector_sheet.dart';

void main() {
  testWidgets('CustomTagSelectorSheet 样式与功能验收测试：符合OriginUI规范，无搜索框、无清空按钮、无“可多选”，按钮一行一个纵向排列',
      (tester) async {
    final List<Tag> mockTags = [
      Tag(
        id: 1,
        name: '餐饮',
        color: '#FF5722',
        sortOrder: 0,
        createdAt: DateTime.now(),
      ),
      Tag(
        id: 2,
        name: '交通',
        color: '#2196F3',
        sortOrder: 1,
        createdAt: DateTime.now(),
      ),
    ];

    List<int>? confirmedTags;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tagsForCurrentLedgerProvider.overrideWith(
            (ref) => Future.value(mockTags),
          ),
          recentTagsForCurrentLedgerProvider.overrideWith(
            (ref) => Future.value(<Tag>[]),
          ),
          canCreateTagForCurrentLedgerProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  confirmedTags = await CustomTagSelectorSheet.show(
                    context,
                    selectedTagIds: [1],
                  );
                },
                child: const Text('打开标签选择器'),
              ),
            ),
          ),
        ),
      ),
    );

    // 1. 点击打开标签选择抽屉
    await tester.tap(find.text('打开标签选择器'));
    await tester.pumpAndSettle();

    // 2. 验证弹窗成功打开，且完全没有搜索框 (TextField)
    expect(find.byType(CustomTagSelectorSheet), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // 3. 验证标题符合 OriginUI 规范：居中纯净标题，彻底删除“可多选”
    expect(find.text('选择标签'), findsOneWidget);
    expect(find.text('可多选'), findsNothing);

    // 4. 验证彻底删除清空按钮
    expect(find.text('清空'), findsNothing);

    // 5. 验证底部操作按钮：一行一个，纵向排列（新建在上、确定在下，无加号图标）
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    final createPos = tester.getCenter(find.text('新建'));
    final confirmPos = tester.getCenter(find.text('确定'));

    // 新建在确定的上方
    expect(createPos.dy < confirmPos.dy, isTrue);

    // 确定与新建均为通栏大胶囊按钮（一行一个，且左右边距和宽度一致）
    final confirmBtn = find.ancestor(of: find.text('确定'), matching: find.byType(AnimatedScale)).first;
    final createBtn = find.ancestor(of: find.text('新建'), matching: find.byType(AnimatedScale)).first;
    final confirmRect = tester.getRect(confirmBtn);
    final createRect = tester.getRect(createBtn);
    expect(confirmRect.width, equals(createRect.width));
    expect(confirmRect.left, equals(createRect.left));

    // 6. 点击“交通”多选，此时同时选中 1 和 2
    await tester.tap(find.text('交通'));
    await tester.pumpAndSettle();

    // 7. 点击“确定”并验证返回结果
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 8. 验证弹窗已退出并成功返回选中 ID 列表 [1, 2]
    expect(find.byType(CustomTagSelectorSheet), findsNothing);
    expect(confirmedTags, equals([1, 2]));
  });
}
