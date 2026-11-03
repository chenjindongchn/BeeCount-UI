import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import 'package:beecount_ui/beecount_ui.dart' show showBeeToast, BeeTone;

import '../../providers.dart';
import '../../cloud/sync_service.dart';
import '../../cloud/sync/sync_engine.dart';
import '../../cloud/sync/sync_providers.dart' as sync_p;
import '../../pages/cloud/beecount_cloud_sync_page.dart';
import '../../pages/cloud/cloud_sync_page.dart';
import '../styles/origin_tokens.dart';

/// 首页同步状态视觉分类
enum HomeSyncVisualState {
  /// 未开启云同步（隐藏不显示）
  hidden,

  /// 正在同步中（蓝色呼吸脉动）
  syncing,

  /// 已同步 / 正常连接（绿色圆点）
  synced,

  /// 离线 / 户外未连后台（中性灰圆点）
  offline,

  /// 异常 / 鉴权错误（低饱和暖橙圆点）
  error,
}

/// vivo OriginOS 风格首页同步状态小圆点 (OriginSyncDot)
///
/// 遵循第一性原理与极简低调设计：
/// 1. 摆放于顶部大标题账本名称右侧（日常账本 ▾ ●），不干扰原账本切换；
/// 2. 直径 6dp，点击热区 32×32dp，支持触觉反馈；
/// 3. 在外面没有连接后台的环境下，展示中性灰（离线安全存留），绝不误报红橙打扰用户；
/// 4. 正常已同步显示绿色；传输中显示呼吸蓝；鉴权或严重错误显示暖橙；
/// 5. 点击弹出轻量 OriginOS 状态面板，长按直接触发立即同步。
class OriginSyncDot extends ConsumerStatefulWidget {
  const OriginSyncDot({super.key});

  @override
  ConsumerState<OriginSyncDot> createState() => _OriginSyncDotState();
}

class _OriginSyncDotState extends ConsumerState<OriginSyncDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOnline = true;
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.82, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 监听网络连通状态
    _checkInitialConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// 判断错误是否属于网络连接不可达/超时（户外无后台场景）
  bool _isNetworkUnreachableError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception');
  }

  /// 触发一次手动同步
  Future<void> _triggerSync(BuildContext context, {bool showToast = false}) async {
    if (_isManualSyncing) return;
    final ledgerId = ref.read(currentLedgerIdProvider);
    final syncService = ref.read(syncServiceProvider);

    setState(() => _isManualSyncing = true);
    if (showToast) {
      showBeeToast(context, '正在发起同步...');
    }

    try {
      if (syncService is SyncEngine) {
        syncService.triggerAutoSync(reason: 'manual_dot_tap');
      } else {
        ref.read(syncStatusRefreshProvider.notifier).state++;
        if (ledgerId > 0) {
          ref.read(syncStatusRefreshByLedgerProvider(ledgerId).notifier).state++;
        }
      }
      // 等待短暂响应时间以展示脉动
      await Future.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      if (mounted && showToast) {
        showBeeToast(this.context, '同步触发异常: $e', tone: BeeTone.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  void _openCloudSettings(BuildContext context, CloudServiceConfig config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => config.type == CloudBackendType.beecountCloud
            ? const BeeCountCloudSyncPage()
            : const CloudSyncPage(),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context, {
    required HomeSyncVisualState state,
    required CloudServiceConfig config,
    required int unpushedCount,
    required String? lastError,
  }) {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = ref.read(primaryColorProvider);

    String title;
    String description;
    IconData icon;
    Color iconColor;

    switch (state) {
      case HomeSyncVisualState.syncing:
        title = '正在同步中';
        description = '正在与云端交换账本最新数据，请稍候...';
        icon = Icons.sync_rounded;
        iconColor = primaryColor;
        break;
      case HomeSyncVisualState.synced:
        title = '云同步已就绪';
        description = '本地账本已与云端保持最新对齐，所有记录均已同步。';
        icon = Icons.cloud_done_rounded;
        iconColor = const Color(0xFF34C759);
        break;
      case HomeSyncVisualState.offline:
        title = '离线待命中';
        if (unpushedCount > 0) {
          description =
              '当前处于户外或未连接后台状态。\n本地已有 $unpushedCount 笔新记录安全留存，待网络恢复后将自动同步。';
        } else {
          description =
              '当前未连接到云端后台。在户外或无网络环境下，本地记账数据均完整安全，恢复连接后会自动同步。';
        }
        icon = Icons.cloud_off_rounded;
        iconColor = isDark ? const Color(0xFFA0A0A5) : const Color(0xFF8E8E93);
        break;
      case HomeSyncVisualState.error:
        title = '同步需要关注';
        description = lastError != null && lastError.isNotEmpty
            ? '同步遇到问题：$lastError'
            : '同步验证未通过或鉴权失效，请检查云同步账户配置。';
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFFF9500);
        break;
      case HomeSyncVisualState.hidden:
        return;
    }

    final backendName = switch (config.type) {
      CloudBackendType.beecountCloud => 'BeeCount Cloud',
      CloudBackendType.supabase => 'Supabase',
      CloudBackendType.webdav => 'WebDAV',
      CloudBackendType.s3 => 'S3 兼容存储',
      CloudBackendType.icloud => 'iCloud',
      _ => '本地存储',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 顶部把手
                Container(
                  width: 36.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
                const SizedBox(height: 20.0),

                // 状态大图标
                Container(
                  width: 52.0,
                  height: 52.0,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 28.0),
                ),
                const SizedBox(height: 12.0),

                // 标题
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6.0),

                // 服务与账号
                Text(
                  '服务后端：$backendName',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: OriginTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 8.0),

                // 描述
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.0,
                    height: 1.45,
                    color: OriginTokens.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 24.0),

                // 操作按钮组
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22.0),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          _openCloudSettings(context, config);
                        },
                        child: Text(
                          '同步设置',
                          style: TextStyle(
                            color: OriginTokens.textPrimary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          minimumSize: const Size.fromHeight(44.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();
                          _triggerSync(context, showToast: true);
                        },
                        child: const Text(
                          '立即同步',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeConfigAsync = ref.watch(activeCloudConfigProvider);
    final config = activeConfigAsync.valueOrNull;

    // 1. 未配置云同步或纯本地模式：完全隐藏，不占视觉空间
    if (config == null || !config.valid || config.type == CloudBackendType.local) {
      return const SizedBox.shrink();
    }

    final ledgerId = ref.watch(currentLedgerIdProvider);
    final syncStatusAsync = ref.watch(syncStatusProvider(ledgerId));
    final syncStatus = syncStatusAsync.valueOrNull ??
        ref.watch(lastSyncStatusProvider(ledgerId));
    final lastError = ref.watch(lastSyncErrorProvider);
    final unpushedAsync = ref.watch(sync_p.unpushedChangeCountProvider);
    final unpushedCount = unpushedAsync.valueOrNull ?? 0;
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. 状态判定
    HomeSyncVisualState visualState;
    if (_isManualSyncing || (syncStatusAsync.isLoading && syncStatus == null)) {
      visualState = HomeSyncVisualState.syncing;
    } else if (!_isOnline || _isNetworkUnreachableError(lastError) || _isNetworkUnreachableError(syncStatus?.message)) {
      // 离线/户外未连接后台：显示中性灰色
      visualState = HomeSyncVisualState.offline;
    } else if (lastError != null || (syncStatus != null && syncStatus.diff == SyncDiff.error)) {
      // 鉴权或其它异常：显示暖橙色
      visualState = HomeSyncVisualState.error;
    } else {
      // 正常连接且已就绪：显示绿色
      visualState = HomeSyncVisualState.synced;
    }

    // 3. 动效调度
    if (visualState == HomeSyncVisualState.syncing) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 1.0;
      }
    }

    // 4. 颜色映射
    final Color dotColor = switch (visualState) {
      HomeSyncVisualState.synced => const Color(0xFF34C759), // 绿色
      HomeSyncVisualState.syncing => primaryColor, // 蓝色脉动
      HomeSyncVisualState.offline => isDark ? const Color(0xFFA0A0A5) : const Color(0xFF8E8E93), // 中性灰
      HomeSyncVisualState.error => const Color(0xFFFF9500), // 暖橙色
      HomeSyncVisualState.hidden => Colors.transparent,
    };

    return Semantics(
      label: '云同步状态',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showDetailSheet(
          context,
          state: visualState,
          config: config,
          unpushedCount: unpushedCount,
          lastError: lastError ?? syncStatus?.message,
        ),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _triggerSync(context, showToast: true);
        },
        child: SizedBox(
          width: 28.0,
          height: 28.0,
          child: Center(
            child: ScaleTransition(
              scale: visualState == HomeSyncVisualState.syncing
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: visualState == HomeSyncVisualState.syncing
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.38),
                            blurRadius: 4.0,
                            spreadRadius: 1.0,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
