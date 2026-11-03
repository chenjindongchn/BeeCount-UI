import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BeeResourceBreakdown 中金额垂直居中于当前行', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: applyBeeCardTheme(ThemeData()),
      home: Scaffold(
        body: BeeResourceBreakdown(
          items: const [
            BeeResourceBreakdownItem(
              id: '1',
              label: '餐饮美食',
              amount: '¥ 128.50',
              detail: '5 笔 · 45.0%',
              fraction: 0.45,
              icon: Icon(Icons.restaurant),
            ),
          ],
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final inkWellFinder = find.byType(InkWell);
    expect(inkWellFinder, findsOneWidget);

    final inkWellRect = tester.getRect(inkWellFinder);
    final amountFinder = find.text('¥ 128.50');
    expect(amountFinder, findsOneWidget);

    final amountRect = tester.getRect(amountFinder);

    // 验证金额的垂直中心与整行的垂直中心对齐（误差在 1 像素以内）
    expect((amountRect.center.dy - inkWellRect.center.dy).abs(), lessThan(1.5));
  });

  testWidgets('BeeAnalyticsRankingList 展开子项中金额垂直居中于当前行', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: applyBeeCardTheme(ThemeData()),
      home: Scaffold(
        body: BeeAnalyticsRankingList(
          items: const [
            BeeRankItem(
              id: 'parent',
              label: '餐饮',
              amount: '¥ 500.00',
              fraction: 0.5,
              icon: Icon(Icons.category),
              children: [
                BeeRankItem(
                  id: 'child1',
                  label: '午餐',
                  amount: '¥ 120.00',
                  fraction: 0.24,
                  icon: Icon(Icons.lunch_dining),
                ),
              ],
            ),
          ],
          expanded: const {'parent'},
          onExpand: (_) {},
          onDetail: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final childFinder = find.byKey(const ValueKey('analytics-child-child1'));
    expect(childFinder, findsOneWidget);

    final childRect = tester.getRect(childFinder);
    final amountFinder = find.text('¥ 120.00');
    expect(amountFinder, findsOneWidget);

    final amountRect = tester.getRect(amountFinder);

    // 验证展开的二级分类金额在整行（高度至少 43）垂直居中
    expect((amountRect.center.dy - childRect.center.dy).abs(), lessThan(1.5));
  });
}
