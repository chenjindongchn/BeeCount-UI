import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
