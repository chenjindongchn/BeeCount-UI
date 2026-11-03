import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/custom_ui/utils/frequent_notes_helper.dart';

void main() {
  group('FrequentNotesHelper 单元测试', () {
    test('根据分类名称智能匹配支出预设常用备注', () {
      final diningNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'expense',
        categoryName: '餐饮美食',
      );
      expect(diningNotes, contains('午餐'));
      expect(diningNotes, contains('外卖'));

      final transportNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'expense',
        categoryName: '交通出行',
      );
      expect(transportNotes, contains('地铁'));
      expect(transportNotes, contains('打车'));

      final shoppingNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'expense',
        categoryName: '日常购物',
      );
      expect(shoppingNotes, contains('超市'));
      expect(shoppingNotes, contains('日用品'));

      final housingNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'expense',
        categoryName: '居家房租水电',
      );
      expect(housingNotes, contains('房租'));
      expect(housingNotes, contains('电费'));
    });

    test('收入与转账类型常用备注匹配', () {
      final incomeNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'income',
        categoryName: '职业工资',
      );
      expect(incomeNotes, contains('工资'));
      expect(incomeNotes, contains('奖金'));

      final transferNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'transfer',
      );
      expect(transferNotes, contains('还信用卡'));
      expect(transferNotes, contains('零钱提现'));
    });

    test('未指定分类名称时回退至通用支出兜底备注', () {
      final defaultNotes = FrequentNotesHelper.getPresetNotes(
        kind: 'expense',
        categoryName: null,
      );
      expect(defaultNotes, isNotEmpty);
      expect(defaultNotes, contains('午餐'));
      expect(defaultNotes, contains('地铁'));
    });
  });
}
