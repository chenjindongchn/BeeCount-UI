import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/ai_chat_providers.dart';
import '../../../utils/format_utils.dart';
import '../../styles/origin_tokens.dart';

/// vivo 蓝心小V 风格全新对话引导与空状态组件 (OriginAiEmptyState)
///
/// 遵循蓝心小V真机视觉：
/// 1. 顶部大字号浅色柔和问候标语；
/// 2. 本月当前账本财务摘要微药丸卡片；
/// 3. 带金色闪烁星标 `✨` 的通透圆角建议卡片（纯白/深灰背景，14dp 圆角，0.5dp 发丝描边）；
/// 4. 点击卡片触发轻触觉反馈并直接填充/发送。
class OriginAiEmptyState extends ConsumerWidget {
  final ValueChanged<String> onSelectPrompt;

  const OriginAiEmptyState({
    super.key,
    required this.onSelectPrompt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(aiChatEmptyLedgerSummaryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12.0),
          // 仿蓝心小V：大字号柔和问候语
          Text(
            '智能记账，找小助手',
            style: TextStyle(
              fontSize: 26.0,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF2C2C30),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            '一句话极速记账、拍照识票、月度财务诊断、多账本智能归属~',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: isDark ? Colors.white54 : const Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 20.0),

          // 本月概览微药丸（若有数据）
          summaryAsync.when(
            data: (summary) {
              if (!summary.hasTransactionData) {
                return const SizedBox.shrink();
              }
              final monthStr = DateFormat('yyyy年M月').format(summary.period);
              return Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F3F7),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE5E6EB),
                    width: OriginTokens.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14.0,
                      color: OriginTokens.textSecondary(context),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        '$monthStr · 已记 ${summary.transactionCount} 笔 · 支出 ¥${formatBalanceFull(summary.expense, "CNY")}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 仿蓝心小V：灵感建议卡片组（带 ✨ 图标与右箭头）
          _buildPromptCard(
            context,
            isDark: isDark,
            title: '刚才买咖啡花了 28 元，微信支付',
            subtitle: '一句话自动提取分类、金额与账户并记账',
            prompt: '刚才买咖啡花了 28 元，微信支付',
          ),
          const SizedBox(height: 12.0),
          _buildPromptCard(
            context,
            isDark: isDark,
            title: '分析一下我这月的餐饮消费结构',
            subtitle: '按分类与金额统计本月生活开销趋势',
            prompt: '分析一下我这月的餐饮消费结构',
          ),
          const SizedBox(height: 12.0),
          _buildPromptCard(
            context,
            isDark: isDark,
            title: '昨天从招行转账 3000 元到微信零钱',
            subtitle: '多账户双向划转与账务对账',
            prompt: '昨天从招行转账 3000 元到微信零钱',
          ),
          const SizedBox(height: 12.0),
          _buildPromptCard(
            context,
            isDark: isDark,
            title: '查询我最近一周的所有大额支出',
            subtitle: '快速筛选关键账目与异常开销',
            prompt: '查询我最近一周的所有大额支出',
          ),

          const SizedBox(height: 40.0),
        ],
      ),
    );
  }

  Widget _buildPromptCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFEAEBED);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14.0),
        onTap: () {
          HapticFeedback.lightImpact();
          onSelectPrompt(prompt);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: borderColor, width: OriginTokens.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                offset: const Offset(0, 2),
                blurRadius: 6.0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 金色四角闪烁星标 ✨
              const Text(
                '✨',
                style: TextStyle(fontSize: 16.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: OriginTokens.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: OriginTokens.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13.0,
                color: OriginTokens.textSecondary(context).withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
