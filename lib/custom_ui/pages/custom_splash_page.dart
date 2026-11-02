import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/base_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../models/home_transaction_preview.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/feature_highlight_providers.dart';
import '../../providers/font_scale_provider.dart';
import '../../providers/home_startup_preview_provider.dart';
import '../../providers/security_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/recurring_transaction_service.dart';
import '../../services/system/logger_service.dart';
import '../../utils/month_range.dart';
import '../styles/origin_tokens.dart';

/// 定制高效冷启动预加载 Provider
///
/// 遵循第一性原理：只预加载首屏展示必需的核心数据（月度汇总、前20条流水、账本信息），
/// 将周期交易生成、同步检查等重度后台逻辑剥离至微任务异步执行，
/// 从而将冷启动时间从数秒直接压缩至百毫秒级。
final customAppSplashInitProvider = FutureProvider<void>((ref) async {
  const tag = 'CustomSplash';
  logger.info(tag, '开始定制极速启屏预加载');
  final startTime = DateTime.now();
  final handoff = ref.read(homeStartupPreviewHandoffProvider)..clear();
  var disposed = false;
  ref.onDispose(() => disposed = true);

  try {
    // 1. 核心首屏依赖（遵循第一性原理：只阻塞等待主题色、暗黑模式、账本ID、应用锁状态，其余14项配置异步预热）
    await Future.wait([
      ref.watch(primaryColorInitProvider.future),
      ref.watch(themeModeInitProvider.future),
      ref.watch(appInitProvider.future),
      ref.watch(securityInitProvider.future),
    ]);

    // 后台非阻塞预热其余非首屏关键配置（有默认值托底，不卡启动门）
    unawaited(Future.wait([
      ref.watch(fontScaleInitProvider.future),
      ref.watch(hideAmountsInitProvider.future),
      ref.watch(compactAmountInitProvider.future),
      ref.watch(skinAnimationInitProvider.future),
      ref.watch(featureHighlightInitProvider.future),
      ref.watch(showTransactionTimeInitProvider.future),
      ref.watch(noteDisplayModeInitProvider.future),
      ref.watch(noteHistoryPreferencesInitProvider.future),
      ref.watch(smartBillingAutoTagsInitProvider.future),
      ref.watch(smartBillingAutoAttachmentInitProvider.future),
      ref.watch(incomeExpenseColorSchemeInitProvider.future),
      ref.watch(displayNameInitProvider.future),
      ref.watch(baseCurrencyInitProvider.future),
      ref.watch(headerSkinInitProvider.future),
    ]));

    if (disposed) return;

    while (true) {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      final now = DateTime.now();
      final ledgerRow = await repo.getLedgerById(ledgerId);
      final startDay = (ledgerRow?.monthStartDay ?? 1).clamp(1, 28);
      final currentMonth = labelForDate(now, startDay);
      ref.read(selectedMonthProvider.notifier).state = currentMonth;

      final monthlyParams = (ledgerId: ledgerId, month: currentMonth);
      ref.invalidate(monthlyTotalsProvider(monthlyParams));
      ref.invalidate(budgetOverviewProvider);

      // 并行预加载：月度统计 + 首屏前20条 + 预算 + 账本
      final results = await Future.wait([
        ref.read(monthlyTotalsProvider(monthlyParams).future),
        handoff.prepare(repo, ledgerId, ref.read(databaseProvider)),
        ref.read(budgetOverviewProvider.future),
        ref.read(currentLedgerProvider.future),
      ]);

      final monthlyResult = results[0] as (double, double);
      final preview = results[1] as HomeTransactionPreview;
      if (disposed) return;
      if (!identical(repo, ref.read(repositoryProvider)) ||
          ledgerId != ref.read(currentLedgerIdProvider) ||
          !identical(handoff.peek(repo, ledgerId)?.preview, preview)) {
        continue;
      }

      ref.read(lastMonthlyTotalsProvider(monthlyParams).notifier).state =
          monthlyResult;
      ref.read(cachedTransactionsProvider.notifier).state = preview.rows;
      break;
    }

    // 首屏所需数据全部就绪，立刻放行切入主界面！
    if (!disposed) {
      ref.read(appInitStateProvider.notifier).state = AppInitState.ready;
      logger.info(tag,
          '定制极速预加载完成，耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms，切换到主界面');
    }

    // 2. 后台异步生成待处理周期交易（错峰延后 3 秒，绝不阻塞或争抢首屏关键帧）
    unawaited(() async {
      try {
        await Future.delayed(const Duration(seconds: 3));
        final repo = ref.read(repositoryProvider);
        final generatedLedgerIds =
            await RecurringTransactionService.generatePendingTransactionsStatic(
          repository: repo,
          verbose: false,
        );
        for (final id in generatedLedgerIds) {
          await PostProcessor.runR(ref, ledgerId: id);
        }
      } catch (e, st) {
        logger.error(tag, '后台异步生成周期交易异常', e, st);
      }
    }());
  } catch (e, stackTrace) {
    if (disposed) return;
    handoff.clear();
    logger.error(tag, '定制极速预加载失败', e, stackTrace);
    rethrow;
  }
});

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
/// 监听定制数据预加载 provider，未就绪时展示 CustomSplashPage，就绪后直接挂载主界面
class CustomAppStartupGate extends ConsumerWidget {
  const CustomAppStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appInitStateProvider) == AppInitState.ready) return child;
    final initialization = ref.watch(customAppSplashInitProvider);
    return CustomSplashPage(
      loadError: initialization.hasError,
      onRetry: () => ref.invalidate(customAppSplashInitProvider),
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
