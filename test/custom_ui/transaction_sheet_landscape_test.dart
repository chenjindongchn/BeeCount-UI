import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/pages/transaction/recording/bindings/recording_category_section.dart';
import 'package:beecount/custom_ui/pages/custom_transaction_sheet.dart';

class FakeAttachmentService extends Fake implements AttachmentService {
  @override
  Future<Directory> getAttachmentDirectory() async {
    return Directory.systemTemp;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('横屏模式下 CustomTransactionSheet 布局自适应无溢出测试', (tester) async {
    // 模拟横屏尺寸：宽 792, 高 360 (类似 3168x1440 屏幕密度为 4.0 时的视口)
    tester.view.physicalSize = const Size(792, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const testAccount = Account(
      id: 1,
      ledgerId: 1,
      name: '现金账户',
      type: 'cash',
      currency: 'CNY',
      initialBalance: 1000.0,
      hidden: false,
      sortOrder: 0,
    );

    const testCategory = Category(
      id: 1,
      name: '餐饮',
      kind: 'expense',
      sortOrder: 0,
      level: 1,
      iconType: 'default',
      icon: 'restaurant',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentLedgerIdProvider.overrideWith((ref) => 1),
          currentLedgerCurrencyProvider.overrideWith((ref) => 'CNY'),
          attachmentServiceProvider.overrideWithValue(FakeAttachmentService()),
          accountsStreamProvider(1).overrideWith((ref) => Stream.value([testAccount])),
          allAccountsStreamProvider.overrideWith((ref) => Stream.value([testAccount])),
          recordingCategoriesProvider((ledgerId: 1, kind: 'expense'))
              .overrideWith((ref) => Future.value([testCategory])),
          recordingCategoriesProvider((ledgerId: 1, kind: 'income'))
              .overrideWith((ref) => Future.value([testCategory])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CustomTransactionSheet(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 验证没有 RenderFlex overflow
    expect(tester.takeException(), isNull);
    // 验证数字键盘渲染正常
    expect(find.text('7'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // 验证无附件时，不应该显示添加图片图标按钮
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing);

    // 等待日志服务的防抖 Timer 结束
    await tester.pump(const Duration(seconds: 3));
  });
}
