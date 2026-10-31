import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount/utils/format_money.dart';
import 'package:beecount/utils/format_utils.dart';
import 'package:beecount/custom_ui/providers/amount_format_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    globalUseThousandSeparator = false;
  });

  group('金额千分位格式化测试', () {
    test('默认关闭千分位时，输出纯数字格式（符合截图期望）', () {
      expect(formatMoneyCompact(8888.0, trimZeros: false), '8888.00');
      expect(formatMoneyCompact(5555.0, trimZeros: false), '5555.00');
      expect(formatMoneyCompact(22.54, trimZeros: false), '22.54');
      expect(formatMoneyCompact(0.0, trimZeros: false), '0.00');
      expect(formatMoneyCompact(-65.0, trimZeros: false), '-65.00');
      expect(formatMoneyCompact(-109.0, trimZeros: false), '-109.00');
      expect(formatMoneyCompact(1234567.89, trimZeros: false), '1234567.89');

      expect(formatBalanceFull(8888.0, 'CNY'), '¥8888.00');
    });

    test('开启千分位开关时，输出传统千分位逗号格式', () {
      expect(formatMoneyCompact(8888.0, trimZeros: false, useThousandSeparator: true), '8,888.00');
      expect(formatMoneyCompact(5555.0, trimZeros: false, useThousandSeparator: true), '5,555.00');
      expect(formatMoneyCompact(1234567.89, trimZeros: false, useThousandSeparator: true), '1,234,567.89');

      expect(formatBalanceFull(8888.0, 'CNY', useThousandSeparator: true), '¥8,888.00');
    });

    test('ThousandSeparatorNotifier 状态切换与全局变量同步', () async {
      final notifier = ThousandSeparatorNotifier();
      expect(notifier.state, false);
      expect(globalUseThousandSeparator, false);

      await notifier.setEnabled(true);
      expect(notifier.state, true);
      expect(globalUseThousandSeparator, true);
      expect(formatMoneyCompact(8888.0, trimZeros: false), '8,888.00');

      await notifier.toggle();
      expect(notifier.state, false);
      expect(globalUseThousandSeparator, false);
      expect(formatMoneyCompact(8888.0, trimZeros: false), '8888.00');
    });
  });
}
