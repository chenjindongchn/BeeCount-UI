import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/custom_ui/pages/custom_account_detail_page.dart';
import 'package:beecount/custom_ui/widgets/origin_menu.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/providers.dart';
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
    await database.customStatement(
      "INSERT INTO ledgers(id, name, currency) VALUES(2, '旅行账本', 'CNY')",
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('CustomAccountDetailPage 右上角应展示 OriginMoreButton 并在点击后展开气泡菜单', (tester) async {
    final accountId = await repo.createAccount(
      ledgerId: 1,
      name: '招商银行',
      type: 'bank',
      currency: 'CNY',
      initialBalance: 2000.0,
    );
    final account = (await repo.getAccount(accountId))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
          baseCurrencyProvider.overrideWith((ref) => 'CNY'),
          hideAmountsProvider.overrideWith((ref) => false),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomAccountDetailPage(account: account),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. 验证右上角为 OriginMoreButton，而非旧版底部弹窗的 IconButton
    final moreButtonFinder = find.descendant(
      of: find.byType(CustomAccountDetailPage),
      matching: find.byType(OriginMoreButton),
    );
    expect(moreButtonFinder, findsOneWidget);

    // 2. 点击 OriginMoreButton
    await tester.tap(moreButtonFinder);
    await tester.pumpAndSettle();

    // 3. 验证弹出的气泡菜单项存在（编辑账户、搜索、关联账本、隐藏账户、删除等）
    expect(find.text('编辑账户'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('关联账本'), findsOneWidget);
    expect(find.text('隐藏账户'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    // 等待 LoggerService 2s 定时器完成
    await tester.pump(const Duration(seconds: 3));
  });
}
