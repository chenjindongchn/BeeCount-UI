import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers.dart';
import '../../../data/db.dart';
import '../../../utils/category_utils.dart';
import '../../../utils/format_money.dart';
import '../../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../styles/origin_tokens.dart';
import '../providers/account_color_display_provider.dart';
import '../utils/account_color_utils.dart';

/// vivo OriginOS 风格交易流水条目组件
///
/// 遵循明细展示设计规范：
/// 1. 左侧：通透彩色分类图标（无死板深色底块）；
/// 2. 中间：分类名称（15.5sp SemiBold）+ 自定义标签（若有）+ 备注（若有，不显示时间）；
/// 3. 右侧：垂直排列，上方加粗金额（支出黑色，收入橙色），下方展示账户信息（支出/收入账户，转账则展示“从A-B”）；
/// 4. 交互：长按条目触发删除确认操作，支持批量模式选择。
class OriginTransactionItem extends ConsumerWidget {
  final Transaction transaction;
  final Category? category;
  final Account? account;
  final Account? toAccount;
  final List<Tag>? tags;
  final bool? hideAmounts;
  final int? transferDirection;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionChanged;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const OriginTransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    this.tags,
    this.hideAmounts,
    this.transferDirection,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionChanged,
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
    final showAccountColor = ref.watch(accountColorDisplayProvider);
    final isTransfer = transaction.type == 'transfer';
    final isExpense = transaction.type == 'expense';
    final isIncome = transaction.type == 'income';

    // 1. 分类显示名称
    String displayName;
    if (isTransfer) {
      displayName = '转账';
    } else {
      displayName = CategoryUtils.getDisplayName(category?.name, context);
      if (displayName.isEmpty) {
        displayName = transaction.note?.trim().isNotEmpty == true
            ? transaction.note!.trim()
            : '日常支出';
      }
    }

    // 2. 自定义标签（若用户为交易打标签则展示，不再 fallback 到账户名）
    String? tagLabel;
    if (tags != null && tags!.isNotEmpty) {
      tagLabel = tags!.first.name;
    }

    // 3. 备注文本（完全删除时间显示，仅在有明确备注且非分类名自身时展示）
    final rawNote = transaction.note?.trim() ?? '';
    final String? noteText =
        (rawNote.isNotEmpty && rawNote != displayName) ? rawNote : null;

    // 4. 账户展示文本（显示在金额下方；转账展示从A-B）
    String accountText = '';
    if (isTransfer) {
      final fromName = account?.name;
      final toName = toAccount?.name;
      if (fromName != null &&
          fromName.isNotEmpty &&
          toName != null &&
          toName.isNotEmpty) {
        accountText = '从$fromName-$toName';
      } else if (fromName != null && fromName.isNotEmpty) {
        accountText = '从$fromName';
      } else if (toName != null && toName.isNotEmpty) {
        accountText = '到$toName';
      }
    } else {
      // 支出或收入账户
      accountText = account?.name ?? '';
    }

    // 5. 金额计算与显示
    final effectiveHideAmounts =
        hideAmounts ?? (ref.watch(hideAmountsProvider) ?? false);
    final amount = transaction.nativeAmount ?? transaction.amount;
    String amountStr;
    Color amountColor;

    if (effectiveHideAmounts) {
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
        // 转账：若在单卡详情中指定了流向，-1 为流出当前账户（支出），1 为流入当前账户（收入）
        if (transferDirection == -1) {
          amountStr = '-${formatMoneyCompact(amount, trimZeros: false)}';
          amountColor = OriginTokens.textPrimary(context);
        } else if (transferDirection == 1) {
          amountStr = '+${formatMoneyCompact(amount, trimZeros: false)}';
          amountColor = const Color(0xFFFF8200);
        } else {
          // 普通通用无流向转账
          amountStr = formatMoneyCompact(amount, trimZeros: false);
          amountColor = OriginTokens.textPrimary(context);
        }
      }
    }

    // 图标与色彩
    final iconColor = _resolveCategoryColor(context, displayName, transaction.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelectionMode ? onSelectionChanged : onTap,
        onLongPress: isSelectionMode
            ? null
            : onLongPress != null
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
              // 0. 批量选择模式复选框
              if (isSelectionMode) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : OriginTokens.divider(context),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],

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

              // 2. 中间信息区 (分类名字 + 自定义标签 + 备注)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：分类名称 + 自定义标签（若有）
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
                    // 第二行：纯备注（已删除时间，仅在有备注时展示）
                    if (noteText != null) ...[
                      const SizedBox(height: 3.0),
                      Text(
                        noteText,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: OriginTokens.textTertiary(context),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12.0),

              // 3. 右侧信息区：金额（上）+ 账户（下）
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.45,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 上层：加粗金额
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
                    // 下层：支出/收入账户或转账从A-B
                    if (accountText.isNotEmpty) ...[
                      const SizedBox(height: 3.0),
                      _buildAccountLabel(
                        context,
                        showAccountColor: showAccountColor,
                        isTransfer: isTransfer,
                        fallbackText: accountText,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountLabel(
    BuildContext context, {
    required bool showAccountColor,
    required bool isTransfer,
    required String fallbackText,
  }) {
    final defaultColor = OriginTokens.textTertiary(context);
    const style = TextStyle(
      fontSize: 11.5,
      height: 1.2,
    );

    if (!showAccountColor) {
      return Text(
        fallbackText,
        style: style.copyWith(color: defaultColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );
    }

    if (isTransfer) {
      final fromName = account?.name;
      final toName = toAccount?.name;
      final hasFrom = fromName != null && fromName.isNotEmpty;
      final hasTo = toName != null && toName.isNotEmpty;

      if (!hasFrom && !hasTo) {
        return Text(
          fallbackText,
          style: style.copyWith(color: defaultColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
        );
      }

      final fromColor = getAccountTypeColor(account?.type);
      final toColor = getAccountTypeColor(toAccount?.type);

      return Text.rich(
        TextSpan(
          children: [
            if (hasFrom) ...[
              TextSpan(text: '从', style: style.copyWith(color: defaultColor)),
              TextSpan(
                text: fromName,
                style: style.copyWith(
                  color: fromColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (hasFrom && hasTo)
              TextSpan(text: ' → ', style: style.copyWith(color: defaultColor)),
            if (hasTo) ...[
              if (!hasFrom)
                TextSpan(text: '到', style: style.copyWith(color: defaultColor)),
              TextSpan(
                text: toName,
                style: style.copyWith(
                  color: toColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
      );
    }

    final accName = account?.name ?? fallbackText;
    final accColor = getAccountTypeColor(account?.type);

    return Text(
      accName,
      style: style.copyWith(
        color: accColor,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
    );
  }
}
