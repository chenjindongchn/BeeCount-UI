import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/currency/exchange_rate_page.dart';
import '../pages/custom_ledgers_page.dart';
import '../../providers.dart';
import '../../utils/account_type_utils.dart';
import '../styles/origin_tokens.dart';
import 'origin_divider.dart';
import 'origin_switch.dart';

/// vivo OriginOS 风格确认弹窗体系 (OriginDialog)
///
/// 遵循蓝河工具箱 `OriginUI/docs/22-update-dialog.md` 与 vivo vigour 原厂规范：
/// 1. 【几何真值】
///    - 卡片标准宽度 304.0dp，最大内容滚动限制 360.0dp，保证无论字数多少按钮均不被挤出；
///    - 大圆角 30.0dp（vivo vigour 标准 DialogCornerRadius = 30dp）；
///    - 双胶囊按钮：高度 46.0dp，圆角 23.0dp。
///
/// 2. 【材质与纯净中性底色】
///    - 日间纯白 #FFFFFF，夜间纯黑/纯深灰 #1E1E1E（全不透明实底，避免杂色遮罩）；
///    - 遮罩蒙层 (Scrim)：日间 30% alpha (#4D000000)，夜间 60% alpha (#99000000)。
///
/// 3. 【排版与交互手感】
///    - 标题 16sp SemiBold，居中排版；
///    - 正文 14sp Regular，行高 1.5，舒适阅读；
///    - 确认胶囊实心填充当前主题强调色（自动读取 Theme.of(context).colorScheme.primary）；
///    - 次要/取消胶囊中性底色（日间 #F4F4F6，夜间 #2A2A2A）；
///    - 入场动效遵循 Cubic(0.28, 0.85, 0.36, 1.0) 贝塞尔曲线，伴随轻触震动反馈。
class OriginDialog extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? icon;
  final String? message;
  final Widget? content;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final String? cancelText;
  final VoidCallback? onCancel;
  final String? destructiveText;
  final VoidCallback? onDestructive;
  final List<Widget>? customActions;
  final bool stackActions;
  final bool isDanger;
  final double maxWidth;
  final Alignment alignment;
  final TextAlign textAlign;

  const OriginDialog({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.message,
    this.content,
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
    this.destructiveText,
    this.onDestructive,
    this.customActions,
    this.stackActions = true,
    this.isDanger = false,
    this.maxWidth = OriginTokens.dialogWidth,
    this.alignment = Alignment.bottomCenter,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = OriginTokens.primary(context);
    final confirmBgColor = isDanger ? OriginTokens.expenseRed : primaryColor;
    final bottomInset = alignment == Alignment.bottomCenter
        ? MediaQuery.of(context).padding.bottom + 28.0
        : 24.0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          left: 28.0,
          right: 28.0,
          bottom: bottomInset,
          top: 24.0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: 260.0,
          ),
          child: Material(
            color: OriginTokens.dialogBackground(context),
            borderRadius: BorderRadius.circular(OriginTokens.dialogRadius),
            elevation: 12.0,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OriginTokens.dialogContentPadding,
                vertical: 24.0,
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 顶部可选图标
                if (icon != null) ...[
                  Center(
                    child: SizedBox(
                      width: 44.0,
                      height: 44.0,
                      child: Center(child: icon!),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],

                // 2. 标题（16sp SemiBold）
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textPrimary(context),
                      letterSpacing: -0.2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                ],

                // 3. 可选副标题（12sp Regular 弱化灰）
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  Text(
                    subtitle!,
                    textAlign: textAlign,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: OriginTokens.summaryText(context),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],

                // 4. 正文内容区（最大高度约束 360dp，长文本可平滑滚动）
                if (content != null || (message != null && message!.isNotEmpty)) ...[
                  const SizedBox(height: 6.0),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: OriginTokens.dialogMaxContentHeight,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: content ??
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              message!,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 14.0,
                                height: 1.5,
                                color: OriginTokens.textSecondary(context),
                              ),
                            ),
                          ),
                    ),
                  ),
                ],

                const SizedBox(height: OriginTokens.dialogMessageButtonGap),

                // 5. 操作按钮组
                if (customActions != null && customActions!.isNotEmpty)
                  ...customActions!
                else
                  _buildDefaultActions(context, confirmBgColor),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDefaultActions(BuildContext context, Color confirmBgColor) {
    final hasCancel = cancelText != null && cancelText!.isNotEmpty;
    final hasConfirm = confirmText != null && confirmText!.isNotEmpty;
    final hasDestructive =
        destructiveText != null && destructiveText!.isNotEmpty;

    if (!hasCancel && !hasConfirm && !hasDestructive) {
      return const SizedBox.shrink();
    }

    final effectiveConfirmBg = isDanger
        ? OriginTokens.dialogButtonSecondary(context)
        : confirmBgColor;
    final effectiveConfirmTextColor =
        isDanger ? OriginTokens.expenseRed : Colors.white;

    // 1. 确认胶囊按钮（主强调色实心，居顶部）
    final confirmBtn = hasConfirm
        ? _OriginDialogCapsuleButton(
            text: confirmText!,
            backgroundColor: effectiveConfirmBg,
            textColor: effectiveConfirmTextColor,
            isPrimary: true,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (onConfirm != null) {
                onConfirm!();
              } else {
                Navigator.of(context).pop(true);
              }
            },
          )
        : null;

    // 2. 破坏性操作胶囊按钮（如删除预算，中性底 + 警示红字，居中间）
    final destructiveBtn = hasDestructive
        ? _OriginDialogCapsuleButton(
            text: destructiveText!,
            backgroundColor: OriginTokens.dialogButtonSecondary(context),
            textColor: OriginTokens.expenseRed,
            isPrimary: false,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (onDestructive != null) {
                onDestructive!();
              } else {
                Navigator.of(context).pop(false);
              }
            },
          )
        : null;

    // 3. 取消胶囊按钮（中性底，居最底）
    final cancelBtn = hasCancel
        ? _OriginDialogCapsuleButton(
            text: cancelText!,
            backgroundColor: OriginTokens.dialogButtonSecondary(context),
            textColor: OriginTokens.textPrimary(context),
            isPrimary: false,
            onPressed: () {
              HapticFeedback.lightImpact();
              if (onCancel != null) {
                onCancel!();
              } else {
                Navigator.of(context).pop(false);
              }
            },
          )
        : null;

    final buttons = <Widget>[
      if (confirmBtn != null) confirmBtn,
      if (destructiveBtn != null) destructiveBtn,
      if (cancelBtn != null) cancelBtn,
    ];

    // 纵向堆叠（OriginOS 规范标准形态：每个胶囊按钮占满一行，高 46dp，圆角 23dp，间距 12dp）
    if (buttons.length > 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 12.0),
            buttons[i],
          ],
        ],
      );
    }

    return buttons.isNotEmpty ? buttons.first : const SizedBox.shrink();
  }
}

/// OriginUI 对话框大胶囊按钮 (高度 46dp, 圆角 23dp)
class OriginDialogCapsuleButton extends StatefulWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;
  final bool isPrimary;
  final VoidCallback onPressed;

  const OriginDialogCapsuleButton({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<OriginDialogCapsuleButton> createState() =>
      _OriginDialogCapsuleButtonState();
}

typedef _OriginDialogCapsuleButton = OriginDialogCapsuleButton;

class _OriginDialogCapsuleButtonState extends State<OriginDialogCapsuleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          height: OriginTokens.dialogButtonHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(OriginTokens.dialogButtonRadius),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: widget.isPrimary ? FontWeight.w600 : FontWeight.w500,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 便捷调起全局 Origin 弹窗的顶层函数
// =============================================================================

/// 调起 OriginOS 风格确认弹窗
Future<bool?> showOriginConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? confirmText,
  String? cancelText,
  bool isDanger = false,
  bool stackActions = true,
  bool barrierDismissible = true,
  Widget? icon,
  TextAlign textAlign = TextAlign.start,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: OriginTokens.dialogScrim(context),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondaryAnim) {
      return OriginDialog(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText ?? '确定',
        cancelText: cancelText ?? '取消',
        isDanger: isDanger,
        stackActions: stackActions,
        icon: icon,
        textAlign: textAlign,
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: OriginTokens.enterCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.28),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 调起 OriginOS 风格单按钮提示弹窗
Future<void> showOriginAlertDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String? okText,
  bool barrierDismissible = true,
  Widget? icon,
  TextAlign textAlign = TextAlign.start,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: OriginTokens.dialogScrim(context),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondaryAnim) {
      return OriginDialog(
        title: title,
        message: message,
        content: content,
        confirmText: okText ?? '我知道了',
        icon: icon,
        textAlign: textAlign,
      );
    },
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: OriginTokens.enterCurve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.28),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 调起自定义内容的 OriginOS 弹窗宿主
Future<T?> showOriginCustomDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: OriginTokens.dialogScrim(context),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim, secondaryAnim) => child,
    transitionBuilder: (ctx, anim, secondaryAnim, c) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: OriginTokens.enterCurve,
        reverseCurve: OriginTokens.exitCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.28),
            end: Offset.zero,
          ).animate(curved),
          child: c,
        ),
      );
    },
  );
}

// =============================================================================
// OriginOS 单选控件与单选弹窗体系 (OriginRadioButton & OriginChoiceDialog)
// 遵循蓝河工具箱 `OriginUI/docs/06-checkbox-and-radio.md` 与 `17-dropdown-menu-and-list-popup.md`
// =============================================================================

/// vivo OriginOS 风格单选按钮控件 (OriginRadioButton)
///
/// 遵循 `OriginUI/docs/06-checkbox-and-radio.md`：
/// 1. 外正圆直径 18.0dp，描边线宽 2.0dp；
/// 2. 选中时中心实心同心圆直径 9.5dp（平滑缩放动效）；
/// 3. 选中态颜色与系统/应用动态主题色（primaryColor）联动。
class OriginRadioButton extends StatelessWidget {
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const OriginRadioButton({
    super.key,
    required this.selected,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final themePrimary = activeColor ?? OriginTokens.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBorderColor = isDark ? const Color(0xFF555555) : const Color(0xFFD0D0D0);

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!selected) : null,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 18.0,
          height: 18.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? themePrimary : unselectedBorderColor,
              width: 2.0,
            ),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              width: selected ? 9.5 : 0.0,
              height: selected ? 9.5 : 0.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? themePrimary : Colors.transparent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// vivo OriginOS 单选选项数据结构
class OriginChoiceOption<T> {
  final T value;
  final String title;
  final String? subtitle;
  final IconData? icon;

  const OriginChoiceOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.icon,
  });
}

/// 弹出 OriginOS 规范的单选列表对话框（用于个性化外观模式、主题色等单选）
///
/// 遵循 `OriginUI/docs/17-dropdown-menu-and-list-popup.md` 与 `06-checkbox-and-radio.md`
Future<T?> showOriginChoiceDialog<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<OriginChoiceOption<T>> options,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final primaryColor = OriginTokens.primary(context);

  return showOriginCustomDialog<T>(
    context,
    child: OriginDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0)
              OriginDivider(
                startIndent: options[i].icon != null ? 48.0 : 12.0,
                endIndent: 12.0,
              ),
            _OriginChoiceRow<T>(
              option: options[i],
              isSelected: options[i].value == selected,
              primaryColor: primaryColor,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop(options[i].value);
              },
            ),
          ],
        ],
      ),
      cancelText: '取消',
      onCancel: () => Navigator.of(context).pop(null),
    ),
  );
}

class _OriginChoiceRow<T> extends StatefulWidget {
  final OriginChoiceOption<T> option;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OriginChoiceRow({
    required this.option,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_OriginChoiceRow<T>> createState() => _OriginChoiceRowState<T>();
}

class _OriginChoiceRowState<T> extends State<_OriginChoiceRow<T>> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pressedBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: _isPressed ? pressedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            if (widget.option.icon != null) ...[
              Icon(
                widget.option.icon,
                size: 20.0,
                color: widget.isSelected
                    ? widget.primaryColor
                    : OriginTokens.textSecondary(context),
              ),
              const SizedBox(width: 12.0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.option.title,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: widget.isSelected
                          ? widget.primaryColor
                          : OriginTokens.textPrimary(context),
                    ),
                  ),
                  if (widget.option.subtitle != null &&
                      widget.option.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      widget.option.subtitle!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            OriginRadioButton(
              selected: widget.isSelected,
              activeColor: widget.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// OriginOS 账户偏好设置对话框与账户选择对话框
// =============================================================================

/// 弹出 OriginOS 风格的「账户偏好设置」对话框
Future<void> showOriginAccountPreferencesDialog(BuildContext context, [WidgetRef? ref]) {
  FocusManager.instance.primaryFocus?.unfocus();

  return showOriginCustomDialog<void>(
    context,
    child: _OriginAccountPreferencesDialog(parentContext: context),
  );
}

class _OriginAccountPreferencesDialog extends ConsumerWidget {
  final BuildContext parentContext;

  const _OriginAccountPreferencesDialog({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);

    final allAccounts = (ref.watch(allAccountsStreamProvider).valueOrNull ?? const <db.Account>[])
        .where((a) => !a.hidden)
        .toList();
    final defaultExpenseId = ref.watch(defaultExpenseAccountIdProvider).valueOrNull;
    final defaultIncomeId = ref.watch(defaultIncomeAccountIdProvider).valueOrNull;
    final hasMultipleCurrencies = (ref.watch(usedCurrenciesProvider).valueOrNull?.length ?? 0) >= 2;
    final featureEnabled = ref.watch(accountFeatureEnabledProvider).valueOrNull ?? false;

    String accountName(int? id) {
      if (id == null) return '不设默认';
      final acc = allAccounts.where((a) => a.id == id).firstOrNull;
      return acc?.name ?? '不设默认';
    }

    return OriginDialog(
      title: '账户偏好设置',
      content: Container(
        decoration: BoxDecoration(
          color: OriginTokens.cardSecondary(context),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 启用账户资产功能开关 (OriginSwitch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 20.0,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: Text(
                      l10n.accountsEnableFeature,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  OriginSwitch(
                    value: featureEnabled,
                    onChanged: (val) async {
                      await ref.read(accountFeatureSetterProvider).setEnabled(val);
                      ref.invalidate(accountFeatureEnabledProvider);
                    },
                  ),
                ],
              ),
            ),
            const OriginDivider(startIndent: 44.0, endIndent: 14.0),

            // 2. 默认支出账户
            _OriginDialogSettingRow(
              icon: Icons.arrow_upward_rounded,
              iconColor: OriginTokens.expenseRed,
              title: '默认支出账户',
              value: accountName(defaultExpenseId),
              onTap: () {
                showOriginAccountPickerDialog(
                  context: context,
                  ref: ref,
                  title: '选择默认支出账户',
                  accounts: allAccounts,
                  currentId: defaultExpenseId,
                  isIncome: false,
                );
              },
            ),
            const OriginDivider(startIndent: 44.0, endIndent: 14.0),

            // 3. 默认收入账户
            _OriginDialogSettingRow(
              icon: Icons.arrow_downward_rounded,
              iconColor: OriginTokens.incomeGreen,
              title: '默认收入账户',
              value: accountName(defaultIncomeId),
              onTap: () {
                showOriginAccountPickerDialog(
                  context: context,
                  ref: ref,
                  title: '选择默认收入账户',
                  accounts: allAccounts,
                  currentId: defaultIncomeId,
                  isIncome: true,
                );
              },
            ),

            // 4. 多币种汇率管理
            if (hasMultipleCurrencies) ...[
              const OriginDivider(startIndent: 44.0, endIndent: 14.0),
              _OriginDialogSettingRow(
                icon: Icons.currency_exchange_rounded,
                iconColor: primaryColor,
                title: l10n.exchangeRatePageTitle,
                value: '管理',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(parentContext).push(
                    MaterialPageRoute(builder: (_) => const ExchangeRatePage()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
      confirmText: '完成',
      onConfirm: () => Navigator.of(context).pop(),
    );
  }
}

class _OriginDialogSettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OriginDialogSettingRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 20.0, color: iconColor),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: OriginTokens.textPrimary(context),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: OriginTokens.textSecondary(context),
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.chevron_right_rounded,
              size: 18.0,
              color: OriginTokens.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出 OriginOS 规范的账户选择器单选对话框
Future<void> showOriginAccountPickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required List<db.Account> accounts,
  required int? currentId,
  required bool isIncome,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final primaryColor = OriginTokens.primary(context);

  return showOriginCustomDialog<void>(
    context,
    child: OriginDialog(
      title: title,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 340.0),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 不设默认项
              _OriginAccountPickerTile(
                icon: Icons.not_interested_rounded,
                title: '不设默认',
                subtitle: '记账时需手动选择或使用上次选择',
                isSelected: currentId == null,
                primaryColor: primaryColor,
                onTap: () async {
                  final setter = ref.read(defaultAccountSetterProvider);
                  if (isIncome) {
                    await setter.setDefaultIncomeAccountId(null);
                    ref.invalidate(defaultIncomeAccountIdProvider);
                  } else {
                    await setter.setDefaultExpenseAccountId(null);
                    ref.invalidate(defaultExpenseAccountIdProvider);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),

              // 各账户项
              for (final acc in accounts) ...[
                const OriginDivider(
                  startIndent: 48.0,
                  endIndent: 12.0,
                ),
                _OriginAccountPickerTile(
                  icon: getIconForAccountType(acc.type),
                  title: acc.name,
                  subtitle: '${acc.currency} · ${getAccountTypeLabel(context, acc.type)}',
                  isSelected: currentId == acc.id,
                  primaryColor: primaryColor,
                  onTap: () async {
                    final setter = ref.read(defaultAccountSetterProvider);
                    if (isIncome) {
                      await setter.setDefaultIncomeAccountId(acc.id);
                      ref.invalidate(defaultIncomeAccountIdProvider);
                    } else {
                      await setter.setDefaultExpenseAccountId(acc.id);
                      ref.invalidate(defaultExpenseAccountIdProvider);
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      cancelText: '取消',
      onCancel: () => Navigator.of(context).pop(),
    ),
  );
}

class _OriginAccountPickerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OriginAccountPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
        child: Row(
          children: [
            Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18.0,
                  color: isSelected ? primaryColor : OriginTokens.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? primaryColor : OriginTokens.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: OriginTokens.textTertiary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            OriginRadioButton(
              selected: isSelected,
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// vivo OriginOS 贴底确认卡体系 (OriginConfirmCard & showOriginConfirmCard)
// 对标蓝河工具箱 `AppOriginConfirmCard` / `OriginConfirmDialog`
// =============================================================================

/// vivo OriginOS 风格贴底确认卡 (OriginConfirmCard)
///
/// 对标蓝河工具箱 `AppOriginConfirmCard` / `OriginConfirmDialog`：
/// 1. 贴近屏幕底端居中悬浮（Alignment.bottomCenter）；
/// 2. 宽度限制 304dp（OriginTokens.dialogWidth），大圆角 30dp；
/// 3. 自底端滑升入场（SlideUp），伴随轻微阻尼弹簧效果与 0.30 深度遮罩；
/// 4. 竖排大胶囊操作按钮（主操作在上、次操作在下，高度 46dp，圆角 23dp）；
/// 5. 内容区域高度约束并平滑滚动（默认最大 340dp）。
class OriginConfirmCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? content;
  final List<Widget>? actions;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final double maxWidth;
  final double maxHeight;
  final TextAlign textAlign;

  const OriginConfirmCard({
    super.key,
    this.title,
    this.subtitle,
    this.content,
    this.actions,
    this.confirmText,
    this.onConfirm,
    this.secondaryText,
    this.onSecondary,
    this.maxWidth = OriginTokens.dialogWidth,
    this.maxHeight = 340.0,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final primaryColor = OriginTokens.primary(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: OriginTokens.dialogMargin,
          right: OriginTokens.dialogMargin,
          bottom: OriginTokens.dialogMargin + bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: 260.0,
          ),
          child: Material(
            color: OriginTokens.dialogBackground(context),
            borderRadius: BorderRadius.circular(OriginTokens.dialogRadius),
            elevation: 12.0,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OriginTokens.dialogContentPadding,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 标题（16sp SemiBold）
                  if (title != null && title!.isNotEmpty) ...[
                    Text(
                      title!,
                      textAlign: textAlign,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: OriginTokens.textPrimary(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                  ],

                  // 2. 可选副标题（12sp Regular 弱化灰）
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    Text(
                      subtitle!,
                      textAlign: textAlign,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: OriginTokens.summaryText(context),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],

                  // 3. 正文内容区（最大高度约束，长列表/长文本平滑滚动）
                  if (content != null) ...[
                    const SizedBox(height: 4.0),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: content!,
                      ),
                    ),
                  ],

                  const SizedBox(height: OriginTokens.dialogMessageButtonGap),

                  // 4. 竖排胶囊操作按钮区（主操作在上、次操作在下）
                  if (actions != null && actions!.isNotEmpty)
                    ...actions!
                  else ...[
                    if (confirmText != null && confirmText!.isNotEmpty)
                      _OriginDialogCapsuleButton(
                        text: confirmText!,
                        backgroundColor: primaryColor,
                        textColor: Colors.white,
                        isPrimary: true,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (onConfirm != null) {
                            onConfirm!();
                          } else {
                            Navigator.of(context).pop(true);
                          }
                        },
                      ),
                    if (confirmText != null && secondaryText != null)
                      const SizedBox(height: 10.0),
                    if (secondaryText != null && secondaryText!.isNotEmpty)
                      _OriginDialogCapsuleButton(
                        text: secondaryText!,
                        backgroundColor: OriginTokens.dialogButtonSecondary(context),
                        textColor: OriginTokens.textPrimary(context),
                        isPrimary: false,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (onSecondary != null) {
                            onSecondary!();
                          } else {
                            Navigator.of(context).pop(false);
                          }
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 调起贴底 OriginOS 确认卡弹窗
Future<T?> showOriginConfirmCard<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: OriginTokens.dialogScrim(context),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondaryAnim) => child,
    transitionBuilder: (ctx, anim, secondaryAnim, c) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.28, 0.85, 0.36, 1.0),
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: anim,
          curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.35),
            end: Offset.zero,
          ).animate(curved),
          child: c,
        ),
      );
    },
  );
}

// =============================================================================
// 选择账本确认卡 (showOriginLedgerPickerDialog)
// =============================================================================

/// 调起 OriginOS 风格的「选择账本确认卡」
///
/// 对标蓝河工具箱全局高刷与系统设置确认卡形态：
/// 1. 贴底滑升入场，304dp 限制宽度与 30dp 大圆角；
/// 2. 账本单选列表带 OriginRadioButton 动效与触觉反馈；
/// 3. 底部竖排实心胶囊（主按钮“确认切换”，次按钮“管理账本”，以及“取消”）。
Future<void> showOriginLedgerPickerDialog(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();

  return showOriginConfirmCard<void>(
    context,
    child: const _OriginLedgerPickerConfirmDialog(),
  );
}

class _OriginLedgerPickerConfirmDialog extends ConsumerStatefulWidget {
  const _OriginLedgerPickerConfirmDialog();

  @override
  ConsumerState<_OriginLedgerPickerConfirmDialog> createState() =>
      _OriginLedgerPickerConfirmDialogState();
}

class _OriginLedgerPickerConfirmDialogState
    extends ConsumerState<_OriginLedgerPickerConfirmDialog> {
  int? _selectedId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);
    final ledgersAsync = ref.watch(localLedgersProvider);
    final currentId = ref.watch(currentLedgerIdProvider);

    final activeId = _selectedId ?? currentId;

    return OriginConfirmCard(
      title: l.homeSwitchLedger,
      textAlign: TextAlign.center,
      actions: [
        // 主操作胶囊：确认切换
        _OriginDialogCapsuleButton(
          text: '确认切换',
          backgroundColor: primaryColor,
          textColor: Colors.white,
          isPrimary: true,
          onPressed: () {
            HapticFeedback.lightImpact();
            if (activeId != currentId) {
              ref.read(currentLedgerIdProvider.notifier).state = activeId;
            }
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 10.0),
        // 次操作胶囊：管理账本
        _OriginDialogCapsuleButton(
          text: l.homeManageLedgers,
          backgroundColor: OriginTokens.dialogButtonSecondary(context),
          textColor: OriginTokens.textPrimary(context),
          isPrimary: false,
          onPressed: () {
            HapticFeedback.lightImpact();
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(builder: (_) => const CustomLedgersPage()),
            );
          },
        ),
        const SizedBox(height: 10.0),
        // 取消胶囊
        _OriginDialogCapsuleButton(
          text: l.commonCancel,
          backgroundColor: OriginTokens.dialogButtonSecondary(context),
          textColor: OriginTokens.textPrimary(context),
          isPrimary: false,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ],
      content: ledgersAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  l.ledgersEmpty,
                  style: TextStyle(
                    fontSize: 14.0,
                    color: OriginTokens.textTertiary(context),
                  ),
                ),
              ),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const OriginDivider(
                    startIndent: 44.0,
                    endIndent: 8.0,
                  ),
                _OriginLedgerPickerTile(
                  name: items[i].name,
                  isShared: items[i].isShared,
                  isSelected: items[i].id == activeId,
                  primaryColor: primaryColor,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedId = items[i].id;
                    });
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const SizedBox(
          height: 120.0,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.commonError,
                style: TextStyle(
                  fontSize: 14.0,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
              const SizedBox(height: 12.0),
              TextButton(
                onPressed: () => ref.invalidate(localLedgersProvider),
                child: Text(l.v4RecordingRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginLedgerPickerTile extends StatelessWidget {
  final String name;
  final bool isShared;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OriginLedgerPickerTile({
    required this.name,
    required this.isShared,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pressedBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      splashColor: pressedBg,
      highlightColor: pressedBg.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 10.0),
        child: Row(
          children: [
            // 左侧图标容器
            Container(
              width: 34.0,
              height: 34.0,
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.12)
                    : OriginTokens.cardSecondary(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isShared ? Icons.people_alt_rounded : Icons.book_rounded,
                  size: 18.0,
                  color: isSelected ? primaryColor : OriginTokens.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 10.0),
            // 中间文本
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? primaryColor
                      : OriginTokens.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8.0),
            // 右侧单选钮
            OriginRadioButton(
              selected: isSelected,
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

