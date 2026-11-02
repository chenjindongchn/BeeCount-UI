import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 加号增强开关 Provider（默认 false：长按展开快捷菜单；开启为 true：长按语音，双击拍照）
final plusButtonEnhancedProvider =
    StateNotifierProvider<PlusButtonEnhancedNotifier, bool>((ref) {
  return PlusButtonEnhancedNotifier();
});

class PlusButtonEnhancedNotifier extends StateNotifier<bool> {
  PlusButtonEnhancedNotifier() : super(false) {
    _loadPreference();
  }

  static const String _prefKey = 'plus_button_enhancement_enabled';

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
