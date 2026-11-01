import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格单列阻尼滚轮组件 (OriginWheelPicker)
///
/// 遵循 vivo OriginOS 官方规范（参考 25-date-and-time-picker.md）：
/// 1. 高度 200dp，单项高度 40dp，可见行数 5 行；
/// 2. 选中项 22~24sp Bold，未选中项淡出（overAndUnderCenterOpacity: 0.35）；
/// 3. 单位固定于选中行右侧（若指定 unit），滚轮纯数字翻滚，单位对称几何占位严格静止，杜绝重叠；
/// 4. 上下平滑渐隐遮罩（ShaderMask）；
/// 5. 触感段落震动反馈（HapticFeedback.selectionClick）。
class OriginWheelPicker<T> extends StatefulWidget {
  final List<T> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String Function(T item) labelBuilder;
  final String? unit;
  final double itemExtent;
  final double height;
  final double selectedFontSize;
  final double unselectedFontSize;

  const OriginWheelPicker({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.labelBuilder,
    this.unit,
    this.itemExtent = 40.0,
    this.height = 200.0,
    this.selectedFontSize = 22.0,
    this.unselectedFontSize = 16.0,
  });

  @override
  State<OriginWheelPicker<T>> createState() => _OriginWheelPickerState<T>();
}

class _OriginWheelPickerState<T> extends State<OriginWheelPicker<T>> {
  late FixedExtentScrollController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.selectedIndex.clamp(
      0,
      widget.items.isEmpty ? 0 : widget.items.length - 1,
    );
    _controller = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  void didUpdateWidget(covariant OriginWheelPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.isNotEmpty && _controller.hasClients) {
      final targetIndex = widget.selectedIndex.clamp(0, widget.items.length - 1);
      if (_controller.selectedItem != targetIndex) {
        _isSyncing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          _controller.jumpToItem(targetIndex);
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = OriginTokens.textPrimary(context);
    final secondaryTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF999999);

    // 第一性原理：精确计算数字与固定单位的对称几何占位，确保无论是 4 位年份还是 2 位月日时分，绝不重叠
    final sampleText = widget.labelBuilder(widget.items.first);
    final isWideText = sampleText.length >= 4; // 4 位年份等
    final numberWidth = isWideText ? 64.0 : 34.0;
    const unitGap = 4.0;
    const unitWidth = 20.0;

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 居中选中行背景微高亮指示条（极简通透）
          IgnorePointer(
            child: Container(
              height: widget.itemExtent,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),

          // 滚轮本体（带上下平滑渐隐 ShaderMask）
          ShaderMask(
            shaderCallback: (Rect rect) {
              return const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black,
                  Colors.black,
                  Colors.transparent,
                ],
                stops: [0.0, 0.22, 0.78, 1.0],
              ).createShader(rect);
            },
            blendMode: BlendMode.dstIn,
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: widget.itemExtent,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.003,
              diameterRatio: 1.5,
              overAndUnderCenterOpacity: 0.35,
              onSelectedItemChanged: (index) {
                if (_isSyncing) return;
                HapticFeedback.selectionClick();
                widget.onChanged(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, index) {
                  final isSelected = index == widget.selectedIndex;
                  final text = widget.labelBuilder(widget.items[index]);

                  return Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: numberWidth,
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSelected
                                  ? widget.selectedFontSize
                                  : widget.unselectedFontSize,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? primaryTextColor : secondaryTextColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        if (widget.unit != null)
                          const SizedBox(width: unitGap + unitWidth),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // 原厂关键细节：单位固定在居中行右侧，纯数字上下翻滚，单位完全静止
          if (widget.unit != null)
            IgnorePointer(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: numberWidth),
                    const SizedBox(width: unitGap),
                    SizedBox(
                      width: unitWidth,
                      child: Text(
                        widget.unit!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
