import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/custom_ui/providers/account_color_display_provider.dart';
import 'package:beecount/custom_ui/utils/account_color_utils.dart';
import 'package:beecount/custom_ui/widgets/origin_transaction_item.dart';

class _FakeAccountColorDisplayNotifier extends AccountColorDisplayNotifier {
  _FakeAccountColorDisplayNotifier(bool initial) {
    state = initial;
  }
}

void main() {
  group('账户类型颜色与夜间模式适配测试', () {
    test('日间模式色彩映射符合设计规范与对比度要求', () {
      expect(getAccountTypeColorAdaptive('wechat', isDark: false),
          const Color(0xFF07C160));
      expect(getAccountTypeColorAdaptive('alipay', isDark: false),
          const Color(0xFF1677FF));
      expect(getAccountTypeColorAdaptive('bank_card', isDark: false),
          const Color(0xFF2E84E6));
      expect(getAccountTypeColorAdaptive('credit_card', isDark: false),
          const Color(0xFF7C4DFF));
      expect(getAccountTypeColorAdaptive('cash', isDark: false),
          const Color(0xFFD48806));
      expect(getAccountTypeColorAdaptive('other', isDark: false),
          const Color(0xFF8C8C8C));
    });

    test('夜间模式色彩映射降低刺眼高光，采用沉稳护眼色系', () {
      expect(getAccountTypeColorAdaptive('wechat', isDark: true),
          const Color(0xFF0E7A43));
      expect(getAccountTypeColorAdaptive('alipay', isDark: true),
          const Color(0xFF125EC4));
      expect(getAccountTypeColorAdaptive('bank_card', isDark: true),
          const Color(0xFF2066B3));
      expect(getAccountTypeColorAdaptive('credit_card', isDark: true),
          const Color(0xFF5E35B1));
      expect(getAccountTypeColorAdaptive('cash', isDark: true),
          const Color(0xFFB37402));
      expect(getAccountTypeColorAdaptive('other', isDark: true),
          const Color(0xFF525252));
    });
  });

  group('OriginTransactionItem 胶囊化显示与夜间模式 Widget 测试', () {
    final mockTx = Transaction(
      id: 1,
      ledgerId: 1,
      accountId: 10,
      type: 'expense',
      amount: 88.0,
      happenedAt: DateTime.now(),
      excludeFromStats: false,
      excludeFromBudget: false,
    );

    final mockAccount = Account(
      id: 10,
      ledgerId: 1,
      name: '微信零钱',
      type: 'wechat',
      currency: 'CNY',
      initialBalance: 0.0,
      sortOrder: 0,
      hidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final mockToAccount = Account(
      id: 11,
      ledgerId: 1,
      name: '招商银行',
      type: 'bank_card',
      currency: 'CNY',
      initialBalance: 0.0,
      sortOrder: 1,
      hidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    testWidgets('开启颜色显示时，渲染为带椭圆圆角背景和白字的胶囊（日间模式）', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountColorDisplayProvider.overrideWith(
              (ref) => _FakeAccountColorDisplayNotifier(true),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: Brightness.light),
            home: Scaffold(
              body: OriginTransactionItem(
                transaction: mockTx,
                account: mockAccount,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证找到“微信零钱”文本
      final wechatTextFinder = find.text('微信零钱');
      expect(wechatTextFinder, findsOneWidget);

      final Text wechatText = tester.widget(wechatTextFinder);
      expect(wechatText.style?.color, Colors.white);

      // 验证其父级容器为胶囊装饰（全圆角，且背景为微信绿）
      final containerFinder = find.ancestor(
        of: wechatTextFinder,
        matching: find.byType(Container),
      ).first;

      final Container container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, const Color(0xFF07C160));
      expect(decoration.borderRadius, BorderRadius.circular(100.0));
    });

    testWidgets('夜间模式下，胶囊采用夜间暗色护眼调性', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountColorDisplayProvider.overrideWith(
              (ref) => _FakeAccountColorDisplayNotifier(true),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: OriginTransactionItem(
                transaction: mockTx,
                account: mockAccount,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final wechatTextFinder = find.text('微信零钱');
      expect(wechatTextFinder, findsOneWidget);

      final containerFinder = find.ancestor(
        of: wechatTextFinder,
        matching: find.byType(Container),
      ).first;

      final Container container = tester.widget(containerFinder);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, const Color(0xFF0E7A43));
    });

    testWidgets('转账场景下，源账户与目标账户渲染为独立色彩双胶囊加箭头', (tester) async {
      final transferTx = Transaction(
        id: 2,
        ledgerId: 1,
        accountId: 10,
        toAccountId: 11,
        type: 'transfer',
        amount: 500.0,
        happenedAt: DateTime.now(),
        excludeFromStats: false,
        excludeFromBudget: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountColorDisplayProvider.overrideWith(
              (ref) => _FakeAccountColorDisplayNotifier(true),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: Brightness.light),
            home: Scaffold(
              body: OriginTransactionItem(
                transaction: transferTx,
                account: mockAccount,
                toAccount: mockToAccount,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('微信零钱'), findsOneWidget);
      expect(find.text('招商银行'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      // 验证微信零钱胶囊为绿色
      final wechatContainer = tester.widget<Container>(
        find.ancestor(of: find.text('微信零钱'), matching: find.byType(Container)).first,
      );
      final wechatDec = wechatContainer.decoration as BoxDecoration?;
      expect(wechatDec?.color, const Color(0xFF07C160));

      // 验证招商银行胶囊为银行卡浅蓝
      final bankContainer = tester.widget<Container>(
        find.ancestor(of: find.text('招商银行'), matching: find.byType(Container)).first,
      );
      final bankDec = bankContainer.decoration as BoxDecoration?;
      expect(bankDec?.color, const Color(0xFF2E84E6));
    });

    testWidgets('关闭颜色显示开关时，以普通文本展示，不添加彩色胶囊', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountColorDisplayProvider.overrideWith(
              (ref) => _FakeAccountColorDisplayNotifier(false),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: OriginTransactionItem(
                transaction: mockTx,
                account: mockAccount,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final wechatTextFinder = find.text('微信零钱');
      expect(wechatTextFinder, findsOneWidget);

      final Text wechatText = tester.widget(wechatTextFinder);
      // 未开启时不为纯白字
      expect(wechatText.style?.color != Colors.white, isTrue);

      // 不存在以该文字为 child 的胶囊 Container
      final containers = find.ancestor(
        of: wechatTextFinder,
        matching: find.byType(Container),
      );
      expect(containers, findsNothing);
    });
  });
}
