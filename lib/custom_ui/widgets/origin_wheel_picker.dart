import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../styles/origin_tokens.dart';

/// vivo OriginOS 风格单列阻尼滚轮组件 (OriginWheelPicker)
///
/// 遵循 OriginOS 细节体验：
/// 1. 阻尼手感与细腻物理滚动；
/// 2. 居中选中胶囊（圆角 10dp，微透明底色，不遮挡阅读）；
/// 3. 上下平滑渐隐遮罩（ShaderMask 36dp 渐隐，消除突兀截断）；
/// 4. 触感段落震动反馈（HapticFeedback.selectionClick）；
/// 5. 选中项 17sp SemiBold / 未选中项 15sp Regular 阶梯字重。
class OriginWheelPicker<T> extends StatefulWidget {
  final List<T> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final String Function(T item) labelBuilder;
  final String? unit;
  final double itemExtent;
  final double height;

  const OriginWheelPicker({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.labelBuilder,
    this.unit,
    this.itemExtent = 44.0,
    this.height = 216.0,
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

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 滚轮本体（带上下渐隐遮罩）
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
              overAndUnderCenterOpacity: 0.45,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: isSelected ? 17.0 : 15.0,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? OriginTokens.textPrimary(context)
                                  : (isDark
                                      ? const Color(0xFF888888)
                                      : const Color(0xFF999999)),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (widget.unit != null) ...[
                            const SizedBox(width: 2.0),
                            Text(
                              widget.unit!,
                              style: TextStyle(
                                fontSize: isSelected ? 13.0 : 12.0,
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                color: isSelected
                                    ? OriginTokens.textPrimary(context)
                                    : (isDark
                                        ? const Color(0xFF777777)
                                        : const Color(0xFFAAAAAA)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 居中指示胶囊框（忽略指针点击）
          IgnorePointer(
            child: Container(
              height: widget.itemExtent - 4.0,
              margin: const EdgeInsets.symmetric(horizontal: 6.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
