import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/custom_ui/pages/custom_budget_page.dart';
import 'package:beecount/custom_ui/pages/custom_home_page.dart';
import 'package:beecount/custom_ui/widgets/origin_card.dart';
import 'package:beecount/custom_ui/widgets/origin_scaffold.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/budget_repository.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/budget_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'日常生活','CNY')");
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomHomePage & CustomBudgetPage 规范与交互测试', () {
    testWidgets('1. 顶部卡片包含今日支出文本、间距与眼睛开关，去设置跳转至 CustomBudgetPage',
        (tester) async {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        currentLedgerProvider.overrideWith(
            (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        budgetOverviewProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomHomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证卡片顶部展示了“今日支出”文本
      expect(find.text('今日支出'), findsOneWidget);

      // 验证主页提示卡片中出现了“设置预算，轻松掌控每月开支”
      expect(find.text('设置预算，轻松掌控每月开支'), findsOneWidget);

      // 点击“去设置”按钮
      final l10n =
          AppLocalizations.of(tester.element(find.byType(CustomHomePage)));
      final setupActionFinder = find.text(l10n.budgetSetupAction);
      expect(setupActionFinder, findsOneWidget);

      await tester.tap(setupActionFinder);
      await tester.pumpAndSettle();

      // 验证跳转到了符合 OriginUI 规范的 CustomBudgetPage
      expect(find.byType(CustomBudgetPage), findsOneWidget);

      // 验证没有预算时，添加总预算的按钮在页面的最底下（bottomNavigationBar 中渲染）
      final customBudgetPage = tester.widget<CustomBudgetPage>(
        find.byType(CustomBudgetPage),
      );
      expect(find.text(l10n.budgetAddTotal), findsOneWidget);
      expect(find.text(l10n.budgetEmptyHint), findsOneWidget);
    });

    testWidgets('2. 右上角更多菜单中包含「预算管理」入口并可点击进入', (tester) async {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        currentLedgerProvider.overrideWith(
            (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        budgetOverviewProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomHomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击右上角更多按钮（竖排双圆点）
      final moreButtonFinder = find.byType(OriginMoreButton);
      expect(moreButtonFinder, findsOneWidget);
      await tester.tap(moreButtonFinder);
      await tester.pumpAndSettle();

      // 验证弹出菜单项包含“预算管理”
      expect(find.text('预算管理'), findsOneWidget);

      // 点击“预算管理”
      await tester.tap(find.text('预算管理'));
      await tester.pumpAndSettle();

      // 验证成功进入 CustomBudgetPage
      expect(find.byType(CustomBudgetPage), findsOneWidget);
    });

    testWidgets('3. 当存在预算时，首页顶部卡片展示预算延长区域及剩余金额与进度条', (tester) async {
      final mockUsage = BudgetUsage(used: 1200.0, budget: 5000.0);
      final mockOverview = BudgetOverview(
        totalBudget: mockUsage,
        categoryBudgets: const [],
        daysRemaining: 15,
        dailyAvailable: 253.33,
      );

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        currentLedgerProvider.overrideWith(
            (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
        selectedMonthProvider.overrideWith((ref) => DateTime(2026, 10)),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
        currentMonthStartDayProvider.overrideWith((ref) => 1),
        budgetOverviewProvider.overrideWith((ref) async => mockOverview),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomHomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证卡片中包含预算延长区域（且无金钱符号，无多余跳转图标，默认纯数字无千分位）
      expect(find.textContaining('月预算剩余 3800.00'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
      expect(find.textContaining('已用 24%'), findsOneWidget);

      // 点击预算延长区域跳转到 CustomBudgetPage
      await tester.tap(find.textContaining('月预算剩余'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomBudgetPage), findsOneWidget);
      // 有预算时显示本月预算概览
      expect(find.text('本月预算'), findsOneWidget);
      expect(find.textContaining('5000.00'), findsOneWidget);

      // 验证方案 A 规范：顶部 AppBar 无冗余加号图标按钮
      expect(
        find.descendant(
          of: find.byType(OriginSmallTopAppBar),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsNothing,
      );

      // 验证分类预算卡片标题栏包含唯一的「+ 添加」操作
      expect(find.text('分类预算'), findsOneWidget);
      expect(find.text('添加'), findsOneWidget);

      // 验证卡片内部展示轻量空状态引导，不存在外层多余的独立添加大卡片
      expect(find.text('点击右上角「+ 添加」，按分类精细化管理开支'), findsOneWidget);
    });
  });
}
