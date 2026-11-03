import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db.dart';

/// 资产偏好设置：是否默认选择上次的支出账户（按分类记忆上次使用的账户）
/// 开启后，在记账选择分类时会自动切换为该分类上次使用的账户；未操作过的分类不显示账户
final rememberLastAccountEnabledProvider =
    StateNotifierProvider<RememberLastAccountEnabledNotifier, bool>((ref) {
  return RememberLastAccountEnabledNotifier();
});

class RememberLastAccountEnabledNotifier extends StateNotifier<bool> {
  RememberLastAccountEnabledNotifier() : super(false) {
    _loadPreference();
  }

  static const String _prefKey = 'custom_remember_last_category_account_enabled';

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

/// 分类上次使用账户记忆服务 Provider
final categoryAccountMemoryServiceProvider =
    Provider<CategoryAccountMemoryService>((ref) {
  return CategoryAccountMemoryService();
});

class CategoryAccountMemoryService {
  // 内存缓存: { ledgerId: { categoryId: accountId } }
  final Map<int, Map<int, int>> _memoryCache = {};

  static String _prefKeyForLedger(int ledgerId) =>
      'custom_last_category_account_map_$ledgerId';

  /// 异步读取指定账本与分类的上次使用账户 ID
  /// [availableAccounts] 用于过滤已隐藏或已删除的账户
  Future<int?> getLastAccountId({
    required int ledgerId,
    required int categoryId,
    int? parentCategoryId,
    List<Account>? availableAccounts,
  }) async {
    final map = await _getMapForLedger(ledgerId);

    // 1. 优先匹配当前分类
    int? accountId = map[categoryId];

    // 2. 如果子分类无记录，尝试回退查父分类
    if (accountId == null && parentCategoryId != null && parentCategoryId > 0) {
      accountId = map[parentCategoryId];
    }

    if (accountId == null) return null;

    // 3. 校验账户是否仍然有效且未隐藏
    if (availableAccounts != null) {
      final isValid = availableAccounts.any(
        (a) => a.id == accountId && !a.hidden,
      );
      if (!isValid) {
        // 如果账户已失效/已隐藏，视同未操作过
        return null;
      }
    }

    return accountId;
  }

  /// 保存分类对应的上次使用账户 ID
  Future<void> saveLastAccountId({
    required int ledgerId,
    required int categoryId,
    required int accountId,
    int? parentCategoryId,
  }) async {
    final map = await _getMapForLedger(ledgerId);
    map[categoryId] = accountId;
    if (parentCategoryId != null && parentCategoryId > 0) {
      map[parentCategoryId] = accountId;
    }

    _memoryCache[ledgerId] = map;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(
        map.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString(_prefKeyForLedger(ledgerId), jsonStr);
    } catch (_) {}
  }

  /// 获取账本对应的内存或持久化数据
  Future<Map<int, int>> _getMapForLedger(int ledgerId) async {
    if (_memoryCache.containsKey(ledgerId)) {
      return _memoryCache[ledgerId]!;
    }

    final Map<int, int> map = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefKeyForLedger(ledgerId));
      if (savedStr != null && savedStr.isNotEmpty) {
        final decoded = jsonDecode(savedStr);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final catId = int.tryParse(entry.key);
            final accId = entry.value is num ? (entry.value as num).toInt() : null;
            if (catId != null && accId != null) {
              map[catId] = accId;
            }
          }
        }
      }
    } catch (_) {}

    _memoryCache[ledgerId] = map;
    return map;
  }
}
