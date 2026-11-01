import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_date_picker.dart';
import 'origin_segmented_control.dart';

/// vivo OriginOS 风格资源统计周期选择抽屉 (OriginPeriodPicker)
///
/// 专为统计分析、分类详情、账户详情设计：
/// 1. 顶部提供【按月 / 按年 / 全部时间】OriginOS 胶囊滑动分段指示器；
/// 2. 当选中“按月”时，展示年月滚轮（ym）；
/// 3. 当选中“按年”时，展示年份滚轮（y）；
/// 4. 当选中“全部时间”时，居中展示优雅状态；
/// 5. 返回格式与原版完全一致：`({String period, DateTime anchor})?`。
Future<({String period, DateTime anchor})?> showOriginPeriodPicker(
  BuildContext context, {
  required String period,
  required DateTime anchor,
  String? title,
  DateTime? minDate,
  DateTime? maxDate,
}) {
  final l = AppLocalizations.of(context);
  final sheetTitle = title ?? l.homeSelectDate;

  var draftPeriod = ['month', 'year', 'all'].contains(period) ? period : 'month';
  var draftAnchor = anchor;

  return showOriginBottomSheet<({String period, DateTime anchor})>(
    context,
    builder: (ctx) {
      final primaryColor = Theme.of(ctx).colorScheme.primary;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部标题
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      sheetTitle,
                      style: TextStyle(
                        fontSize: OriginSheetTokens.titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: OriginTokens.textPrimary(ctx),
                      ),
                    ),
                  ),
                ),

                // 周期分段切换器 (按月 / 按年 / 全部时间)
                OriginSegmentedControl<String>(
                  items: const ['month', 'year', 'all'],
                  selectedItem: draftPeriod,
                  labelBuilder: (item) => switch (item) {
                    'month' => l.v4DetailMonth,
                    'year' => l.v4DetailYear,
                    'all' => l.analyticsAll,
                    _ => item,
                  },
                  onSelected: (newPeriod) {
                    setSheetState(() => draftPeriod = newPeriod);
                  },
                ),

                const SizedBox(height: 16),

                // 内容区：按月滚轮 / 按年滚轮 / 全部时间文案
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: draftPeriod == 'all'
                      ? SizedBox(
                          key: const ValueKey('period_all'),
                          height: 216.0,
                          child: Center(
                            child: Text(
                              l.v4DetailAllTime,
                              style: TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: OriginTokens.textSecondary(ctx),
                              ),
                            ),
                          ),
                        )
                      : OriginDatePicker(
                          key: ValueKey('period_picker_$draftPeriod'),
                          initialDate: draftAnchor,
                          mode: draftPeriod == 'month'
                              ? OriginDatePickerMode.ym
                              : OriginDatePickerMode.y,
                          minDate: minDate,
                          maxDate: maxDate,
                          onChanged: (newDate) {
                            draftAnchor = newDate;
                          },
                        ),
                ),

                const SizedBox(height: 20),

                // 底部双胶囊操作区
                SizedBox(
                  height: OriginTokens.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      final resultDate = draftPeriod == 'year'
                          ? DateTime(draftAnchor.year)
                          : (draftPeriod == 'month'
                              ? DateTime(draftAnchor.year, draftAnchor.month)
                              : draftAnchor);
                      Navigator.of(ctx).pop((period: draftPeriod, anchor: resultDate));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    child: Text(
                      l.commonConfirm,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  height: OriginTokens.buttonHeight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    style: TextButton.styleFrom(
                      backgroundColor: OriginSheetTokens.cancelBackground(ctx),
                      foregroundColor: OriginTokens.textSecondary(ctx),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OriginTokens.buttonRadius),
                      ),
                    ),
                    child: Text(
                      l.commonCancel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 12),
              ],
            ),
          );
        },
      );
    },
  );
}
