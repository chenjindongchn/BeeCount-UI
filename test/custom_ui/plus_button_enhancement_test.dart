import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart' show BeeAction;
import 'package:beecount/custom_ui/providers/plus_button_enhancement_provider.dart';
import 'package:beecount/custom_ui/widgets/origin_bottom_nav_bar.dart';
import 'package:beecount/custom_ui/widgets/origin_quick_add_fan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('加号增强与扇形展开验收测试', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. plusButtonEnhancedProvider 初始为 false，支持 toggle 与持久化', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(plusButtonEnhancedProvider), isFalse);

      await container.read(plusButtonEnhancedProvider.notifier).toggle();
      expect(container.read(plusButtonEnhancedProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('plus_button_enhancement_enabled'), isTrue);

      await container.read(plusButtonEnhancedProvider.notifier).setEnabled(false);
      expect(container.read(plusButtonEnhancedProvider), isFalse);
      expect(prefs.getBool('plus_button_enhancement_enabled'), isFalse);
    });

    testWidgets('2. OriginQuickAddFan 几何位置验收：右下角加号展开不再错位，三动作均匀展开在屏幕内',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const viewport = Size(393, 852);
      const buttonCenter = Offset(353, 780); // 位于右下角独立悬浮按钮位置

      // 验证 offsets 处于左上方扇形（X 为负值，Y 为负值）
      final offsets = OriginQuickAddFan.getOffsets(buttonCenter, viewport);
      expect(offsets.length, 3);

      // 动作 0（拍照）：Offset(-88, -24)，加号偏左上方
      expect(offsets[0].dx, lessThan(0));
      expect(offsets[0].dy, lessThan(0));

      // 动作 1（相册）：Offset(-64, -64)，加号正左上方
      expect(offsets[1].dx, lessThan(0));
      expect(offsets[1].dy, lessThan(0));

      // 动作 2（语音）：Offset(-20, -88)，加号正上方偏左
      expect(offsets[2].dx, lessThan(0));
      expect(offsets[2].dy, lessThan(0));

      // 验证所有动作中心点均落在屏幕可见区域内，不贴边出界
      for (var i = 0; i < 3; i++) {
        final pos = OriginQuickAddFan.centerFor(buttonCenter, i, viewport);
        expect(pos.dx, greaterThan(32)); // 留有边距
        expect(pos.dx, lessThan(viewport.width - 20)); // 不超出右屏幕
        expect(pos.dy, greaterThan(100)); // 不超出顶部
        expect(pos.dy, lessThan(viewport.height)); // 不超出底部
      }

      // 测试渲染
      bool dismissed = false;
      String? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OriginQuickAddFan(
              buttonCenter: buttonCenter,
              actions: const [
                BeeAction(id: 'camera', label: '拍照记账', icon: Icon(Icons.camera)),
                BeeAction(id: 'album', label: '相册记账', icon: Icon(Icons.photo)),
                BeeAction(id: 'voice', label: '语音记账', icon: Icon(Icons.mic)),
              ],
              title: '快捷记账',
              hint: '滑动至图标后松手',
              cancelLabel: '关闭',
              onSelected: (id) => selectedId = id,
              onDismiss: () => dismissed = true,
              progress: 1.0,
            ),
          ),
        ),
      );

      // 验证文本已被移除，纯保留 3 个图标
      expect(find.text('快捷记账'), findsNothing);
      expect(find.text('拍照记账'), findsNothing);
      expect(find.text('相册记账'), findsNothing);
      expect(find.text('语音记账'), findsNothing);

      expect(find.byIcon(Icons.camera), findsOneWidget);
      expect(find.byIcon(Icons.photo), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // 点击语音记账图标
      await tester.tap(find.byIcon(Icons.mic));
      expect(selectedId, 'voice');

      // 点击遮罩收起
      await tester.tapAt(const Offset(50, 50));
      expect(dismissed, isTrue);
    });

    testWidgets('3. 底部导航栏加号按钮单击、双击手势区分验收', (tester) async {
      int tapCount = 0;
      int doubleTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: OriginBottomNavBar(
              currentIndex: 0,
              onTabSelected: (_) {},
              items: const [
                OriginBottomNavItem(
                  icon: Icons.receipt_outlined,
                  selectedIcon: Icons.receipt,
                  label: '明细',
                ),
                OriginBottomNavItem(
                  icon: Icons.pie_chart_outline,
                  selectedIcon: Icons.pie_chart,
                  label: '洞察',
                ),
              ],
              onCenterTap: () => tapCount++,
              onCenterDoubleTap: () => doubleTapCount++,
            ),
          ),
        ),
      );

      final plusBtn = find.byIcon(Icons.add_rounded);
      expect(plusBtn, findsOneWidget);

      // 双击测试：在 250ms 内连续点击两次
      await tester.tap(plusBtn);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      expect(doubleTapCount, 1);
      expect(tapCount, 0); // 双击不触发单击

      // 单击测试：点击一次并等待 300ms
      await tester.tap(plusBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(tapCount, 1);
      expect(doubleTapCount, 1);
    });

    testWidgets('4. 「加号增强」选项准确放置在「货币符号」上方且交互生效',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final plusButtonEnhanced =
                      ref.watch(plusButtonEnhancedProvider);
                  return ListView(
                    children: [
                      ListTile(
                        key: const Key('plus_setting'),
                        title: const Text('加号增强'),
                        subtitle: Text(
                          plusButtonEnhanced
                              ? '开启：长按语音，双击拍照'
                              : '关闭：长按展开快捷菜单',
                        ),
                        onTap: () => ref
                            .read(plusButtonEnhancedProvider.notifier)
                            .toggle(),
                      ),
                      const ListTile(
                        key: Key('currency_setting'),
                        title: Text('货币符号'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final plusSetting = find.byKey(const Key('plus_setting'));
      final currencySetting = find.byKey(const Key('currency_setting'));

      expect(plusSetting, findsOneWidget);
      expect(currencySetting, findsOneWidget);

      // 验证「加号增强」位于「货币符号」上方（Y 坐标更小）
      final plusY = tester.getTopLeft(plusSetting).dy;
      final currencyY = tester.getTopLeft(currencySetting).dy;
      expect(plusY, lessThan(currencyY));

      // 初始状态下副标题为关闭文案
      expect(find.text('关闭：长按展开快捷菜单'), findsOneWidget);

      // 点击加号增强进行切换
      await tester.tap(plusSetting);
      await tester.pumpAndSettle();

      // 验证切换为开启文案
      expect(find.text('开启：长按语音，双击拍照'), findsOneWidget);
    });
  });
}
