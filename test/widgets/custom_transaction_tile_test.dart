import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:beecount/custom_ui/pages/custom_category_detail_page.dart';
import 'package:beecount/custom_ui/widgets/custom_transaction_tile.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';

void main() {
  late db.BeeDatabase database;
  late LocalRepository repo;

  setUp(() async {
    database = db.BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(database);
    await database.customStatement(
      "INSERT INTO ledgers(id, name, currency) VALUES(1, '日常生活', 'CNY')",
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('CustomTransactionTileBinding 规范渲染分类名称、金额与流水条目结构', (tester) async {
    const category = db.Category(
      id: 1,
      name: '餐饮',
      kind: 'expense',
      sortOrder: 0,
      level: 1,
      iconType: 'builtin',
    );

    final transaction = db.Transaction(
      id: 1,
      ledgerId: 1,
      type: 'expense',
      amount: 45.0,
      currencyCode: 'CNY',
      happenedAt: DateTime.now(),
      categoryId: 1,
      excludeFromStats: false,
      excludeFromBudget: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
          baseCurrencyProvider.overrideWith((ref) => 'CNY'),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomTransactionTileBinding(
              row: (
                t: transaction,
                category: category,
                account: null,
                toAccount: null,
              ),
              tags: const [],
              attachmentCount: 0,
              onReturned: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('-45.00'), findsOneWidget);

    // 寻找流水条目上的 InkWell
    final inkWellFinder = find.descendant(
      of: find.byType(CustomTransactionTileBinding),
      matching: find.byType(InkWell),
    );

    expect(inkWellFinder, findsWidgets);

    // 清理并完成异步定时器
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('当 allowCategoryNavigation 为 false 时（如资产页面），点击分类图标不应跳转分类详情', (tester) async {
    const category = db.Category(
      id: 1,
      name: '餐饮',
      kind: 'expense',
      sortOrder: 0,
      level: 1,
      iconType: 'builtin',
    );

    final transaction = db.Transaction(
      id: 1,
      ledgerId: 1,
      type: 'expense',
      amount: 45.0,
      currencyCode: 'CNY',
      happenedAt: DateTime.now(),
      categoryId: 1,
      excludeFromStats: false,
      excludeFromBudget: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
          baseCurrencyProvider.overrideWith((ref) => 'CNY'),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomTransactionTileBinding(
              row: (
                t: transaction,
                category: category,
                account: null,
                toAccount: null,
              ),
              tags: const [],
              attachmentCount: 0,
              allowCategoryNavigation: false,
              onReturned: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final inkWellFinder = find.descendant(
      of: find.byType(CustomTransactionTileBinding),
      matching: find.byType(InkWell),
    );

    expect(inkWellFinder, findsWidgets);
    await tester.tap(inkWellFinder.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证绝不跳转 CustomCategoryDetailPage
    expect(find.byType(CustomCategoryDetailPage), findsNothing);

    // 清理并完成异步定时器
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
