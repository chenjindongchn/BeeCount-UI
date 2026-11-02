import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 明细页面资产颜色显示开关 Provider
/// 默认 false：保持默认灰色；开启为 true：在明细页面按资产属性变换颜色
final accountColorDisplayProvider =
    StateNotifierProvider<AccountColorDisplayNotifier, bool>((ref) {
  return AccountColorDisplayNotifier();
});

class AccountColorDisplayNotifier extends StateNotifier<bool> {
  AccountColorDisplayNotifier() : super(false) {
    _loadPreference();
  }

  static const String _prefKey = 'detail_page_account_color_display_enabled';

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
