import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/custom_ui/widgets/custom_account_grid_picker.dart';

void main() {
  final List<Account> testAccounts = [
    Account(
      id: 101,
      ledgerId: 1,
      name: '招商银行卡',
      type: 'debitCard',
      initialBalance: 1000.0,
      currency: 'CNY',
      sortOrder: 0,
      hidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Account(
      id: 102,
      ledgerId: 1,
      name: '微信钱包',
      type: 'wechat',
      initialBalance: 200.0,
      currency: 'USD',
      sortOrder: 1,
      hidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  testWidgets('CustomAccountGridPicker 显示图标网格、不选择账户在首位且不显示币种', (tester) async {
    int? selectedId;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedId = await CustomAccountGridPicker.show(
                    context,
                    accounts: testAccounts,
                    currentAccountId: 101,
                    showNoAccountOption: true,
                    title: '选择账户',
                  );
                },
                child: const Text('打开选择器'),
              ),
            ),
          ),
        ),
      ),
    );

    // 点击按钮打开弹窗
    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();

    // 验证标题
    expect(find.text('选择账户'), findsOneWidget);

    // 验证“不选择账户”存在且排在首位
    expect(find.text('不选择账户'), findsOneWidget);
    expect(find.text('招商银行卡'), findsOneWidget);
    expect(find.text('微信钱包'), findsOneWidget);

    // 验证币种 'CNY' 和 'USD' 不会作为文本出现在弹窗中
    expect(find.text('CNY'), findsNothing);
    expect(find.text('USD'), findsNothing);

    // 点击“不选择账户”
    await tester.tap(find.text('不选择账户'));
    await tester.pumpAndSettle();

    // 验证返回 -1 (noAccountId)
    expect(selectedId, CustomAccountGridPicker.noAccountId);
  });

  testWidgets('CustomAccountGridPicker 点击账户返回对应 ID', (tester) async {
    int? selectedId;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedId = await CustomAccountGridPicker.show(
                    context,
                    accounts: testAccounts,
                    currentAccountId: null,
                    showNoAccountOption: true,
                  );
                },
                child: const Text('打开选择器'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开选择器'));
    await tester.pumpAndSettle();

    // 点击招商银行卡
    await tester.tap(find.text('招商银行卡'));
    await tester.pumpAndSettle();

    expect(selectedId, 101);
  });
}
