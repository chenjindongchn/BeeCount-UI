import 'package:flutter/material.dart';

import '../styles/origin_sheet_tokens.dart';

/// 以 OriginUI 规范弹出底部抽屉
///
/// 遵循 `OriginUI/docs/15-bottom-sheet.md` 规范：
/// - 顶部圆角 30dp，卡片实底（日间 #FFFFFF，夜间 #1E1E1E）
/// - 进场动效：遮罩 200ms 淡入，卡片 400ms 自底向上 Cubic(0.28, 0.85, 0.36, 1.0)
/// - 退场动效：200ms 快速回退 Cubic(0.25, 0.1, 0.25, 1.0)
/// - 支持在 [OriginSheetDragRegion] 区域内下滑手势关闭
Future<T?> showOriginBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double heightFactor = 0.94,
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
    required this.heightFactor,
    bool barrierDismissible = true,
  }) : _barrierDismissible = barrierDismissible;

  final WidgetBuilder builder;
  final double heightFactor;
  final bool _barrierDismissible;

  @override
  Duration get transitionDuration => OriginSheetTokens.enterDuration;

  @override
  Duration get reverseTransitionDuration => OriginSheetTokens.exitDuration;

  @override
  bool get barrierDismissible => _barrierDismissible;

  @override
  Color? get barrierColor => null; // 遮罩由 _OriginSheetHost 自行分段渲染

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
    // 入场遮罩在前 200ms（400ms 的前 50%）淡入完毕；退场时同步淡出
    _scrim = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(
        0,
        OriginSheetTokens.scrimEnterDuration.inMilliseconds /
            OriginSheetTokens.enterDuration.inMilliseconds,
      ),
      reverseCurve: Curves.linear,
    );
    _settle = AnimationController(
      vsync: this,
      duration: OriginSheetTokens.exitDuration,
    )..addListener(() {
        setState(() {
          _drag = _settleFrom * (1 - Curves.easeOut.transform(_settle.value));
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
    final maxH = mq.size.height - mq.padding.top - insetBottom - 8;
    final height = (mq.size.height * widget.route.heightFactor).clamp(0.0, maxH);

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
                  child: SizedBox(
                    height: height,
                    width: double.infinity,
                    child: widget.route.builder(context),
                  ),
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
  const OriginSheetDragRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_OriginSheetScope>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: scope?.onDragUpdate,
      onVerticalDragEnd: scope?.onDragEnd,
      child: child,
    );
  }
}
