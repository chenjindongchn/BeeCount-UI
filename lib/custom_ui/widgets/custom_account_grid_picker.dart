import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../utils/account_type_utils.dart';
import '../pages/custom_account_edit_page.dart';

/// 记账页面账户选择网格抽屉组件 (CustomAccountGridPicker)
///
/// 特性：
/// 1. 图标网格排列（每排4个），去除了币种显示，界面简洁聚焦。
/// 2. “不选择账户”常驻第 1 个图标位置（当 [showNoAccountOption] 为 true 时）。
/// 3. 当账户列表为空时，提供优雅的空状态提示与一键“+ 新建账户”快捷通道。
/// 4. 支持深浅主题、选中态主题色光环高亮以及触觉反馈。
class CustomAccountGridPicker extends ConsumerWidget {
  const CustomAccountGridPicker({
    super.key,
    required this.accounts,
    this.currentAccountId,
    this.showNoAccountOption = true,
    this.title = '选择账户',
    this.primaryColor,
    this.ledgerId,
  });

  /// 账户列表
  final List<Account> accounts;

  /// 当前选中的账户 ID（null 表示未选择或不选择账户）
  final int? currentAccountId;

  /// 是否显示“不选择账户”选项
  final bool showNoAccountOption;

  /// 弹窗顶部标题
  final String title;

  /// 主题主色（若未传则从 Riverpod 中获取）
  final Color? primaryColor;

  /// 当前账本 ID（新建账户时关联）
  final int? ledgerId;

  /// 特殊标记值：当用户点击“不选择账户”时返回 -1
  static const int noAccountId = -1;

  /// 弹出账户网格选择对话框
  ///
  /// 返回值：
  /// - `null`: 用户点击外部遮罩或关闭按钮取消选择，保持现状
  /// - `-1` ([noAccountId]): 用户点击“不选择账户”
  /// - `int` (账户真实 ID): 用户选中的账户 ID
  static Future<int?> show(
    BuildContext context, {
    required List<Account> accounts,
    required int? currentAccountId,
    bool showNoAccountOption = true,
    String title = '选择账户',
    Color? primaryColor,
    int? ledgerId,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomAccountGridPicker(
        accounts: accounts,
        currentAccountId: currentAccountId,
        showNoAccountOption: showNoAccountOption,
        title: title,
        primaryColor: primaryColor,
        ledgerId: ledgerId,
      ),
    );
  }

  Future<void> _handleCreateAccount(BuildContext context) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomAccountEditPage(ledgerId: ledgerId ?? 1),
      ),
    );
    if (result != null && context.mounted) {
      if (result is int) {
        // 直接返回新创建的账户 ID
        Navigator.of(context).pop(result);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = primaryColor ?? ref.watch(primaryColorProvider);

    // 项总数：[可选的不选择账户] + 现有账户列表 + 1个末尾的新增账户按钮
    final int baseOffset = showNoAccountOption ? 1 : 0;
    final int totalCount = baseOffset + accounts.length + 1;

    // 屏幕高度限制：最大高度不超过屏幕高度的 65%，少时自适应
    final maxHeight = MediaQuery.of(context).size.height * 0.65;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部优雅把手
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 标题行与操作按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 新建账户轻量胶囊按钮
                      GestureDetector(
                        onTap: () => _handleCreateAccount(context),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: primary),
                              const SizedBox(width: 2),
                              Text(
                                '新建',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 关闭按钮
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),

            // 当没有任何账户且也不显示“不选择账户”（如转账模式且无账户）时展示全幅空状态
            if (accounts.isEmpty && !showNoAccountOption)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '暂无可用账户',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '创建账户后即可进行记账与转账管理',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _handleCreateAccount(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('新建账户'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // 图标网格区域
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 一排显示4个
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    // 1. “不选择账户” 项（常驻第 0 个）
                    final bool isNoAccountItem =
                        showNoAccountOption && index == 0;

                    // 2. 末尾的“+ 新建账户” 项
                    final bool isAddAccountItem = index == totalCount - 1;

                    // 3. 普通账户项
                    final Account? account =
                        (isNoAccountItem || isAddAccountItem)
                            ? null
                            : accounts[index - baseOffset];

                    // 选中状态判断
                    final bool isSelected = isNoAccountItem
                        ? currentAccountId == null
                        : (account != null && currentAccountId == account.id);

                    final String itemName = isNoAccountItem
                        ? '不选择账户'
                        : (isAddAccountItem
                            ? '添加账户'
                            : (account?.name ?? ''));

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (isAddAccountItem) {
                          _handleCreateAccount(context);
                          return;
                        }
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(
                          isNoAccountItem ? noAccountId : account!.id,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 图标容器
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withValues(
                                      alpha: isDark ? 0.25 : 0.15,
                                    )
                                  : (isDark
                                      ? const Color(0xFF28282C)
                                      : const Color(0xFFF4F5F7)),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: primary, width: 2)
                                  : (isAddAccountItem
                                      ? Border.all(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                          width: 1,
                                        )
                                      : null),
                            ),
                            child: Center(
                              child: isNoAccountItem
                                  ? Icon(
                                      Icons.not_interested_rounded,
                                      size: 22,
                                      color: isSelected
                                          ? primary
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF4A4A4F)),
                                    )
                                  : (isAddAccountItem
                                      ? Icon(
                                          Icons.add_rounded,
                                          size: 24,
                                          color: primary,
                                        )
                                      : AccountTypeIcon(
                                          type: account!.type,
                                          size: 24,
                                        )),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 账户名称（不显示币种）
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected || isAddAccountItem
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected || isAddAccountItem
                                  ? primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : const Color(0xFF333336)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
