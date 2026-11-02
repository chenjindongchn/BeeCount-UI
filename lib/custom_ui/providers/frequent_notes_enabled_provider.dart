import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记账抽屉常用备注推荐开关 Provider（默认 true：展示历史高频备注快捷胶囊；关闭为 false：不展示）
final frequentNotesEnabledProvider =
    StateNotifierProvider<FrequentNotesEnabledNotifier, bool>((ref) {
  return FrequentNotesEnabledNotifier();
});

class FrequentNotesEnabledNotifier extends StateNotifier<bool> {
  FrequentNotesEnabledNotifier() : super(true) {
    _loadPreference();
  }

  static const String _prefKey = 'frequent_notes_recommendation_enabled';

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
