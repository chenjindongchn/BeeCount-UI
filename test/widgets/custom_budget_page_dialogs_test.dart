import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/custom_ui/pages/custom_budget_page.dart';
import 'package:beecount/custom_ui/widgets/origin_dialog.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
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
    SharedPreferences.setMockInitialValues({'home_budget_card_enabled': true});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency,month_start_day) VALUES(1,'日常生活','CNY',1)");
    await repo.createCategory(name: '餐饮', kind: 'expense', icon: 'food');
    await repo.createCategory(name: '交通', kind: 'expense', icon: 'bus');
  });

  tearDown(() async {
    await db.close();
  });

  group('CustomBudgetPage 预算对话框优化测试', () {
    testWidgets('1. 月度总预算右上角编辑按钮点击弹出对话框并修改金额', (tester) async {
      // 先创建一个总预算 3000
      await repo.createBudget(
        ledgerId: 1,
        type: 'total',
        amount: 3000,
        startDay: 1,
      );

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomBudgetPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证本月预算卡片展示
      expect(find.text('本月预算'), findsOneWidget);

      // 点击右上角的“编辑”
      final editBtn = find.text('编辑');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // 验证弹出对话框：TextField 预填了 3000
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      expect(find.text('3000'), findsOneWidget);

      // 修改金额为 5000
      await tester.enterText(inputFinder, '5000');
      await tester.pumpAndSettle();

      // 点击“保存”
      final saveBtn = find.text('保存');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 消化 Toast 2 秒定时器
      await tester.pump(const Duration(seconds: 3));

      // 验证对话框关闭且总预算更新为 5000
      expect(find.byType(TextField), findsNothing);
      final updatedBudget = await repo.getTotalBudget(1);
      expect(updatedBudget?.amount, 5000.0);
    });

    testWidgets('2. 分类预算右上角添加按钮点击弹出对话框并创建分类预算', (tester) async {
      // 创建总预算以展示分类预算卡片
      await repo.createBudget(
        ledgerId: 1,
        type: 'total',
        amount: 3000,
        startDay: 1,
      );

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomBudgetPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击分类预算右上角的“添加”按钮
      final addBtn = find.text('添加');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // 验证弹出“添加分类预算”对话框
      expect(find.text('添加分类预算'), findsOneWidget);

      // 输入金额 800
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '800');
      await tester.pumpAndSettle();

      // 点击保存
      final saveBtn = find.text('保存');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 消化 Toast 2 秒定时器
      await tester.pump(const Duration(seconds: 3));

      // 验证对话框关闭且分类预算已写入数据库
      expect(find.text('添加分类预算'), findsNothing);
      final catBudgets = await repo.getCategoryBudgets(1);
      expect(catBudgets.length, 1);
      expect(catBudgets.first.amount, 800.0);
    });

    testWidgets('3. 空预算状态下点击底部添加总预算弹出对话框', (tester) async {
      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomBudgetPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击底部“添加总预算”
      final addTotalBtn = find.text('添加总预算');
      expect(addTotalBtn, findsOneWidget);
      await tester.tap(addTotalBtn);
      await tester.pumpAndSettle();

      // 验证弹出对话框
      expect(find.byType(TextField), findsOneWidget);

      // 输入金额 6000 并保存
      await tester.enterText(find.byType(TextField), '6000');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 消化 Toast 2 秒定时器
      await tester.pump(const Duration(seconds: 3));

      // 验证保存成功
      final total = await repo.getTotalBudget(1);
      expect(total?.amount, 6000.0);
    });

    testWidgets('4. 编辑总预算弹窗展示标准3胶囊按钮（保存/删除总预算/取消），点击删除能正确删除', (tester) async {
      await repo.createBudget(
        ledgerId: 1,
        type: 'total',
        amount: 2500,
        startDay: 1,
      );

      final container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 1),
        syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomBudgetPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击右上角编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // 验证 3 胶囊按钮均存在
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('删除总预算'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      // 点击“删除总预算”胶囊按钮
      await tester.tap(find.text('删除总预算'));
      await tester.pumpAndSettle();

      // 弹出 OriginOS 风格二次确认弹窗
      expect(find.text('确定删除此预算？'), findsOneWidget);

      // 点击确认弹窗的“删除”按钮
      final deleteConfirmBtn =
          find.widgetWithText(OriginDialogCapsuleButton, '删除');
      expect(deleteConfirmBtn, findsOneWidget);
      await tester.tap(deleteConfirmBtn);
      await tester.pumpAndSettle();

      // 消化 Toast 2 秒定时器
      await tester.pump(const Duration(seconds: 3));

      // 验证数据库中总预算已清空
      final total = await repo.getTotalBudget(1);
      expect(total, isNull);
    });
  });
}
