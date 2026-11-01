import 'package:flutter/material.dart';

/// OriginUI 二级页面转场规范
///
/// 对齐蓝河工具箱 `app/.../ui/theme/AppPageNavHost.kt` 的全 App 共享转场：
/// - 时长 300ms（[PageTransitionsBuilder] 基类默认值），缓动 FastOutSlowIn
///   （即 Cubic(0.4, 0.0, 0.2, 1.0)，与 Compose 的 FastOutSlowInEasing 相同）；
/// - 进场：新页面自屏幕右侧全宽滑入；
/// - 压栈退场：旧页面向左退让 1/3 屏宽；
/// - 返回：完全对称反向。
///
/// 与蓝河工具箱的唯一差异：新旧页面均不做淡入淡出，只做位移。原因是 Flutter
/// 与 Compose 的合成环境不同，全页透明度会引入两类黑屏：
/// 1. Compose 两页同时半透明时透出的是窗口主题底色；Flutter 透出的是
///    Navigator 背后的黑色窗口底，动画中段整屏发黑；
/// 2. 本 App 根壳层底栏与首页预算条含 [BackdropFilter]（实时模糊），
///    带模糊的子树一旦被套上透明度，模糊区域会直接渲染成黑色并闪烁。
/// 保持两层页面全不透明后，黑色与闪烁从原理上不会出现，观感即 iOS/OriginOS
/// 原生滑动转场。
///
/// 挂载方式：由 `applyOriginTheme` 注入 `ThemeData.pageTransitionsTheme`，
/// 所有 `MaterialPageRoute`（含上游页面）自动套用，无需改动各 push 调用点。
class OriginPageTransitionsBuilder extends PageTransitionsBuilder {
  const OriginPageTransitionsBuilder();

  static final Animatable<double> _easing =
      CurveTween(curve: Curves.fastOutSlowIn);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 本页自身进出：0 -> 1 为进场，返回时反向全宽滑出
    final enterSlide = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(_easing.animate(animation));

    // 上层页面压栈/出栈时本页的联动：仅退让 1/3 屏宽，保持完全不透明
    final parallaxSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0 / 3.0, 0.0),
    ).animate(_easing.animate(secondaryAnimation));

    return SlideTransition(
      position: parallaxSlide,
      child: SlideTransition(position: enterSlide, child: child),
    );
  }
}
