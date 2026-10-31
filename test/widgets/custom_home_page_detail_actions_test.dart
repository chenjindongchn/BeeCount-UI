import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/custom_ui/pages/custom_home_page.dart';
import 'package:beecount/custom_ui/widgets/origin_dialog.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/custom_ui/widgets/origin_transaction_feed.dart';
import 'package:beecount/custom_ui/widgets/origin_transaction_item.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/search_page.dart';
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
    await db.customStatement(
        "INSERT INTO categories(id,name,kind) VALUES(1,'餐饮','expense')");
    await repo.addTransaction(
      ledgerId: 1,
      type: 'expense',
      amount: 22.54,
      categoryId: 1,
      happenedAt: DateTime(2024, 9, 22, 10, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CustomHomePage(),
      ),
    );
  }

  testWidgets('右上角设置菜单应包含“多选”并可点击跳转至批量模式', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
      selectedMonthProvider.overrideWith((ref) => DateTime(2024, 9)),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      currentMonthStartDayProvider.overrideWith((ref) => 1),
      budgetOverviewProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildTestApp(container));
    await tester.pumpAndSettle();

    // 点击右上角更多按钮
    final moreBtnFinder = find.byType(OriginMoreButton);
    expect(moreBtnFinder, findsOneWidget);
    await tester.tap(moreBtnFinder);
    await tester.pumpAndSettle();

    // 验证弹出菜单中有“多选”选项
    final multiSelectFinder = find.text('多选');
    expect(multiSelectFinder, findsOneWidget);

    // 点击“多选”
    await tester.tap(multiSelectFinder);
    await tester.pumpAndSettle();

    // 验证跳转到了 SearchPage 批量模式
    expect(find.byType(SearchPage), findsOneWidget);
  });

  testWidgets('长按账单条目应弹出确认删除对话框，点击确定后删除该账单', (tester) async {
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(repo),
      currentLedgerIdProvider.overrideWith((ref) => 1),
      currentLedgerProvider.overrideWith(
          (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
      selectedMonthProvider.overrideWith((ref) => DateTime(2024, 9)),
      syncServiceProvider.overrideWithValue(LocalOnlySyncService()),
      currentMonthStartDayProvider.overrideWith((ref) => 1),
      budgetOverviewProvider.overrideWith((ref) async => null),
    ]);
    addTearDown(container.dispose);

    final tx = (await (db.select(db.transactions)..where((t) => t.ledgerId.equals(1))).get()).first;
    final cat = (await (db.select(db.categories)..where((c) => c.id.equals(1))).get()).first;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => OriginTransactionItem(
                transaction: tx,
                category: cat,
                onLongPress: () async {
                  final confirmed = await showOriginConfirmDialog(
                    context,
                    title: '确定要删除该条账单吗？删除后不可恢复',
                    confirmText: '确定',
                    cancelText: '取消',
                    isDanger: true,
                  );
                  if (confirmed == true) {
                    await repo.deleteTransaction(tx.id);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 找到账单条目（餐饮）
    final itemFinder = find.text('餐饮');
    expect(itemFinder, findsOneWidget);

    // 长按条目
    await tester.longPress(itemFinder);
    await tester.pumpAndSettle();

    // 验证弹出确认删除对话框及其内容
    expect(find.byType(OriginDialog), findsOneWidget);
    expect(find.text('确定要删除该条账单吗？删除后不可恢复'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 点击“确定”
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 验证弹窗消失，数据库中的账单已被成功删除
    expect(find.byType(OriginDialog), findsNothing);
    final txs = await (db.select(db.transactions)..where((t) => t.ledgerId.equals(1))).get();
    expect(txs, isEmpty);
  });
}
