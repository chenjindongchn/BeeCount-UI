import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../styles/origin_tokens.dart';

/// vivo 蓝心小V 风格悬浮胶囊输入 Dock (OriginAiInputDock)
///
/// 遵循蓝心小V真机视觉：
/// 1. 悬浮于屏幕底部手势条上方，左右 16dp 留白，完全圆弧大胶囊（26dp 圆角）；
/// 2. 左侧配备拍照/识图图标，支持一键拍照记账与相册导入；
/// 3. 中间输入框无冗余边框，自适应 1~4 行扩展；
/// 4. 右侧动态状态流转：空文本展示麦克风/加号，输入中变为高光发送圆形微胶囊，AI 生成中转为停止呼吸态；
/// 5. 顶部可集成单行横滑建议胶囊药丸栏。
class OriginAiInputDock extends StatefulWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback? onPickImage;
  final VoidCallback? onTakePhoto;

  const OriginAiInputDock({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
    this.onPickImage,
    this.onTakePhoto,
  });

  @override
  State<OriginAiInputDock> createState() => _OriginAiInputDockState();
}

class _OriginAiInputDockState extends State<OriginAiInputDock> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _showImageOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222224) : Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16.0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8.0),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, size: 22.0),
                  title: const Text('拍照识票记账', style: TextStyle(fontSize: 15.0)),
                  onTap: () {
                    Navigator.of(bottomContext).pop();
                    widget.onTakePhoto?.call();
                  },
                ),
                Divider(
                  height: 1.0,
                  thickness: OriginTokens.hairline,
                  color: isDark ? Colors.white12 : const Color(0xFFE5E6EA),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, size: 22.0),
                  title: const Text('从相册选取账单图片', style: TextStyle(fontSize: 15.0)),
                  onTap: () {
                    Navigator.of(bottomContext).pop();
                    widget.onPickImage?.call();
                  },
                ),
                const SizedBox(height: 8.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);
    final dockBg = isDark ? const Color(0xFF232326) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E3E8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 10.0),
          child: Container(
            decoration: BoxDecoration(
              color: dockBg,
              borderRadius: BorderRadius.circular(26.0),
              border: Border.all(color: borderColor, width: OriginTokens.hairline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                  offset: const Offset(0, 4),
                  blurRadius: 16.0,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧相机/识图按钮
                IconButton(
                  tooltip: '拍照/图片记账',
                  icon: Icon(
                    Icons.camera_alt_outlined,
                    size: 22.0,
                    color: OriginTokens.textSecondary(context),
                  ),
                  onPressed: () => _showImageOptions(context),
                ),

                // 中间输入框
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (_hasText && !widget.isLoading) {
                        widget.onSend();
                      }
                    },
                    style: TextStyle(
                      fontSize: 14.5,
                      color: OriginTokens.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isLoading ? '小助手思考中...' : '点击输入或对我说...',
                      hintStyle: TextStyle(
                        fontSize: 14.5,
                        color: OriginTokens.textTertiary(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 10.0,
                      ),
                      isDense: true,
                    ),
                  ),
                ),

                // 右侧状态与操作按钮
                if (widget.isLoading)
                  // 停止按钮
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Material(
                      color: isDark ? Colors.white12 : const Color(0xFFF1F2F5),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onStop();
                        },
                        child: const SizedBox(
                          width: 36.0,
                          height: 36.0,
                          child: Center(
                            child: Icon(
                              Icons.stop_rounded,
                              size: 20.0,
                              color: Color(0xFFFF4D4F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_hasText)
                  // 高亮发送圆形微胶囊
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Material(
                      color: primaryColor,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onSend();
                        },
                        child: const SizedBox(
                          width: 36.0,
                          height: 36.0,
                          child: Center(
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              size: 20.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  // 未输入时的右侧图标（语音或加号）
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '语音记账',
                        icon: Icon(
                          Icons.mic_none_rounded,
                          size: 22.0,
                          color: OriginTokens.textSecondary(context),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('按住说话功能持续升级中')),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
  }
}
