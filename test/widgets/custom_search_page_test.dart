import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/custom_ui/pages/custom_search_page.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/custom_ui/widgets/origin_search_bar.dart';
import 'package:beecount/custom_ui/widgets/origin_search_filter_sheet.dart';
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

  Widget buildTestApp(Widget child, ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: child,
      ),
    );
  }

  testWidgets('CustomSearchPage 遵循 OriginUI 渲染 OriginSearchBar 与右上角双圆点入口',
      (tester) async {
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
      buildTestApp(const CustomSearchPage(), container),
    );
    await tester.pumpAndSettle();

    // 验证 OriginSearchBar 存在
    expect(find.byType(OriginSearchBar), findsOneWidget);
    // 验证返回箭头图标存在
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    // 验证右上角为 OriginMoreIcon（两个点）
    expect(find.byType(OriginMoreIcon), findsOneWidget);

    // 点击右上角双圆点图标
    await tester.tap(find.byType(OriginMoreIcon));
    await tester.pumpAndSettle();

    // 验证 OriginSearchFilterSheet 抽屉滑出，并包含分类筛选与交易类型
    expect(find.byType(OriginSearchFilterSheet), findsOneWidget);
    expect(find.text('分类筛选'), findsOneWidget);
    expect(find.text('交易类型'), findsOneWidget);
  });

  testWidgets('CustomSearchPage 批量模式展示标题栏与全选操作，且无退出批量操作按钮', (tester) async {
    // 插入两条测试交易数据
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 20.0,
      happenedAt: DateTime(2026, 10, 24),
      note: '午餐',
    );
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 15.0,
      happenedAt: DateTime(2026, 10, 24),
      note: '咖啡',
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
      buildTestApp(const CustomSearchPage(initialBatchMode: true), container),
    );
    await tester.pumpAndSettle();

    // 批量模式下不应显示普通的胶囊搜索栏
    expect(find.byType(OriginSearchBar), findsNothing);
    // 验证初始批量模式标题为“批量操作”
    expect(find.text('批量操作'), findsOneWidget);
    // 验证已彻底删除“退出批量操作”文本按钮
    expect(find.text('退出批量操作'), findsNothing);
    // 验证右上角呈现 OriginOS 标准“全选”按钮
    expect(find.text('全选'), findsAtLeastNWidgets(1));

    // 点击右上角“全选”
    await tester.tap(find.text('全选').first);
    await tester.pumpAndSettle();

    // 验证标题动态更新为“已选择 2 笔”
    expect(find.text('已选择 2 笔'), findsOneWidget);
    // 验证右上角切换为“取消全选”
    expect(find.text('取消全选'), findsAtLeastNWidgets(1));
  });
}
