import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart' as db;
import '../../utils/account_type_utils.dart';

/// 资产页面是否按分类分组展示 Provider（默认 true：按账户类别分组；false：所有账户平铺展示）
final showAccountGroupingProvider =
    StateNotifierProvider<ShowAccountGroupingNotifier, bool>((ref) {
  return ShowAccountGroupingNotifier();
});

class ShowAccountGroupingNotifier extends StateNotifier<bool> {
  ShowAccountGroupingNotifier() : super(true) {
    _loadPreference();
  }

  static const String _prefKey = 'custom_account_grouping_enabled';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}

/// 资产页面平铺展示时的全局自定义账户 ID 排序 Provider
final customAccountOrderProvider =
    StateNotifierProvider<CustomAccountOrderNotifier, List<int>>((ref) {
  return CustomAccountOrderNotifier();
});

class CustomAccountOrderNotifier extends StateNotifier<List<int>> {
  CustomAccountOrderNotifier() : super(const []) {
    _loadPreference();
  }

  static const String _prefKey = 'custom_account_global_order_ids';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is List) {
          state = decoded.map((e) => (e as num).toInt()).toList();
        }
      }
    } catch (_) {}
  }

  Future<void> updateOrder(List<int> newOrder) async {
    state = List<int>.unmodifiable(newOrder);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(newOrder));
    } catch (_) {}
  }
}

/// 按照资产页面的规则排序账户列表：
/// 1. 若用户在资产页面自定义调整过全局顺序（orderIds 不为空），则优先按该全局顺序排列；
/// 2. 否则按资产页面原本的默认顺序：按大类标准顺序（accountTypeOrder）分组，组内按 sortOrder 升序排列。
List<db.Account> sortAccountsLikeAssetsPage(
  List<db.Account> accounts,
  List<int> globalOrderIds,
) {
  if (accounts.isEmpty) return accounts;

  // 1. 如果有全局自定义排序
  if (globalOrderIds.isNotEmpty) {
    final map = {for (final a in accounts) a.id: a};
    final sorted = <db.Account>[];
    for (final id in globalOrderIds) {
      final acc = map.remove(id);
      if (acc != null) sorted.add(acc);
    }
    // 未在自定义排序列表中的账户（如新创建的）按默认规则追加到末尾
    if (map.isNotEmpty) {
      final remaining = map.values.toList();
      _sortByDefaultAssetsOrder(remaining);
      sorted.addAll(remaining);
    }
    return sorted;
  }

  // 2. 默认资产页排序规则：按 accountTypeOrder + 组内 sortOrder
  final list = List<db.Account>.from(accounts);
  _sortByDefaultAssetsOrder(list);
  return list;
}

void _sortByDefaultAssetsOrder(List<db.Account> list) {
  list.sort((a, b) {
    final aTypeIdx = accountTypeOrder.indexOf(a.type);
    final bTypeIdx = accountTypeOrder.indexOf(b.type);
    final aRank = aTypeIdx == -1 ? 9999 : aTypeIdx;
    final bRank = bTypeIdx == -1 ? 9999 : bTypeIdx;
    if (aRank != bRank) {
      return aRank.compareTo(bRank);
    }
    // 同一类型内部按 sortOrder 升序排序
    if (a.sortOrder != b.sortOrder) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    return a.id.compareTo(b.id);
  });
}
