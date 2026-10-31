import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount/custom_ui/pages/custom_accounts_page.dart';
import 'package:beecount/custom_ui/styles/origin_tokens.dart';
import 'package:beecount/custom_ui/widgets/origin_card.dart';
import 'package:beecount/data/db.dart' as db;
import 'package:beecount/providers.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/l10n/app_localizations.dart';

void main() {
  testWidgets('OriginCard 必须通过带有 Clip.antiAlias 和 borderRadius 的 Material 承载', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OriginCard(
            radius: 16.0,
            child: Text('Test Card Content'),
          ),
        ),
      ),
    );

    final materialFinder = find.descendant(
      of: find.byType(OriginCard),
      matching: find.byType(Material),
    );
    expect(materialFinder, findsOneWidget);

    final Material material = tester.widget(materialFinder);
    expect(material.clipBehavior, equals(Clip.antiAlias));
    expect(material.borderRadius, equals(BorderRadius.circular(16.0)));
  });

  testWidgets('资产列表中的账户条目在单项或多项首尾时 InkWell 应设置贴合卡片的 borderRadius', (tester) async {
    final fakeAccounts = [
      db.Account(
        id: 1,
        ledgerId: 1,
        name: '现金钱包',
        type: 'cash',
        currency: 'CNY',
        initialBalance: 100.0,
        sortOrder: 0,
        hidden: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      db.Account(
        id: 2,
        ledgerId: 1,
        name: '工商银行',
        type: 'bank',
        currency: 'CNY',
        initialBalance: 500.0,
        sortOrder: 0,
        hidden: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWith((ref) => 1),
          baseCurrencyProvider.overrideWith((ref) => 'CNY'),
          allAccountsStreamProvider.overrideWith((ref) => Stream.value(fakeAccounts)),
          allAccountStatsProvider.overrideWith((ref) => Future.value({})),
          hideAmountsProvider.overrideWith((ref) => false),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CustomAccountsPage(asTab: true),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 在 CustomAccountsPage 中查找所有 InkWell
    final inkWellFinder = find.descendant(
      of: find.byType(CustomAccountsPage),
      matching: find.byType(InkWell),
    );

    // 验证账户行的 InkWell 正确配置了贴合卡片的圆角 (12.0dp)
    // 两个不同类别的单项账户（现金 1 个，银行 1 个），各自卡片里只有 1 项，应为全圆角
    final rowFinder = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_OriginAccountRow');
    expect(rowFinder, findsNWidgets(2));

    for (final rowElement in rowFinder.evaluate()) {
      final inkWellFinder = find.descendant(
        of: find.byWidget(rowElement.widget),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsOneWidget);
      final InkWell inkWell = tester.widget(inkWellFinder);
      expect(inkWell.borderRadius, equals(BorderRadius.circular(OriginTokens.cardRadius)));
    }
  });
}
