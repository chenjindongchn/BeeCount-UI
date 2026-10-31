import 'package:flutter/material.dart';

/// OriginUI 二级页面转场规范
///
/// 对齐蓝河工具箱 `app/.../ui/theme/AppPageNavHost.kt` 的全 App 共享转场：
/// - 时长 300ms，缓动 FastOutSlowIn（即 Cubic(0.4, 0.0, 0.2, 1.0)）；
/// - 进场：新页面自屏幕右侧全宽滑入并淡入；
/// - 压栈退场：旧页面向左退让 1/3 屏宽并淡出；
/// - 返回进场：被揭出的页面自 -1/3 屏宽滑回并淡入；
/// - 返回退场：顶层页面全宽向右滑出并淡出。
///
/// 挂载方式：由 [applyOriginTheme] 注入 `ThemeData.pageTransitionsTheme`，
/// 所有 `MaterialPageRoute`（含上游页面）自动套用，无需改动各 push 调用点。
class OriginPageTransitionsBuilder extends PageTransitionsBuilder {
  const OriginPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _OriginPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _OriginPageTransition extends StatelessWidget {
  const _OriginPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  static final Animatable<double> _easing =
      CurveTween(curve: Curves.fastOutSlowIn);

  @override
  Widget build(BuildContext context) {
    // 本页自身进出：0 -> 1 为进场，返回时反向全宽滑出
    final primary = _easing.animate(animation);
    final slide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
        .animate(primary);
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(primary);

    // 上层页面压栈/出栈时本页的联动：退让 1/3 屏宽并淡出
    final secondary = _easing.animate(secondaryAnimation);
    final secondarySlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0 / 3.0, 0.0),
    ).animate(secondary);
    final secondaryFade = Tween<double>(begin: 1.0, end: 0.0).animate(secondary);

    return SlideTransition(
      position: secondarySlide,
      child: FadeTransition(
        opacity: secondaryFade,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: child),
        ),
      ),
    );
  }
}
