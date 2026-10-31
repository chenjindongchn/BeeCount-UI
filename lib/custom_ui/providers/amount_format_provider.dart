import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/format_money.dart';

/// 千分位开关 Provider（默认 false：如 8888.00；开启为 true：如 8,888.00）
final thousandSeparatorProvider =
    StateNotifierProvider<ThousandSeparatorNotifier, bool>((ref) {
  return ThousandSeparatorNotifier();
});

class ThousandSeparatorNotifier extends StateNotifier<bool> {
  ThousandSeparatorNotifier() : super(false) {
    globalUseThousandSeparator = false;
    _loadPreference();
  }

  static const String _prefKey = 'use_thousand_separator';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
        globalUseThousandSeparator = saved;
      } else {
        state = false;
        globalUseThousandSeparator = false;
      }
    } catch (_) {
      state = false;
      globalUseThousandSeparator = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    globalUseThousandSeparator = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}
