import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 分类详情页面是否显示“累计金额趋势”图表 Provider
/// 默认 false：默认关闭；勾选开启后显示
final categoryDetailShowTrendProvider =
    StateNotifierProvider<CategoryDetailShowTrendNotifier, bool>((ref) {
  return CategoryDetailShowTrendNotifier();
});

class CategoryDetailShowTrendNotifier extends StateNotifier<bool> {
  CategoryDetailShowTrendNotifier() : super(false) {
    _loadPreference();
  }

  static const String _prefKey = 'custom_category_detail_show_trend';

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
