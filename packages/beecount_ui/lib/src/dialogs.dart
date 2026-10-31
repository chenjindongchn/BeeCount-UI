import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'foundations.dart';

/// vivo OriginOS 风格卡片弹窗规范 (BeeDialog)
///
/// 遵循蓝河工具箱 `OriginUI/docs/22-update-dialog.md` 与 vivo vigour 原厂反编译真值：
/// - 【位置与动画】：悬浮贴靠屏幕底端（Alignment.bottomCenter），从屏幕底部平滑上升入场 (Slide up from bottom)；
/// - 【几何规范】：卡片标准宽度 304.0dp，外部大圆角 30.0dp (vigour_layout_corner_Radius)；
/// - 【排版真值】：16sp SemiBold 居中大标题，正文/表单内容严格靠左排版 (TextAlign.start)；
/// - 【按钮规范】：上下竖排双胶囊按钮，每个按钮占一整行，高度 46.0dp，圆角 23.0dp，垂直间距 12dp；
///   主操作在上（实心强调色或赤红危险色），次操作在下（实心中性灰胶囊）；
/// - 【纯净底色】：日间纯白 #FFFFFF，夜间纯黑暗灰 #1E1E1E，不产生杂色遮罩；
/// - 【遮罩蒙层】：日间 30% alpha (#4D000000)，夜间 60% alpha (#99000000)。
class BeeDialog extends StatelessWidget {
  const BeeDialog({
    super.key,
    required this.title,
    this.content,
    this.actions = const [],
    this.showClose = true,
    this.stackActions = true,
    this.animate = true,
  });

  final Widget title;
  final Widget? content;
  final List<Widget> actions;
  final bool showClose, stackActions;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? const Color(0xFFE9E9E9) : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? const Color(0xFFA6A6A6) : const Color(0xFF666666);
    final softBtnBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);

    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light
            ? const Color(0xff262829)
            : Colors.white;

    final actionTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(onPrimary: foreground),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: foreground,
          minimumSize: const Size(double.infinity, 46),
          maximumSize: const Size(double.infinity, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: softBtnBg,
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 46),
          maximumSize: const Size(double.infinity, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: softBtnBg,
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 46),
          maximumSize: const Size(double.infinity, 46),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: foreground,
          elevation: 0,
          minimumSize: const Size(double.infinity, 46),
          maximumSize: const Size(double.infinity, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        ),
      ),
    );

    // 智能主次操作排序：若原顺序为 [次要/取消, 主要/删除/确认]，调整为 OriginOS 标准：主操作在上，次操作在下
    final sortedActions = _sortOriginActions(actions);

    // 靠底边距：系统手势导航条高度 + 28dp (OriginDimens.DialogBottomMargin)
    final bottomPadding = MediaQuery.of(context).padding.bottom + 28.0;

    final card = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 28.0,
          right: 28.0,
          bottom: bottomPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 304.0, // vivo vigour 官方标准卡片宽度 304dp
            minWidth: 260.0,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(30.0), // 30dp 大圆角
            elevation: 12.0,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 标题行（16sp SemiBold 严格居中，CloseButton 位于右上角保持平衡）
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: showClose ? 36.0 : 0.0,
                          ),
                          child: DefaultTextStyle.merge(
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                              letterSpacing: -0.2,
                            ),
                            child: title,
                          ),
                        ),
                      ),
                      if (showClose)
                        Positioned(
                          right: 0,
                          child: SizedBox(
                            width: 32.0,
                            height: 32.0,
                            child: CloseButton(
                              color: textSecondary,
                              style: IconButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // 2. 正文/表单内容区域（遵循 OriginUI 规范：严格靠左排版，最大高度 360dp，平滑滚动）
                  if (content != null) ...[
                    const SizedBox(height: 14.0),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360.0),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DefaultTextStyle.merge(
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: 14.0,
                                height: 1.5,
                                color: textSecondary,
                              ),
                              child: content!,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 3. 底部操作按钮组（OriginOS 规范：上下竖排，每个按钮占满一行，间距 12dp）
                  if (sortedActions.isNotEmpty) ...[
                    const SizedBox(height: 20.0),
                    Theme(
                      data: actionTheme,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < sortedActions.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12.0),
                            _OriginActionCapsule(action: sortedActions[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (animate) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.28, 0.85, 0.36, 1.0),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0.0, (1.0 - value) * 60.0), // 从带动画底部平滑上升 60dp
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: card,
      );
    }

    return card;
  }
}

/// 将传入的 actions 按 OriginOS 规范智能重排（主操作在上，次操作在下）
List<Widget> _sortOriginActions(List<Widget> rawActions) {
  if (rawActions.length != 2) return rawActions;

  final first = rawActions[0];
  final second = rawActions[1];

  bool isSecondaryOrCancel(Widget w) {
    if (w is BeeButton) {
      if (w.kind == BeeButtonKind.secondary || w.kind == BeeButtonKind.quiet) {
        return true;
      }
      final l = w.label.toLowerCase();
      if (l.contains('取消') || l.contains('cancel') || l.contains('返回') || l.contains('关闭')) {
        return true;
      }
    }
    if (w is TextButton || w is OutlinedButton) return true;
    return false;
  }

  bool isPrimaryOrDanger(Widget w) {
    if (w is BeeButton) {
      if (w.kind == BeeButtonKind.primary || w.kind == BeeButtonKind.danger) {
        return true;
      }
      final l = w.label.toLowerCase();
      if (l.contains('确定') ||
          l.contains('确认') ||
          l.contains('删除') ||
          l.contains('保存') ||
          l.contains('导入') ||
          l.contains('delete') ||
          l.contains('confirm') ||
          l.contains('ok')) {
        return true;
      }
    }
    if (w is FilledButton || w is ElevatedButton) return true;
    return false;
  }

  if (isSecondaryOrCancel(first) && isPrimaryOrDanger(second)) {
    return [second, first];
  }

  return rawActions;
}

/// OriginOS 胶囊按钮渲染包装器（高度 46dp，圆角 23dp，满宽独占一行）
class _OriginActionCapsule extends StatelessWidget {
  final Widget action;

  const _OriginActionCapsule({required this.action});

  @override
  Widget build(BuildContext context) {
    if (action is BeeButton) {
      final btn = action as BeeButton;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final primary = theme.colorScheme.primary;

      final Color bg;
      final Color fg;
      final FontWeight fw;

      switch (btn.kind) {
        case BeeButtonKind.danger:
          bg = const Color(0xFFFF4D4F);
          fg = Colors.white;
          fw = FontWeight.w600;
          break;
        case BeeButtonKind.primary:
          bg = primary;
          fg = Colors.white;
          fw = FontWeight.w600;
          break;
        case BeeButtonKind.secondary:
        case BeeButtonKind.quiet:
          bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);
          fg = isDark ? const Color(0xFFE9E9E9) : const Color(0xFF333333);
          fw = FontWeight.w500;
          break;
      }

      return SizedBox(
        height: 46.0,
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
          ),
          onPressed: btn.loading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  btn.onPressed?.call();
                },
          child: btn.loading
              ? SizedBox(
                  width: 18.0,
                  height: 18.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (btn.icon != null) ...[
                      btn.icon!,
                      const SizedBox(width: 6.0),
                    ],
                    Flexible(
                      child: Text(
                        btn.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: fw,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return SizedBox(
      height: 46.0,
      width: double.infinity,
      child: action,
    );
  }
}

/// 基础通用弹窗唤起函数 (showBeeDialog)
///
/// 遵循 vivo OriginOS 规范：
/// - 从屏幕底端向上滑升入场 (Slide up from bottom)；
/// - 配合 Cubic(0.28, 0.85, 0.36, 1.0) 弹簧贝塞尔曲线与触感反馈；
/// - 卡片贴底悬浮展示，宽度 304dp，圆角 30dp。
Future<T?> showBeeDialog<T>(
  BuildContext context, {
  required String title,
  required Widget child,
  List<Widget> actions = const [],
  bool dismissible = true,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  HapticFeedback.lightImpact();

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scrimColor = isDark ? const Color(0x99000000) : const Color(0x4D000000);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: scrimColor,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim1, anim2) => BeeDialog(
      title: Text(title),
      content: child,
      actions: actions,
      animate: false,
    ),
    transitionBuilder: (ctx, anim1, anim2, c) {
      final curved = CurvedAnimation(
        parent: anim1,
        curve: const Cubic(0.28, 0.85, 0.36, 1.0),
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.28), // 自底端向上平滑升起
            end: Offset.zero,
          ).animate(curved),
          child: c,
        ),
      );
    },
  );
}

/// vivo OriginOS 风格通用操作二次确认弹窗组件
class _OriginBeeConfirmDialogWidget extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;

  const _OriginBeeConfirmDialogWidget({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
    final textPrimary = isDark ? const Color(0xFFE9E9E9) : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? const Color(0xFFA6A6A6) : const Color(0xFF666666);
    final cancelBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F4F6);
    final cancelTextColor = isDark ? const Color(0xFFE9E9E9) : const Color(0xFF333333);
    final confirmBg = danger ? const Color(0xFFFF4D4F) : primary;

    // 靠底边距：系统手势导航条高度 + 28dp (OriginDimens.DialogBottomMargin)
    final bottomPadding = MediaQuery.of(context).padding.bottom + 28.0;

    // 正文对齐逻辑：遵循 vivo 原厂 DialogContentMessageTextView 机制，正文说明一律靠左排版
    final isSingleShort = !message.contains('\n') && message.length < 16;
    final messageAlign = isSingleShort ? TextAlign.center : TextAlign.start;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 28.0,
          right: 28.0,
          bottom: bottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 304.0, // vivo vigour 官方标准卡片宽度 304dp
            minWidth: 260.0,
          ),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(30.0), // 30dp 大圆角
            elevation: 12.0,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 标题（16sp SemiBold 居中）
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  // 2. 正文说明（14sp Regular，行高 1.5，按 OriginUI 规范严格靠左对齐，最大高度 360dp 滚动防挤出）
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 14.0),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360.0),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          message,
                          textAlign: messageAlign,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.normal,
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24.0),
                  // 3. 底部 OriginOS 竖排双实心胶囊按钮（主操作在上、次操作在下，各占一行）
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 上方：主操作按钮（确认 / 删除，实心填充品牌色或危险赤红）
                      SizedBox(
                        height: 46.0,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmBg,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23.0),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      // 下方：次操作按钮（取消 / 返回，实心中性灰色胶囊）
                      SizedBox(
                        height: 46.0,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cancelBg,
                            foregroundColor: cancelTextColor,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(23.0),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            cancelLabel,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格通用操作二次确认弹窗 (showBeeConfirm)
///
/// 遵循第一性原理：全软件 14 个核心业务二次确认入口统一调用此函数。
/// - 【位置与动画】：悬浮贴靠屏幕底端（Alignment.bottomCenter），从屏幕底部平滑上升入场 (Slide up from bottom)；
/// - 【排版真值】：16sp 居中大标题，正文说明严格靠左对齐 (TextAlign.start)；
/// - 【几何规范】：304dp 限制宽，30dp 大圆角，46dp 双胶囊按钮。
Future<bool> showBeeConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  HapticFeedback.lightImpact();

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final scrimColor = isDark ? const Color(0x99000000) : const Color(0x4D000000);

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: scrimColor,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, anim1, anim2) => _OriginBeeConfirmDialogWidget(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      danger: danger,
    ),
    transitionBuilder: (ctx, anim1, anim2, child) {
      // vivo 官方动效：Cubic(0.28, 0.85, 0.36, 1.0) 从带动画底部平滑滑入 (Slide up from bottom)
      final curved = CurvedAnimation(
        parent: anim1,
        curve: const Cubic(0.28, 0.85, 0.36, 1.0),
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.28), // 自底端向上平滑升起
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );

  return result ?? false;
}
