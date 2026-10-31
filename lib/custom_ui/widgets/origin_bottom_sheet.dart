import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/currency/exchange_rate_page.dart';
import '../../providers.dart';
import '../../utils/account_type_utils.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import 'origin_card.dart';
import 'origin_divider.dart';
import 'origin_dialog.dart';
import 'origin_switch.dart';

/// 以 OriginUI 规范弹出自底向上升起的抽屉 (OriginBottomSheet)
///
/// 遵循 `OriginUI/docs/15-bottom-sheet.md` 规范：
/// - 顶部圆角 30dp，卡片实底（日间 #FFFFFF，夜间 #1E1E1E）
/// - 进场动效：遮罩 200ms 淡入，卡片 400ms 自底向上滑出 Cubic(0.28, 0.85, 0.36, 1.0)
/// - 退场动效：200ms 快速回退 Cubic(0.25, 0.1, 0.25, 1.0)
/// - 支持在卡片内下滑跟手手势关闭（位移超 100dp 自动退出）
Future<T?> showOriginBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor,
  bool barrierDismissible = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    OriginBottomSheetRoute<T>(
      builder: builder,
      heightFactor: heightFactor,
      barrierDismissible: barrierDismissible,
    ),
  );
}

class OriginBottomSheetRoute<T> extends PopupRoute<T> {
  OriginBottomSheetRoute({
    required this.builder,
    this.heightFactor,
    bool barrierDismissible = true,
  }) : _barrierDismissible = barrierDismissible;

  final WidgetBuilder builder;
  final double? heightFactor;
  final bool _barrierDismissible;

  @override
  Duration get transitionDuration => OriginSheetTokens.enterDuration;

  @override
  Duration get reverseTransitionDuration => OriginSheetTokens.exitDuration;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color? get barrierColor => null; // 遮罩由 _OriginSheetHost 自行渲染

  @override
  String? get barrierLabel => 'dismiss';

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _OriginSheetHost<T>(route: this, animation: animation);
  }
}

class _OriginSheetHost<T> extends StatefulWidget {
  const _OriginSheetHost({required this.route, required this.animation});

  final OriginBottomSheetRoute<T> route;
  final Animation<double> animation;

  @override
  State<_OriginSheetHost<T>> createState() => _OriginSheetHostState<T>();
}

class _OriginSheetHostState<T> extends State<_OriginSheetHost<T>>
    with SingleTickerProviderStateMixin {
  late final CurvedAnimation _slide;
  late final CurvedAnimation _scrim;
  late final AnimationController _settle;
  double _drag = 0;
  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    _slide = CurvedAnimation(
      parent: widget.animation,
      curve: OriginSheetTokens.enterCurve,
      reverseCurve: OriginSheetTokens.exitCurve,
    );
    // 入场遮罩在前 200ms 淡入完毕；退场时同步淡出
    _scrim = CurvedAnimation(
      parent: widget.animation,
      curve: const Interval(0, 0.5),
      reverseCurve: Curves.linear,
    );
    _settle = AnimationController(
      vsync: this,
      duration: OriginSheetTokens.exitDuration,
    )..addListener(() {
        setState(() {
          _drag = _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value));
        });
      });
  }

  @override
  void dispose() {
    _slide.dispose();
    _scrim.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _settle.stop();
    setState(() => _drag = (_drag + d.delta.dy).clamp(0.0, double.infinity));
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dy;
    if (_drag > OriginSheetTokens.dismissDistance ||
        v > OriginSheetTokens.dismissVelocity) {
      Navigator.of(context).maybePop();
    } else {
      _settleFrom = _drag;
      _settle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final insetBottom = mq.viewInsets.bottom;
    final maxH = mq.size.height - mq.padding.top - insetBottom - 8.0;

    Widget cardContent = widget.route.builder(context);
    if (widget.route.heightFactor != null) {
      final h = (mq.size.height * widget.route.heightFactor!).clamp(0.0, maxH);
      cardContent = SizedBox(height: h, width: double.infinity, child: cardContent);
    } else {
      cardContent = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: cardContent,
      );
    }

    return Stack(
      children: [
        // 遮罩蒙层，点击外部退出
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.route.barrierDismissible
                ? () => Navigator.of(context).maybePop()
                : null,
            child: FadeTransition(
              opacity: _scrim,
              child: ColoredBox(color: OriginSheetTokens.scrimColor(context)),
            ),
          ),
        ),
        // 自底向上卡片
        Positioned(
          left: 0,
          right: 0,
          bottom: insetBottom,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) => FractionalTranslation(
              translation: Offset(0, 1 - _slide.value),
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: child,
              ),
            ),
            child: RepaintBoundary(
              child: _OriginSheetScope(
                onDragUpdate: _onDragUpdate,
                onDragEnd: _onDragEnd,
                child: Material(
                  color: OriginSheetTokens.cardColor(context),
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(OriginSheetTokens.cornerRadius),
                  ),
                  child: cardContent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OriginSheetScope extends InheritedWidget {
  const _OriginSheetScope({
    required this.onDragUpdate,
    required this.onDragEnd,
    required super.child,
  });

  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  bool updateShouldNotify(_OriginSheetScope old) => false;
}

/// 抽屉内可触发下滑退出的热区包装组件
class OriginSheetDragRegion extends StatelessWidget {
  final Widget child;
  const OriginSheetDragRegion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_OriginSheetScope>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: scope?.onDragUpdate,
      onVerticalDragEnd: scope?.onDragEnd,
      child: child,
    );
  }
}

/// 顶部药丸拖拽手柄指示条（32x4dp）
class OriginSheetDragHandle extends StatelessWidget {
  const OriginSheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return OriginSheetDragRegion(
      child: Center(
        child: Container(
          width: OriginSheetTokens.dragHandleWidth,
          height: OriginSheetTokens.dragHandleHeight,
          margin: const EdgeInsets.symmetric(
            vertical: OriginSheetTokens.dragHandleVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: OriginSheetTokens.dragHandleColor(context),
            borderRadius: BorderRadius.circular(OriginSheetTokens.dragHandleRadius),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// vivo OriginOS 底部操作面板与单选面板 (OriginActionSheet)
// 严格对齐 `OriginUI/docs/15-bottom-sheet.md` 与蓝河工具箱 `OriginActionSheet`
// =============================================================================

/// 弹出 OriginOS 规范的从底部升起的单选操作面板 (OriginActionSheet)
/// 用于外观模式、金额格式、收支配色等单选
Future<T?> showOriginActionSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<OriginChoiceOption<T>> options,
}) {
  FocusManager.instance.primaryFocus?.unfocus();

  return showOriginBottomSheet<T>(
    context,
    builder: (sheetCtx) => _OriginActionSheetContent<T>(
      title: title,
      selected: selected,
      options: options,
    ),
  );
}

class _OriginActionSheetContent<T> extends StatelessWidget {
  final String title;
  final T selected;
  final List<OriginChoiceOption<T>> options;

  const _OriginActionSheetContent({
    required this.title,
    required this.selected,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = OriginTokens.primary(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 顶部药丸手柄
          const OriginSheetDragHandle(),

          // 2. 居中标题（60dp 最小高度，17sp Medium）
          OriginSheetDragRegion(
            child: SizedBox(
              height: 48.0,
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: OriginSheetTokens.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),

          // 3. 选项列表（受 426dp 限高保护）
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: OriginSheetTokens.maxHeight,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < options.length; i++) ...[
                    if (i > 0)
                      OriginDivider(
                        startIndent: options[i].icon != null ? 56.0 : 20.0,
                        endIndent: 20.0,
                      ),
                    _OriginActionSheetTile<T>(
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
            ),
          ),

          const SizedBox(height: 12.0),

          // 4. 底部独立取消胶囊按钮（高度 46dp，圆角 23dp）
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginSheetTokens.buttonHorizontalPadding,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(null),
              borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
              child: Container(
                height: OriginSheetTokens.buttonHeight,
                decoration: BoxDecoration(
                  color: OriginSheetTokens.cancelBackground(context),
                  borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: OriginSheetTokens.buttonBottomMargin + bottomPadding),
        ],
      ),
    );
  }
}

class _OriginActionSheetTile<T> extends StatefulWidget {
  final OriginChoiceOption<T> option;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OriginActionSheetTile({
    required this.option,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  State<_OriginActionSheetTile<T>> createState() => _OriginActionSheetTileState<T>();
}

class _OriginActionSheetTileState<T> extends State<_OriginActionSheetTile<T>> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pressedBg = isDark ? const Color(0xFF262626) : const Color(0xFFF4F4F6);

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
        color: _isPressed ? pressedBg : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        child: Row(
          children: [
            if (widget.option.icon != null) ...[
              Icon(
                widget.option.icon,
                size: 22.0,
                color: widget.isSelected
                    ? widget.primaryColor
                    : OriginTokens.textSecondary(context),
              ),
              const SizedBox(width: 14.0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.option.title,
                    style: TextStyle(
                      fontSize: OriginSheetTokens.itemFontSize,
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
// vivo OriginOS 风格账户偏好设置抽屉与账户选择抽屉 (自底向上升起)
// =============================================================================

/// 弹出 vivo OriginOS 风格账户偏好设置抽屉（自底向上升起）
Future<void> showOriginAccountPreferencesSheet(BuildContext context, WidgetRef ref) {
  FocusManager.instance.primaryFocus?.unfocus();

  return showOriginBottomSheet<void>(
    context,
    builder: (sheetCtx) => _OriginAccountPreferencesSheet(parentContext: context),
  );
}

class _OriginAccountPreferencesSheet extends ConsumerWidget {
  final BuildContext parentContext;

  const _OriginAccountPreferencesSheet({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 顶部手柄
          const OriginSheetDragHandle(),

          // 2. 顶栏标题栏
          OriginSheetDragRegion(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '账户偏好设置',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textPrimary(context),
                      letterSpacing: -0.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. 设置分组卡片（遵循 OriginSettingGroup / OriginCard 规范）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: OriginCard(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              color: OriginTokens.cardSecondary(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 启用账户资产功能开关 (OriginSwitch 原厂真值胶囊开关)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 22.0,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            l10n.accountsEnableFeature,
                            style: TextStyle(
                              fontSize: 15.0,
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
                  const OriginDivider(startIndent: 50.0, endIndent: 16.0),

                  // 2. 默认支出账户行
                  _OriginSheetSettingRow(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: OriginTokens.expenseRed,
                    title: '默认支出账户',
                    value: accountName(defaultExpenseId),
                    onTap: () {
                      showOriginAccountPickerSheet(
                        context: context,
                        ref: ref,
                        title: '选择默认支出账户',
                        accounts: allAccounts,
                        currentId: defaultExpenseId,
                        isIncome: false,
                      );
                    },
                  ),
                  const OriginDivider(startIndent: 50.0, endIndent: 16.0),

                  // 3. 默认收入账户行
                  _OriginSheetSettingRow(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: OriginTokens.incomeGreen,
                    title: '默认收入账户',
                    value: accountName(defaultIncomeId),
                    onTap: () {
                      showOriginAccountPickerSheet(
                        context: context,
                        ref: ref,
                        title: '选择默认收入账户',
                        accounts: allAccounts,
                        currentId: defaultIncomeId,
                        isIncome: true,
                      );
                    },
                  ),

                  // 4. 多币种汇率管理（仅多币种时展示）
                  if (hasMultipleCurrencies) ...[
                    const OriginDivider(startIndent: 50.0, endIndent: 16.0),
                    _OriginSheetSettingRow(
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
          ),

          const SizedBox(height: 18.0),

          // 4. 底部独立胶囊完成按钮
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginSheetTokens.buttonHorizontalPadding,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
              child: Container(
                height: OriginSheetTokens.buttonHeight,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '完成',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: OriginSheetTokens.buttonBottomMargin + bottomPadding),
        ],
      ),
    );
  }
}

class _OriginSheetSettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OriginSheetSettingRow({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 13.0),
        child: Row(
          children: [
            Icon(icon, size: 22.0, color: iconColor),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w500,
                  color: OriginTokens.textPrimary(context),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textSecondary(context),
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              Icons.chevron_right_rounded,
              size: 20.0,
              color: OriginTokens.textTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出 OriginOS 规范的账户选择器底部抽屉（自底向上升起）
Future<void> showOriginAccountPickerSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required List<db.Account> accounts,
  required int? currentId,
  required bool isIncome,
}) {
  FocusManager.instance.primaryFocus?.unfocus();

  return showOriginBottomSheet<void>(
    context,
    builder: (sheetCtx) => _OriginAccountPickerSheetContent(
      title: title,
      accounts: accounts,
      currentId: currentId,
      isIncome: isIncome,
    ),
  );
}

class _OriginAccountPickerSheetContent extends ConsumerWidget {
  final String title;
  final List<db.Account> accounts;
  final int? currentId;
  final bool isIncome;

  const _OriginAccountPickerSheetContent({
    required this.title,
    required this.accounts,
    required this.currentId,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = OriginTokens.primary(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 顶部手柄
          const OriginSheetDragHandle(),

          // 2. 居中标题
          OriginSheetDragRegion(
            child: SizedBox(
              height: 48.0,
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: OriginSheetTokens.titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4.0),

          // 3. 账户列表（受 426dp 限高保护）
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: OriginSheetTokens.maxHeight,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 不设默认项
                  _OriginAccountRow(
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
                      startIndent: 60.0,
                      endIndent: 20.0,
                    ),
                    _OriginAccountRow(
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

          const SizedBox(height: 12.0),

          // 4. 底部独立取消按钮
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginSheetTokens.buttonHorizontalPadding,
            ),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
              child: Container(
                height: OriginSheetTokens.buttonHeight,
                decoration: BoxDecoration(
                  color: OriginSheetTokens.cancelBackground(context),
                  borderRadius: BorderRadius.circular(OriginSheetTokens.buttonRadius),
                ),
                alignment: Alignment.center,
                child: Text(
                  '取消',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: OriginSheetTokens.buttonBottomMargin + bottomPadding),
        ],
      ),
    );
  }
}

class _OriginAccountRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _OriginAccountRow({
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20.0,
                  color: isSelected ? primaryColor : OriginTokens.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 12.0),
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
