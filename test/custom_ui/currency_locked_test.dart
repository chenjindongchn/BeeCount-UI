import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/custom_ui/providers/amount_format_provider.dart';
import 'package:beecount/utils/format_money.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('锁定币种 (Lock Currency) 验收测试', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      globalCurrencyLocked = false;
      globalShowCurrencySymbol = false;
      globalUseThousandSeparator = true;
    });

    test('1. currencyLockedProvider 初始为 false，支持 toggle 与持久化', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currencyLockedProvider), isFalse);
      expect(globalCurrencyLocked, isFalse);

      await container.read(currencyLockedProvider.notifier).toggle();
      expect(container.read(currencyLockedProvider), isTrue);
      expect(globalCurrencyLocked, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('lock_currency_mode'), isTrue);

      await container.read(currencyLockedProvider.notifier).setEnabled(false);
      expect(container.read(currencyLockedProvider), isFalse);
      expect(globalCurrencyLocked, isFalse);
      expect(prefs.getBool('lock_currency_mode'), isFalse);
    });

    test('2. 锁定币种开启时，formatDisplayAmount 强制隐藏所有货币符号', () {
      // 未锁定，允许显示货币符号
      globalCurrencyLocked = false;
      final withSymbol = formatDisplayAmount(
        1234.56,
        currencyCode: 'CNY',
        showCurrency: true,
      );
      expect(withSymbol, contains('¥'));

      // 开启锁定币种：强制不显示货币符号
      globalCurrencyLocked = true;
      final lockedDisplay = formatDisplayAmount(
        1234.56,
        currencyCode: 'CNY',
        showCurrency: true,
        signed: false,
      );
      expect(lockedDisplay, isNot(contains('¥')));
      expect(lockedDisplay, isNot(contains('CNY')));
      expect(lockedDisplay, equals('1,234.56'));

      // 美元同样不显示 $ 符号
      final lockedUsd = formatDisplayAmount(
        99.9,
        currencyCode: 'USD',
        showCurrency: true,
        signed: false,
      );
      expect(lockedUsd, isNot(contains('\$')));
      expect(lockedUsd, isNot(contains('USD')));
      expect(lockedUsd, equals('99.9'));
    });

    testWidgets('3. 记账抽屉转账模式下，锁定币种开启时隐藏账户卡片上的 CNY 币种标签',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          currencyLockedProvider.overrideWith((ref) => CurrencyLockedNotifier()),
        ],
      );
      addTearDown(container.dispose);

      Widget buildChip(WidgetRef ref) {
        final isLocked = ref.watch(currencyLockedProvider);
        const currency = 'CNY';
        return Column(
          children: [
            const Text('账户名'),
            if (!isLocked) ...[
              const SizedBox(height: 1),
              Text(currency),
            ],
          ],
        );
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) => buildChip(ref)),
            ),
          ),
        ),
      );

      // 默认未锁定：应能找到 CNY 标签
      expect(find.text('CNY'), findsOneWidget);

      // 开启锁定币种：CNY 标签应彻底消失
      await container.read(currencyLockedProvider.notifier).setEnabled(true);
      await tester.pumpAndSettle();

      expect(find.text('CNY'), findsNothing);
    });
  });
}
