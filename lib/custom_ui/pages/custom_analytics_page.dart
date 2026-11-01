import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../utils/month_range.dart';
import '../../pages/ai/ai_chat_page.dart';
import '../../pages/transaction/search_page.dart';
import '../../pages/calendar/calendar_page.dart';
import '../widgets/origin_date_picker.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_analytics_content.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_menu.dart';

/// vivo OriginOS 风格数据洞察与统计分析页面 (CustomAnalyticsPage)
///
/// 遵循 `OriginUI/docs/` 规范：
/// 1. 大标题栏（84dp / 22sp SemiBold）；
/// 2. 胶囊分段滑动选择器（36dp 高度，18dp 圆角，滑动药丸动效）；
/// 3. 日间纯白卡片，夜间 #202020 纯深色卡片；
/// 4. 纯 Riverpod 驱动，不修改原有统计计算逻辑。
class CustomAnalyticsPage extends ConsumerStatefulWidget {
  final bool showBack;
  const CustomAnalyticsPage({super.key, this.showBack = false});

  @override
  ConsumerState<CustomAnalyticsPage> createState() => _CustomAnalyticsPageState();
}

class _CustomAnalyticsPageState extends ConsumerState<CustomAnalyticsPage> {
  String _scope = 'month';
  String _type = 'expense';
  Object? _queryKey;
  Future<Map<String, AnalyticsResult>>? _query;

  void _selectType(String value) => setState(() => _type = value);

  DateTime get _latestPeriod =>
      labelForDate(DateTime.now(), ref.read(currentMonthStartDayProvider));

  bool get _canGoNext {
    final selected = ref.read(selectedMonthProvider);
    final latest = _latestPeriod;
    return _scope == 'month'
        ? DateTime(selected.year, selected.month).isBefore(latest)
        : _scope == 'year' && selected.year < latest.year;
  }

  Future<void> _showPeriodPicker() async {
    final selected = ref.read(selectedMonthProvider);
    final latest = _latestPeriod;
    final result = await showOriginDatePicker(
      context,
      initial: selected,
      mode: _scope == 'year' ? OriginDatePickerMode.y : OriginDatePickerMode.ym,
      maxDate: latest,
    );
    if (result != null && mounted) {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(result.year, _scope == 'year' ? 1 : result.month, 1);
    }
  }

  void _movePeriod(int delta) {
    if (_scope == 'all' || (delta > 0 && !_canGoNext)) return;
    final selected = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = _scope == 'year'
        ? DateTime(selected.year + delta, 1)
        : DateTime(selected.year, selected.month + delta);
  }

  void _openAI() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIChatPage()),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void _openCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CalendarPage()),
    );
  }

  Future<void> _runRecalcForeignTx(int count) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l.recalcForeignTxAction,
      message: l.recalcSyncCountHint(count),
      confirmText: l.commonConfirm,
      cancelText: l.commonCancel,
    );
    if (confirmed != true || !mounted) return;
    final repo = ref.read(repositoryProvider);
    final id = ref.read(currentLedgerIdProvider);
    final foreign = await repo.getLedgerForeignCurrencies(id);
    await refreshExchangeRatesFromUi(ref, force: true, extraQuotes: foreign);
    await repo.recomputeForeignTxForLedger(id);
    if (mounted) setState(() => _queryKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repo = ref.watch(repositoryProvider);
    final id = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final sd = ref.watch(currentMonthStartDayProvider);
    final tick = ref.watch(statsRefreshProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    final key = (repo, id, month, _scope, sd, tick, DateUtils.dateOnly(DateTime.now()));
    if (_queryKey != key) {
      _queryKey = key;
      _query = loadAnalyticsViews(
        repo,
        ledgerId: id,
        scope: _scope,
        selMonth: month,
        startDay: sd,
      );
    }

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l10n.tabInsights,
        leading: widget.showBack ? const BackButton() : null,
        actions: [
          // vivo OriginOS 规范：右上角“竖排双圆点”展示更多功能
          OriginMoreButton(
            tooltip: '更多与设置',
            items: [
              OriginMenuItem(
                title: '日历看板',
                icon: const Icon(Icons.calendar_month_outlined),
                onTap: _openCalendar,
              ),
              OriginMenuItem(
                title: l10n.homeSearch,
                icon: const Icon(Icons.search_rounded),
                onTap: _openSearch,
              ),
              OriginMenuItem(
                title: l10n.aiChatTitle,
                icon: Icon(
                  Icons.auto_awesome_rounded,
                  color: primaryColor,
                ),
                onTap: _openAI,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部 OriginOS 胶囊分段滑动选择器 (月度 / 年度 / 全部)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OriginTokens.cardMargin,
              4.0,
              OriginTokens.cardMargin,
              8.0,
            ),
            child: OriginSegmentedControl<String>(
              items: const ['month', 'year', 'all'],
              selectedItem: _scope,
              onSelected: (scope) => setState(() => _scope = scope),
              labelBuilder: (scope) {
                switch (scope) {
                  case 'month':
                    return l10n.analyticsMonth;
                  case 'year':
                    return l10n.analyticsYear;
                  default:
                    return l10n.analyticsAll;
                }
              },
            ),
          ),

          // 核心统计图表与明细内容
          Expanded(
            child: FutureBuilder<Map<String, AnalyticsResult>>(
              key: ValueKey((
                repo,
                id,
                month,
                _scope,
                sd,
                DateUtils.dateOnly(DateTime.now()),
              )),
              future: _query,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return BeeEmptyState(
                    title: l10n.commonError,
                    message: '${snapshot.error}',
                    action: BeeButton(
                      label: l10n.v4RecordingRetry,
                      onPressed: () => setState(() => _queryKey = null),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return OriginAnalyticsContent(
                  data: snapshot.data![_type]!,
                  scope: _scope,
                  type: _type,
                  month: month,
                  onTypeChanged: _selectType,
                  onPeriod: _scope == 'all' ? null : _showPeriodPicker,
                  onRecalculate: _runRecalcForeignTx,
                  onPrevious: _scope == 'all' ? null : () => _movePeriod(-1),
                  onNext: _canGoNext ? () => _movePeriod(1) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
