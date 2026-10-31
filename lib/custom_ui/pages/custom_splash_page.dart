import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/base_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/database_providers.dart';
import '../../providers/home_startup_preview_provider.dart';
import '../../providers/ui_state_providers.dart';
import '../styles/origin_tokens.dart';

/// 记账蓝盒定制启动页 (CustomSplashPage)
///
/// 解决冷启动两大核心痛点：
/// 1. 彻底解决旧小蜜蜂图片闪现问题：使用新定制的蓝盒品牌 Logo 与应用名，与系统启动画面保持像素级视觉一致；
/// 2. 彻底消除双重动画重叠与慢启动：剔除原版长达 1.2 秒的强制飞线描边动画与大菊花，仅做极简静默占位与数据预加载，
///    数据一就绪（通常 100~200ms）即刻无缝呈现主页面，体验毫秒级秒开。
class CustomSplashPage extends StatelessWidget {
  const CustomSplashPage({super.key, this.loadError = false, this.onRetry});

  final bool loadError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final l = AppLocalizations.of(context);

    // 亮暗色背景严格对应原生系统启动屏背景（浅色纯白，深色 OriginOS 沉浸黑）
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : const Color(0xFF9CA3AF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 居中品牌呈现：垂直居中偏上，与原生启动图标中心精准贴合
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 品牌 Logo：使用定制的新换图标，带平滑抗锯齿与微圆角
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo2.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(height: 16),
                // 软件名称落款
                Text(
                  OriginAppInfo.appName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),

          // 底部品牌格言落款（仅在未出错时展示）
          if (!loadError)
            Positioned(
              bottom: 28 + MediaQuery.paddingOf(context).bottom,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '极简记账 · 掌控生活',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: subTextColor,
                  ),
                ),
              ),
            ),

          // 异常重试保护（在极少数预加载失败时提示用户，绝不白屏卡死）
          if (loadError)
            Positioned(
              bottom: 24 + MediaQuery.paddingOf(context).bottom,
              left: 32,
              right: 32,
              child: SafeArea(
                child: FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    l.v4RecordingRetry,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 定制应用启动网关 (CustomAppStartupGate)
/// 监听数据预加载 provider，未就绪时展示 CustomSplashPage，就绪后直接挂载主界面
class CustomAppStartupGate extends ConsumerWidget {
  const CustomAppStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appInitStateProvider) == AppInitState.ready) return child;
    final initialization = ref.watch(appSplashInitProvider);
    return CustomSplashPage(
      loadError: initialization.hasError,
      onRetry: () => ref.invalidate(appSplashInitProvider),
    );
  }
}

/// 定制首页启动网关 (CustomHomeStartupGate)
/// 保证首屏交易缓存完全就绪后进入主界面，避免白屏或空数据闪现
class CustomHomeStartupGate extends ConsumerStatefulWidget {
  const CustomHomeStartupGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CustomHomeStartupGate> createState() =>
      _CustomHomeStartupGateState();
}

class _CustomHomeStartupGateState extends ConsumerState<CustomHomeStartupGate> {
  BaseRepository? _repository;
  int? _ledger;
  int _generation = 0;
  bool _ready = false, _entered = false;
  Object? _error;

  void _bind(BaseRepository repository, int ledger) {
    _repository = repository;
    _ledger = ledger;
    _error = null;
    final handoff = ref.read(homeStartupPreviewHandoffProvider);
    _ready = handoff.peek(repository, ledger) != null;
    final generation = ++_generation;
    if (!_ready) _prepare(repository, ledger, generation);
  }

  Future<void> _prepare(
      BaseRepository repository, int ledger, int generation) async {
    try {
      final handoff = ref.read(homeStartupPreviewHandoffProvider);
      while (mounted && generation == _generation) {
        await handoff.prepare(repository, ledger, ref.read(databaseProvider));
        if (!mounted || generation != _generation) return;
        if (handoff.peek(repository, ledger) == null) continue;
        setState(() => _ready = true);
        return;
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_entered) return widget.child;
    final repository = ref.watch(repositoryProvider);
    final ledger = ref.watch(currentLedgerIdProvider);
    if (!identical(repository, _repository) || ledger != _ledger) {
      _bind(repository, ledger);
    }
    if (_ready) {
      _entered = true;
      return widget.child;
    }
    return CustomSplashPage(
      loadError: _error != null,
      onRetry: () => setState(() => _bind(repository, ledger)),
    );
  }
}
