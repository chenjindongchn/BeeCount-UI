import 'package:beecount/custom_ui/pages/custom_mine_page.dart';
import 'package:beecount/custom_ui/widgets/origin_profile_card.dart';
import 'package:beecount/custom_ui/widgets/origin_setting_card.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CustomMinePage OriginOS 规范化测试', () {
    testWidgets('1. 顶部不展示个人资料卡片且主 Tab 模式下无异常返回箭头', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const CustomMinePage(),
          overrides: [
            bottomTabIndexProvider.overrideWith((ref) => 3),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 验证未渲染 OriginProfileCard（符合用户不需要个人卡片的需求）
      expect(find.byType(OriginProfileCard), findsNothing);

      // 验证未出现异常的返回按钮
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('2. 核心功能分组中成功提拔「分类管理」入口', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CustomMinePage()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 验证分类管理入口存在
      expect(find.text('分类管理'), findsOneWidget);
      expect(find.text('编辑自定义分类'), findsOneWidget);
    });

    testWidgets('3. 云同步卡片采用 OriginSettingGroup 统一呈现', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CustomMinePage()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 验证包含 OriginSettingGroup 容器
      expect(find.byType(OriginSettingGroup), findsWidgets);
      expect(find.text('云服务'), findsOneWidget);
    });

    testWidgets('4. 记账显示偏好中包含「金额千分位」开关，默认关闭，点击可切换', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CustomMinePage()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // 滚动找到金额千分位开关
      final itemFinder = find.text('金额千分位');
      await tester.scrollUntilVisible(itemFinder, 200);
      await tester.ensureVisible(itemFinder);
      await tester.pumpAndSettle();
      expect(itemFinder, findsOneWidget);
      expect(find.text('关闭：显示为 8888.00'), findsOneWidget);

      // 点击切换
      await tester.tap(itemFinder);
      await tester.pumpAndSettle();
      expect(find.text('开启：显示为 8,888.00'), findsOneWidget);
    });
  });
}

