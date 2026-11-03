import '../../data/repositories/base_repository.dart';
import '../../models/note_history.dart';
import '../../services/data/note_history_service.dart';

/// 记账抽屉常用备注智能推荐工具
///
/// 核心解决记账冷启动与无历史记录时推荐区域空白的问题：
/// 1. 优先提取用户在当前账本/分类下的真实历史高频备注；
/// 2. 当历史备注不足或为空时，智能依据分类语义补充行业通用高频备注；
/// 3. 确保在设置开启「常用备注推荐」后，记账抽屉始终拥有优雅且贴合场景的快捷输入胶囊。
class FrequentNotesHelper {
  // --- 预置高频常用备注词库 ---

  static const List<String> _defaultExpenseNotes = [
    '午餐',
    '晚餐',
    '外卖',
    '地铁',
    '超市',
    '打车',
    '买菜',
    '水果',
  ];

  static const List<String> _diningNotes = [
    '午餐',
    '晚餐',
    '外卖',
    '早餐',
    '咖啡',
    '奶茶',
    '零食',
    '水果',
    '夜宵',
    '聚餐',
  ];

  static const List<String> _transportNotes = [
    '地铁',
    '打车',
    '公交',
    '加油',
    '停车费',
    '打车回家',
    '打车上班',
    '高铁票',
    '机票',
    '充电费',
  ];

  static const List<String> _shoppingNotes = [
    '超市',
    '日用品',
    '买菜',
    '网购',
    '买衣服',
    '生活用品',
    '水果零食',
    '数码配件',
  ];

  static const List<String> _housingNotes = [
    '房租',
    '电费',
    '水费',
    '燃气费',
    '物业费',
    '宽带费',
    '生活杂费',
    '维修费',
  ];

  static const List<String> _entertainmentNotes = [
    '电影',
    '游戏充值',
    '聚会',
    '门票',
    '剧本杀',
    'KTV',
    '按摩足疗',
    '周边潮玩',
  ];

  static const List<String> _medicalNotes = [
    '买药',
    '医院挂号',
    '体检',
    '看牙',
    '眼科配镜',
    '口罩抗原',
    '保健品',
  ];

  static const List<String> _educationNotes = [
    '买书',
    '课程培训',
    '考证报名',
    '文具用品',
    '学费',
    '学习资料',
  ];

  static const List<String> _petNotes = [
    '猫粮狗粮',
    '宠物零食',
    '猫砂',
    '驱虫疫苗',
    '宠物洗澡',
    '宠物看病',
    '宠物玩具',
  ];

  static const List<String> _socialNotes = [
    '份子钱',
    '生日礼物',
    '请客吃饭',
    '随礼',
    '发红包',
    '探病慰问',
  ];

  static const List<String> _incomeNotes = [
    '工资',
    '奖金',
    '报销款',
    '兼职收入',
    '理财收益',
    '微信红包',
    '退款入账',
    '二手闲置',
  ];

  static const List<String> _transferNotes = [
    '还信用卡',
    '还花呗',
    '零钱提现',
    '还借款',
    '生活费',
    '理财转入',
    '备用金',
  ];

  /// 根据分类名称与交易类型智能推断高频预设备注
  static List<String> getPresetNotes({
    required String kind,
    String? categoryName,
  }) {
    if (kind == 'income') {
      return _incomeNotes;
    }
    if (kind == 'transfer') {
      return _transferNotes;
    }

    final name = (categoryName ?? '').trim().toLowerCase();
    if (name.isEmpty) {
      return _defaultExpenseNotes;
    }

    if (_matches(name, ['餐', '饭', '吃', '喝', '饮', '咖啡', '茶', '酒', '外卖', '早', '午', '晚', '夜宵', '食'])) {
      return _diningNotes;
    }
    if (_matches(name, ['车', '行', '路', '地铁', '公交', '打车', '高铁', '飞机', '机票', '油', '停车', '充'])) {
      return _transportNotes;
    }
    if (_matches(name, ['购', '买', '超市', '日用', '商场', '网购', '服饰', '衣', '鞋', '数码'])) {
      return _shoppingNotes;
    }
    if (_matches(name, ['房', '住', '家', '水电', '燃气', '物业', '宽带', '租', '修'])) {
      return _housingNotes;
    }
    if (_matches(name, ['娱', '玩', '影', '游', '唱', 'ktv', '聚会', '休闲'])) {
      return _entertainmentNotes;
    }
    if (_matches(name, ['医', '药', '病', '体检', '诊', '健', '牙'])) {
      return _medicalNotes;
    }
    if (_matches(name, ['教', '学', '书', '课', '训', '考'])) {
      return _educationNotes;
    }
    if (_matches(name, ['宠', '猫', '狗'])) {
      return _petNotes;
    }
    if (_matches(name, ['礼', '送', '人情', '社交', '红'])) {
      return _socialNotes;
    }

    return _defaultExpenseNotes;
  }

  static bool _matches(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  /// 综合聚合推荐备注：历史高频优先 + 预置语义兜底补充
  static Future<List<String>> getRecommendedNotes({
    required BaseRepository repository,
    required int ledgerId,
    required NoteHistoryScope scope,
    required NoteHistorySort sort,
    required String kind,
    int? categoryId,
    String? categorySyncId,
    String? categoryName,
    int limit = 8,
  }) async {
    final result = <String>[];
    final seen = <String>{};

    // 1. 尝试拉取用户本地历史备注记录
    try {
      final history = await NoteHistoryService.getHistoryNotes(
        repository: repository,
        ledgerId: ledgerId,
        scope: scope,
        sort: sort,
        categoryId: categoryId,
        categorySyncId: categorySyncId,
        limit: limit,
      );

      for (final item in history) {
        final trimmed = item.note.trim();
        if (trimmed.isNotEmpty && seen.add(trimmed)) {
          result.add(trimmed);
          if (result.length >= limit) break;
        }
      }

      // 如果当前分类模式下历史记录为空，且限制了分类，回退查询一次全账本历史备注来补充
      if (result.isEmpty &&
          scope == NoteHistoryScope.currentCategory &&
          (categoryId != null || (categorySyncId?.isNotEmpty ?? false))) {
        final fallbackHistory = await NoteHistoryService.getHistoryNotes(
          repository: repository,
          ledgerId: ledgerId,
          scope: NoteHistoryScope.allCategories,
          sort: sort,
          limit: limit,
        );
        for (final item in fallbackHistory) {
          final trimmed = item.note.trim();
          if (trimmed.isNotEmpty && seen.add(trimmed)) {
            result.add(trimmed);
            if (result.length >= limit) break;
          }
        }
      }
    } catch (_) {}

    // 2. 数量未达上限时，智能补全当前分类/类型的经典预置常用备注
    if (result.length < limit) {
      final presets = getPresetNotes(
        kind: kind,
        categoryName: categoryName,
      );
      for (final p in presets) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty && seen.add(trimmed)) {
          result.add(trimmed);
          if (result.length >= limit) break;
        }
      }
    }

    return result;
  }
}
