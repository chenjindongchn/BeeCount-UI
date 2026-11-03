import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:beecount/custom_ui/pages/custom_mine_page.dart';
import 'package:beecount/custom_ui/pages/custom_category_manage_page.dart';
import 'package:beecount/custom_ui/pages/custom_tag_manage_page.dart';
import 'package:beecount/custom_ui/pages/custom_ledgers_page.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/custom_ui/widgets/origin_scaffold.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/github_star_provider.dart';
import 'package:beecount/l10n/app_localizations.dart';

void main() {
  late db.BeeDatabase database;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    database = db.BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(database);
    await database.customStatement(
      "INSERT INTO ledgers(id, name, currency) VALUES(1, '日常生活', 'CNY')",
    );
  });

  tearDown(() async {
    await database.close();
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        baseCurrencyProvider.overrideWith((ref) => 'CNY'),
        hideAmountsProvider.overrideWith((ref) => false),
        githubStarCountProvider.overrideWith((ref) => 100),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  testWidgets('CustomMinePage 采用 OriginOS 大标题栏并展示核心设置卡片', (tester) async {
    await tester.pumpWidget(wrap(const CustomMinePage()));
    await tester.pumpAndSettle();

    expect(find.byType(OriginLargeTopAppBar), findsOneWidget);
    expect(find.text('分类管理'), findsWidgets);
    expect(find.text('标签管理'), findsWidgets);
    expect(find.text('账户偏好设置'), findsWidgets);
    expect(find.text('智能记账'), findsWidgets);
    expect(find.text('数据管理'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('CustomCategoryManagePage 右上角应展示 OriginMoreButton 并展开气泡菜单', (tester) async {
    await tester.pumpWidget(wrap(const CustomCategoryManagePage()));
    await tester.pumpAndSettle();

    final moreFinder = find.byType(OriginMoreButton);
    expect(moreFinder, findsOneWidget);

    await tester.tap(moreFinder);
    await tester.pumpAndSettle();

    expect(find.text('新建分类'), findsWidgets);
    expect(find.text('分享分类'), findsOneWidget);
    expect(find.text('导入分类'), findsOneWidget);
    expect(find.text('生成默认分类'), findsOneWidget);
    expect(find.text('清空未使用分类'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('CustomTagManagePage 右上角应展示 OriginMoreButton 并展开气泡菜单', (tester) async {
    await tester.pumpWidget(wrap(const CustomTagManagePage()));
    await tester.pumpAndSettle();

    final moreFinder = find.byType(OriginMoreButton);
    expect(moreFinder, findsOneWidget);

    await tester.tap(moreFinder);
    await tester.pumpAndSettle();

    expect(find.text('新增标签'), findsWidgets);
    expect(find.text('分享标签'), findsOneWidget);
    expect(find.text('生成默认标签'), findsWidgets);
    expect(find.text('导入标签'), findsOneWidget);
    expect(find.text('清理未使用'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('CustomLedgersPage 右上角应展示刷新按钮', (tester) async {
    await tester.pumpWidget(wrap(const CustomLedgersPage()));
    await tester.pumpAndSettle();

    final refreshFinder = find.byTooltip('刷新账本');
    expect(refreshFinder, findsOneWidget);

    await tester.tap(refreshFinder);
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 3));
  });
}
