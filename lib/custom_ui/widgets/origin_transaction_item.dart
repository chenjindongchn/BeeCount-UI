import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/db.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/format_money.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格交易流水条目组件
///
/// 严格依据设计规范及 UI 参考还原：
/// 1. 左侧通透彩色分类图标（无死板深色底块）；
/// 2. 第一行：加粗分类名称（15.5sp SemiBold）+ 圆角浅灰细框标签（10.5sp 账户/标签）；
/// 3. 第二行：时间与备注优雅混排（09:56 | 淘宝闪购，12.5sp 次级灰色）；
/// 4. 右侧金额：支出黑色加粗（-22.54），收入橙色加粗（+0.01）；
/// 5. 长按条目触发删除确认操作。
class OriginTransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final List<Tag>? tags;
  final bool hideAmounts;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const OriginTransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    this.tags,
    this.hideAmounts = false,
    this.onTap,
    this.onLongPress,
  });

  /// 依据分类或关键字提供充满呼吸感的纯净色彩
  Color _resolveCategoryColor(BuildContext context, String catName, String kind) {
    if (kind == 'transfer') {
      return const Color(0xFF1E88E5); // 转账蓝
    }
    if (catName.contains('餐') || catName.contains('食') || catName.contains('饮') || catName.contains('饭')) {
      return const Color(0xFFFF9100); // 暖橙色
    }
    if (catName.contains('车') || catName.contains('行') || catName.contains('交通') || catName.contains('打车') || catName.contains('铁')) {
      return const Color(0xFF2979FF); // 交通蓝
    }
    if (catName.contains('购') || catName.contains('买') || catName.contains('超市') || catName.contains('日用')) {
      return const Color(0xFFFF5252); // 购物红
    }
    if (catName.contains('玩') || catName.contains('乐') || catName.contains('影') || catName.contains('游')) {
      return const Color(0xFF7C4DFF); // 娱乐紫
    }
    if (catName.contains('医') || catName.contains('药') || catName.contains('病')) {
      return const Color(0xFF00BFA5); // 医疗青绿
    }
    if (catName.contains('工') || catName.contains('薪') || catName.contains('奖') || kind == 'income') {
      return const Color(0xFFFF8200); // 收入橙
    }
    // 默认根据名称哈希保持稳定且和谐的色相
    final colors = [
      const Color(0xFF2979FF),
      const Color(0xFFFF9100),
      const Color(0xFF00BFA5),
      const Color(0xFF7C4DFF),
      const Color(0xFFFF5252),
      const Color(0xFF3F51B5),
    ];
    return colors[catName.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = transaction.type == 'transfer';
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';

    // 1. 分类显示名称
    String displayName;
    if (isTransfer) {
      displayName = isIncome ? '收转账' : '转账';
    } else {
      displayName = CategoryUtils.getDisplayName(category?.name, context);
      if (displayName.isEmpty) {
        displayName = transaction.note?.trim().isNotEmpty == true
            ? transaction.note!.trim()
            : '日常支出';
      }
    }

    // 2. 标签文本（优先使用自定义标签，如支付宝自动记账/微信自动记账；无标签时使用账户名）
    String? tagLabel;
    if (tags != null && tags!.isNotEmpty) {
      tagLabel = tags!.first.name;
    } else if (account?.name != null && account!.name.isNotEmpty) {
      tagLabel = account!.name;
    }

    // 3. 时间与备注文本 (09:56 | 淘宝闪购)
    final dt = transaction.happenedAt.toLocal();
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final note = transaction.note?.trim() ?? '';

    String subtitleText;
    if (note.isNotEmpty) {
      subtitleText = '$timeStr | $note';
    } else {
      subtitleText = timeStr;
    }

    // 4. 金额计算与显示
    final amount = transaction.nativeAmount ?? transaction.amount;
    String amountStr;
    Color amountColor;

    if (hideAmounts) {
      amountStr = '****';
      amountColor = OriginTokens.textPrimary(context);
    } else {
      if (isExpense) {
        amountStr = '-${formatMoneyCompact(amount, trimZeros: false)}';
        amountColor = OriginTokens.textPrimary(context);
      } else if (isIncome) {
        amountStr = '+${formatMoneyCompact(amount, trimZeros: false)}';
        amountColor = const Color(0xFFFF8200); // 暖橙色
      } else {
        // 转账
        amountStr = formatMoneyCompact(amount, trimZeros: false);
        amountColor = OriginTokens.textPrimary(context);
      }
    }

    // 图标与色彩
    final iconColor = _resolveCategoryColor(context, displayName, transaction.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress != null
            ? () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. 左侧图标 (通透无底色，居中放置)
              SizedBox(
                width: 32.0,
                height: 32.0,
                child: Center(
                  child: category != null
                      ? RecordingCategoryIcon(
                          category: category!,
                          size: 24.0,
                          color: iconColor,
                        )
                      : isTransfer
                          ? Icon(
                              Icons.sync_alt_rounded,
                              size: 24.0,
                              color: iconColor,
                            )
                          : Icon(
                              Icons.category_outlined,
                              size: 24.0,
                              color: iconColor,
                            ),
                ),
              ),
              const SizedBox(width: 12.0),

              // 2. 中间信息区 (两行结构)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：分类名称 + 圆角标签
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: OriginTokens.textPrimary(context),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tagLabel != null && tagLabel.isNotEmpty) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: OriginTokens.cardSecondary(context),
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(
                                color: OriginTokens.divider(context),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              tagLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: OriginTokens.textTertiary(context),
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4.0),

                    // 第二行：时间与备注 (09:56 | 淘宝闪购)
                    Text(
                      subtitleText,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: OriginTokens.textTertiary(context),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12.0),

              // 3. 右侧金额 (加粗等宽，清晰直观)
              Text(
                amountStr,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
