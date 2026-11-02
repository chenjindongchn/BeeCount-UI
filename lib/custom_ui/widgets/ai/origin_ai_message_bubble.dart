import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../pages/ai/chat/widgets/agent_markdown_text.dart';
import '../../styles/origin_tokens.dart';

/// vivo 蓝心小V 风格对话气泡组件 (OriginAiMessageBubble)
///
/// 遵循蓝心小V真机视觉：
/// 1. 用户气泡：右对齐主题色圆角大胶囊（18dp 圆角），白色字体，干净利落；
/// 2. AI 助手气泡：去卡片化（Borderless）设计，文字平铺于页面背景，行距宽阔（1.65）；
/// 3. AI 消息左下角配有轻量化操作工具栏（复制、朗读、更多）；
/// 4. 支持长按呼出复制与删除菜单。
class OriginAiMessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final Widget? extraContent;

  const OriginAiMessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    this.onCopy,
    this.onDelete,
    this.extraContent,
  });

  void _showContextMenu(BuildContext context, Offset globalPos) {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomContext) => Container(
        margin: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222224) : Colors.white,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCopy != null)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, size: 20.0),
                  title: Text(l10n.aiChatCopy, style: const TextStyle(fontSize: 15.0)),
                  onTap: () {
                    Navigator.of(bottomContext).pop();
                    onCopy!();
                  },
                ),
              if (onDelete != null) ...[
                if (onCopy != null)
                  Divider(
                    height: 1.0,
                    thickness: OriginTokens.hairline,
                    color: isDark ? Colors.white12 : const Color(0xFFE5E6EA),
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20.0,
                    color: OriginTokens.expenseRed,
                  ),
                  title: Text(
                    l10n.commonDelete,
                    style: const TextStyle(fontSize: 15.0, color: OriginTokens.expenseRed),
                  ),
                  onTap: () {
                    Navigator.of(bottomContext).pop();
                    onDelete!();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return _buildUserBubble(context);
    }
    return _buildAssistantBubble(context);
  }

  Widget _buildUserBubble(BuildContext context) {
    final primaryColor = OriginTokens.primary(context);

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPressStart: (details) => _showContextMenu(context, details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6.0),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 11.0),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18.0),
              topRight: Radius.circular(18.0),
              bottomLeft: Radius.circular(18.0),
              bottomRight: Radius.circular(6.0),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.25),
                blurRadius: 6.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: Colors.white,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文本主区域（直接平铺，无外层厚重白底大卡片）
            if (content.isNotEmpty)
              GestureDetector(
                onLongPressStart: (details) =>
                    _showContextMenu(context, details.globalPosition),
                child: AgentMarkdownText(
                  data: content,
                  style: TextStyle(
                    color: OriginTokens.textPrimary(context),
                    fontSize: 15.0,
                    height: 1.65,
                  ),
                ),
              ),

            if (extraContent != null) ...[
              const SizedBox(height: 8.0),
              extraContent!,
            ],

            // 仿蓝心小V：左下角微型操作工具栏
            if (content.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onCopy != null)
                    _buildMicroAction(
                      icon: Icons.copy_rounded,
                      tooltip: '复制内容',
                      onTap: onCopy!,
                    ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4.0),
                    _buildMicroAction(
                      icon: Icons.delete_outline_rounded,
                      tooltip: '删除此消息',
                      onTap: onDelete!,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMicroAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Material(
          color: isDark ? Colors.white10 : const Color(0xFFF0F1F4),
          borderRadius: BorderRadius.circular(6.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(6.0),
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: Icon(
                icon,
                size: 13.0,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
        );
      },
    );
  }
}
