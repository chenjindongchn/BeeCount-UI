import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/custom_ui/providers/last_account_preference_provider.dart';
import 'package:beecount/data/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RememberLastAccountEnabledNotifier', () {
    test('默认情况下开关处于关闭状态 (false)', () async {
      final notifier = RememberLastAccountEnabledNotifier();
      expect(notifier.state, false);
    });

    test('切换开关并持久化保存', () async {
      final notifier = RememberLastAccountEnabledNotifier();
      await notifier.setEnabled(true);
      expect(notifier.state, true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('custom_remember_last_category_account_enabled'),
        true,
      );
    });
  });

  group('CategoryAccountMemoryService', () {
    late CategoryAccountMemoryService service;

    setUp(() {
      service = CategoryAccountMemoryService();
    });

    final List<Account> dummyAccounts = [
      Account(
        id: 101,
        ledgerId: 1,
        name: '微信',
        type: 'wechat',
        currency: 'CNY',
        initialBalance: 100,
        hidden: false,
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: 102,
        ledgerId: 1,
        name: '支付宝',
        type: 'alipay',
        currency: 'CNY',
        initialBalance: 200,
        hidden: false,
        sortOrder: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      Account(
        id: 103,
        ledgerId: 1,
        name: '已隐藏账户',
        type: 'cash',
        currency: 'CNY',
        initialBalance: 0,
        hidden: true, // 隐藏账户
        sortOrder: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    test('未操作过的分类返回 null (不显示)', () async {
      final accountId = await service.getLastAccountId(
        ledgerId: 1,
        categoryId: 999,
        availableAccounts: dummyAccounts,
      );
      expect(accountId, isNull);
    });

    test('记录并读取分类对应的账户', () async {
      // 记录餐饮(1)使用微信(101)
      await service.saveLastAccountId(
        ledgerId: 1,
        categoryId: 1,
        accountId: 101,
      );

      final accountId = await service.getLastAccountId(
        ledgerId: 1,
        categoryId: 1,
        availableAccounts: dummyAccounts,
      );
      expect(accountId, 101);
    });

    test('已隐藏账户自动视为失效并返回 null', () async {
      // 记录分类使用 103 (hidden=true)
      await service.saveLastAccountId(
        ledgerId: 1,
        categoryId: 2,
        accountId: 103,
      );

      final accountId = await service.getLastAccountId(
        ledgerId: 1,
        categoryId: 2,
        availableAccounts: dummyAccounts,
      );
      expect(accountId, isNull);
    });

    test('支持多账本隔离', () async {
      // 账本 1 记分类 1 用微信(101)
      await service.saveLastAccountId(
        ledgerId: 1,
        categoryId: 1,
        accountId: 101,
      );

      // 账本 2 查分类 1 应为 null
      final accInLedger2 = await service.getLastAccountId(
        ledgerId: 2,
        categoryId: 1,
        availableAccounts: dummyAccounts,
      );
      expect(accInLedger2, isNull);
    });
  });
}
