import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 双击返回退出开关 Provider（默认 true：需连续返回两次退出；关闭为 false：按一次直接退出）
final doubleBackExitProvider =
    StateNotifierProvider<DoubleBackExitNotifier, bool>((ref) {
  return DoubleBackExitNotifier();
});

class DoubleBackExitNotifier extends StateNotifier<bool> {
  DoubleBackExitNotifier() : super(true) {
    _loadPreference();
  }

  static const String _prefKey = 'double_back_exit_enabled';

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
