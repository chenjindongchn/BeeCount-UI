import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/custom_ui/pages/custom_category_detail_page.dart';
import 'package:beecount/custom_ui/providers/category_display_preferences_provider.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';

void main() {
  late db.BeeDatabase database;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    database = db.BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(database);
    await database.customStatement(
      "INSERT INTO ledgers(id, name, currency) VALUES(1, '日常账本', 'CNY')",
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('categoryDetailShowTrendProvider 默认关闭并支持切换', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(categoryDetailShowTrendProvider), isFalse);

    await container.read(categoryDetailShowTrendProvider.notifier).toggle();
    expect(container.read(categoryDetailShowTrendProvider), isTrue);

    await container.read(categoryDetailShowTrendProvider.notifier).toggle();
    expect(container.read(categoryDetailShowTrendProvider), isFalse);
  });

  testWidgets('CustomCategoryDetailPage 右上角展示双圆点菜单且包含累计金额趋势选项并能控制显隐', (tester) async {
    final categoryId = await repo.createCategory(
      name: '餐饮美食',
      kind: 'expense',
      icon: 'cutlery',
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        baseCurrencyProvider.overrideWith((ref) => 'CNY'),
        hideAmountsProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomCategoryDetailPage(
            categoryId: 1,
            categoryName: '餐饮美食',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. 验证右上角为 OriginMoreButton（两个点），而非旧版三点 IconButton
    final moreButtonFinder = find.descendant(
      of: find.byType(CustomCategoryDetailPage),
      matching: find.byType(OriginMoreButton),
    );
    expect(moreButtonFinder, findsOneWidget);

    // 默认关闭状态下，页面主体内不应展示“累计金额趋势”卡片
    expect(find.text('累计金额趋势'), findsNothing);

    // 2. 点击右上角两个点打开气泡菜单
    await tester.tap(moreButtonFinder);
    await tester.pumpAndSettle();

    // 3. 验证气泡菜单项：包含“累计金额趋势”及分类操作
    expect(find.text('累计金额趋势'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('分类迁移'), findsOneWidget);
    expect(find.text('分类管理'), findsOneWidget);

    // 4. 点击“累计金额趋势”菜单项，打勾开启
    await tester.tap(find.text('累计金额趋势'));
    await tester.pumpAndSettle();

    // 5. 验证页面内的“累计金额趋势”卡片已经显示出来
    expect(find.text('累计金额趋势'), findsOneWidget);
    expect(container.read(categoryDetailShowTrendProvider), isTrue);

    // 6. 再次点击右上角两个点
    await tester.tap(moreButtonFinder);
    await tester.pumpAndSettle();

    // 此时菜单项中有 check 勾选图标
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // 点击气泡菜单中的“累计金额趋势”取消勾选
    await tester.tap(find.text('累计金额趋势').last);
    await tester.pumpAndSettle();

    // 验证状态重置为 false，页面内趋势卡片隐藏
    expect(container.read(categoryDetailShowTrendProvider), isFalse);
    expect(find.text('累计金额趋势'), findsNothing);

    // 清理并完成异步定时器
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
