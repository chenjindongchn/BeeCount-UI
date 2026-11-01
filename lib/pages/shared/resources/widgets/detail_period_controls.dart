import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../custom_ui/widgets/origin_period_picker.dart';

List<BeeSegment<String>> detailPeriodItems(BuildContext context) {
  final l = AppLocalizations.of(context);
  return [
    BeeSegment('month', l.v4DetailMonth),
    BeeSegment('year', l.v4DetailYear),
    BeeSegment('all', l.analyticsAll),
  ];
}

String detailRangeLabel(BuildContext context, String period, DateTime anchor) =>
    switch (period) {
      'all' => AppLocalizations.of(context).v4DetailAllTime,
      'year' => '${anchor.year}',
      _ => MaterialLocalizations.of(context).formatMonthYear(anchor),
    };

Future<({String period, DateTime anchor})?> showResourcePeriodPicker(
    BuildContext context,
    {required String period,
    required DateTime anchor}) =>
    showOriginPeriodPicker(context, period: period, anchor: anchor);
