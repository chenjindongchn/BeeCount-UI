import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_bottom_sheet.dart';
import 'origin_switch.dart';

/// 交易高级标记（不计入收支/不计入预算）设置弹窗
class CustomTransactionFlagsSheet extends StatefulWidget {
  const CustomTransactionFlagsSheet({
    super.key,
    required this.initialExcludeFromStats,
    required this.initialExcludeFromBudget,
    required this.kind,
  });

  final bool initialExcludeFromStats;
  final bool initialExcludeFromBudget;
  final String kind;

  static Future<({bool excludeFromStats, bool excludeFromBudget})?> show(
    BuildContext context, {
    required bool excludeFromStats,
    required bool excludeFromBudget,
    required String kind,
  }) {
    return showOriginBottomSheet<({bool excludeFromStats, bool excludeFromBudget})>(
      context,
      builder: (_) => CustomTransactionFlagsSheet(
        initialExcludeFromStats: excludeFromStats,
        initialExcludeFromBudget: excludeFromBudget,
        kind: kind,
      ),
    );
  }

  @override
  State<CustomTransactionFlagsSheet> createState() =>
      _CustomTransactionFlagsSheetState();
}

class _CustomTransactionFlagsSheetState
    extends State<CustomTransactionFlagsSheet> {
  late bool _excludeFromStats;
  late bool _excludeFromBudget;

  @override
  void initState() {
    super.initState();
    _excludeFromStats = widget.initialExcludeFromStats;
    _excludeFromBudget = widget.initialExcludeFromBudget;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = OriginSheetTokens.cardColor(context);
    final isExpense = widget.kind == 'expense';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OriginSheetTokens.cornerRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部小手柄
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 标题栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '记账标记设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop((
                    excludeFromStats: _excludeFromStats,
                    excludeFromBudget: _excludeFromBudget,
                  ));
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: OriginTokens.primary(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. 不计入收支开关卡片
          _buildSwitchItem(
            context,
            title: '不计入收支',
            subtitle: '该笔记录将排除在月度收支总额与统计图表之外（常用于报销垫付、押金等）',
            value: _excludeFromStats,
            onChanged: (val) {
              HapticFeedback.lightImpact();
              setState(() => _excludeFromStats = val);
            },
          ),

          // 2. 不计入预算开关卡片（仅支出显示）
          if (isExpense) ...[
            const SizedBox(height: 10),
            _buildSwitchItem(
              context,
              title: '不计入预算',
              subtitle: '该笔消费不扣减当月可用预算额度',
              value: _excludeFromBudget,
              onChanged: (val) {
                HapticFeedback.lightImpact();
                setState(() => _excludeFromBudget = val);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBg = isDark ? const Color(0xFF262629) : const Color(0xFFF7F8FA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OriginSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
