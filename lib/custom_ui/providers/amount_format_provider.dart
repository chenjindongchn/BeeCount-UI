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

/// 货币符号显示开关 Provider（默认 false：如 8888.00；开启为 true：如 ¥8888.00）
final currencySymbolVisibleProvider =
    StateNotifierProvider<CurrencySymbolVisibleNotifier, bool>((ref) {
  return CurrencySymbolVisibleNotifier();
});

class CurrencySymbolVisibleNotifier extends StateNotifier<bool> {
  CurrencySymbolVisibleNotifier() : super(false) {
    globalShowCurrencySymbol = false;
    _loadPreference();
  }

  static const String _prefKey = 'show_currency_symbol';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
        globalShowCurrencySymbol = saved;
      } else {
        state = false;
        globalShowCurrencySymbol = false;
      }
    } catch (_) {
      state = false;
      globalShowCurrencySymbol = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    globalShowCurrencySymbol = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}

/// 锁定币种开关 Provider（默认 false：未锁定；开启为 true：锁定币种，隐藏全软件币种标识与符号）
final currencyLockedProvider =
    StateNotifierProvider<CurrencyLockedNotifier, bool>((ref) {
  return CurrencyLockedNotifier();
});

class CurrencyLockedNotifier extends StateNotifier<bool> {
  CurrencyLockedNotifier() : super(false) {
    globalCurrencyLocked = false;
    _loadPreference();
  }

  static const String _prefKey = 'lock_currency_mode';

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
        globalCurrencyLocked = saved;
      } else {
        state = false;
        globalCurrencyLocked = false;
      }
    } catch (_) {
      state = false;
      globalCurrencyLocked = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    globalCurrencyLocked = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }

  Future<void> toggle() => setEnabled(!state);
}
