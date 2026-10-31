import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/main/analytics/bindings/analytics_data.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../utils/category_utils.dart';
import '../../utils/format_money.dart';
import '../pages/custom_category_detail_page.dart';

/// vivo OriginOS 风格洞察分类排行组件 (OriginAnalyticsRanking)
///
/// 点击具体分类进入定制的分类详情页面 (CustomCategoryDetailPage)，
/// 享有 OriginOS 顶栏、双圆点更多菜单及累计金额趋势动态开关能力。
class OriginAnalyticsRanking extends ConsumerStatefulWidget {
  const OriginAnalyticsRanking({
    super.key,
    required this.data,
    required this.scope,
    required this.month,
  });

  final AnalyticsResult data;
  final String scope;
  final DateTime month;

  @override
  ConsumerState<OriginAnalyticsRanking> createState() =>
      _OriginAnalyticsRankingState();
}

class _OriginAnalyticsRankingState
    extends ConsumerState<OriginAnalyticsRanking> {
  final expanded = <String>{};
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        hide = ref.watch(hideAmountsProvider);

    String amount(double n) =>
        hide ? '****' : formatMoneyCompact(n, signed: false);

    BeeRankItem item(
      int? id,
      String name,
      dynamic category,
      double total, [
      List<BeeRankItem> children = const [],
    ]) =>
        BeeRankItem(
          id: '$id',
          label: CategoryUtils.getDisplayName(name, context),
          amount: amount(total),
          fraction: widget.data.total == 0 ? 0 : total / widget.data.total,
          description: hide
              ? '****'
              : '${(widget.data.total == 0 ? 0 : total / widget.data.total * 100).toStringAsFixed(1)}%',
          icon: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: category == null
                  ? BeeLineIcon(
                      'Shapes',
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                  : RecordingCategoryIcon(
                      category: category,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
            ),
          ),
          children: children,
        );

    final list = widget.data.categories
        .map(
          (e) => item(
            e.id,
            e.name,
            e.category,
            e.total,
            e.subCategories
                .where((s) => s.total > 0)
                .map((s) => item(s.id, s.name, s.category, s.total))
                .toList(),
          ),
        )
        .toList();

    void detail(String id) {
      final categoryId = int.tryParse(id);
      if (categoryId == null) return;
      final names = <int?, String>{
        for (final e in widget.data.categories) e.id: e.name,
        for (final e in widget.data.categories)
          for (final s in e.subCategories) s.id: s.name,
      };
      final name = names[categoryId]!;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CustomCategoryDetailPage(
            categoryId: categoryId,
            categoryName: name,
            startDate: widget.scope == 'all' ? null : widget.data.start,
            endDate: widget.scope == 'all' ? null : widget.data.end,
            periodLabel: widget.scope == 'all'
                ? null
                : widget.scope == 'year'
                    ? '${widget.month.year}'
                    : '${widget.month.year}.${widget.month.month.toString().padLeft(2, '0')}',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeeAnalyticsRankingList(
          items: showAll ? list : list.take(4).toList(),
          expanded: expanded,
          onExpand: (id) => setState(() {
            expanded.contains(id) ? expanded.remove(id) : expanded.add(id);
          }),
          onDetail: detail,
        ),
        if (list.length > 4)
          TextButton(
            onPressed: () => setState(() => showAll = !showAll),
            child: Text(
              showAll
                  ? l.v4InsightsCollapseCategories
                  : l.v4InsightsAllCategories(list.length),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
      ],
    );
  }
}
