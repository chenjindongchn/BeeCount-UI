import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../agent/permission/agent_authorization_gate.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/ai/agent_tool_presentation.dart';
import '../../styles/origin_tokens.dart';
import '../origin_card.dart';
import '../origin_dialog.dart';

/// vivo OriginOS 风格 AI 助手工具调用授权弹窗 (OriginToolAuthorizationDialog)
///
/// 遵循 OriginUI 规范：
/// 1. 贴底居中悬浮、30dp 大圆角卡片；
/// 2. 纵向堆叠标准胶囊按钮（高度 46dp，圆角 23dp）；
/// 3. 安全提示与调用参数卡片化展示。
Future<AgentToolAuthorizationChoice> showOriginToolAuthorizationDialog({
  required BuildContext context,
  required AgentToolAuthorizationRequest request,
}) async {
  final l10n = AppLocalizations.of(context);
  final arguments = AgentToolPresentation.safeArguments(
    l10n,
    request.toolName,
    request.arguments,
  );

  final toolLabel = AgentToolPresentation.label(l10n, request.toolName);
  final toolDesc = AgentToolPresentation.description(l10n, request.toolName);
  final scopeText = request.ledgerId == null
      ? l10n.agentAuthorizationAllLedgers
      : l10n.agentAuthorizationCurrentLedger(request.ledgerId!);

  final choice = await showOriginCustomDialog<AgentToolAuthorizationChoice>(
    context,
    barrierDismissible: false,
    child: OriginDialog(
      title: l10n.agentAuthorizationTitle,
      icon: Container(
        width: 44.0,
        height: 44.0,
        decoration: BoxDecoration(
          color: OriginTokens.primary(context).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.shield_outlined,
          size: 24.0,
          color: OriginTokens.primary(context),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 工具名称与功能描述卡片
          OriginCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(14.0),
            color: OriginTokens.cardSecondary(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        toolLabel,
                        style: TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: OriginTokens.primary(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(
                        scopeText,
                        style: TextStyle(
                          fontSize: 11.0,
                          color: OriginTokens.primary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (toolDesc.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Text(
                    toolDesc,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 参数清单（若有）
          if (arguments.isNotEmpty) ...[
            const SizedBox(height: 10.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: Text(
                l10n.agentAuthorizationParameters,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: OriginTokens.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: 4.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < arguments.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${arguments[i].label}: ',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            arguments[i].value,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: OriginTokens.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      customActions: [
        // 1. 始终允许（主强调色胶囊）
        OriginDialogCapsuleButton(
          text: l10n.agentAuthorizationAlwaysAllow,
          backgroundColor: OriginTokens.primary(context),
          textColor: Colors.white,
          isPrimary: true,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(AgentToolAuthorizationChoice.alwaysAllow);
          },
        ),
        const SizedBox(height: 10.0),

        // 2. 仅本次允许（次要操作胶囊）
        OriginDialogCapsuleButton(
          text: l10n.agentAuthorizationAllowOnce,
          backgroundColor: OriginTokens.dialogButtonSecondary(context),
          textColor: OriginTokens.primary(context),
          isPrimary: false,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(AgentToolAuthorizationChoice.allowOnce);
          },
        ),
        const SizedBox(height: 10.0),

        // 3. 拒绝（取消胶囊）
        OriginDialogCapsuleButton(
          text: l10n.agentAuthorizationDeny,
          backgroundColor: OriginTokens.dialogButtonSecondary(context),
          textColor: OriginTokens.textPrimary(context),
          isPrimary: false,
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(AgentToolAuthorizationChoice.deny);
          },
        ),
      ],
    ),
  );

  return choice ?? AgentToolAuthorizationChoice.deny;
}
