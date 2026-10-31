import 'package:beecount/custom_ui/pages/custom_splash_page.dart';
import 'package:beecount/custom_ui/styles/origin_tokens.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/shared/branding/bee_artwork.dart';
import 'package:beecount/providers/ui_state_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    themeMode: mode,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('CustomSplashPage 冷启动与品牌一致性测试', () {
    testWidgets('1. 展示新定制品牌 Logo 与「记账蓝盒」，杜绝旧小蜜蜂与旧标语', (tester) async {
      await tester.pumpWidget(_buildTestApp(const CustomSplashPage()));
      await tester.pump();

      // 验证展示了新定制的名称
      expect(find.text(OriginAppInfo.appName), findsOneWidget);
      expect(find.text('极简记账 · 掌控生活'), findsOneWidget);

      // 验证渲染了新 Logo assets/logo2.png
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, 'assets/logo2.png');

      // 严密断言：绝不包含旧版小蜜蜂组件与旧标语
      expect(find.byType(BeeIcon), findsNothing);
      expect(find.text('蜜蜂记账'), findsNothing);
      expect(find.text('一笔一蜜'), findsNothing);

      // 严密断言：绝不包含原版长达 1.2 秒的强制飞线动画 BeeTrailBackdrop
      expect(find.byType(BeeTrailBackdrop), findsNothing);
    });

    testWidgets('2. 异常状态下展示重试按钮且点击可触发回调', (tester) async {
      var retryClicked = false;
      await tester.pumpWidget(
        _buildTestApp(
          CustomSplashPage(
            loadError: true,
            onRetry: () => retryClicked = true,
          ),
        ),
      );
      await tester.pump();

      final retryBtnFinder = find.byType(FilledButton);
      expect(retryBtnFinder, findsOneWidget);
      await tester.tap(retryBtnFinder);
      expect(retryClicked, isTrue);
    });

    testWidgets('3. CustomAppStartupGate 就绪前后路由切换流畅且无多余动画拖延', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appSplashInitProvider.overrideWith((ref) async {}),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _buildTestApp(
            const CustomAppStartupGate(
              child: Text('MainAppReady'),
            ),
          ),
        ),
      );
      await tester.pump();

      // 初始状态为 splash，应呈现 CustomSplashPage
      expect(find.byType(CustomSplashPage), findsOneWidget);
      expect(find.text('MainAppReady'), findsNothing);

      // 触发数据就绪
      container.read(appInitStateProvider.notifier).state = AppInitState.ready;
      await tester.pump();

      // 立即切入主页面，0 毫秒强制阻滞
      expect(find.text('MainAppReady'), findsOneWidget);
      expect(find.byType(CustomSplashPage), findsNothing);
    });
  });
}
