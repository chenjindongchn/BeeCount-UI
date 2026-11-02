import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/runtime/agent_execution_settings.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/ai/agent_activity_page.dart';
import '../../pages/ai/agent_memory_page.dart';
import '../../pages/ai/agent_permissions_page.dart';
import '../../pages/ai/ai_provider_manage_page.dart';
import '../../pages/ai/ai_settings_page.dart';
import '../../providers/ai_chat_providers.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_setting_card.dart';

/// vivo OriginOS 风格 AI 助手设置页面 (CustomAISettingsPage)
///
/// 遵循蓝河/OriginUI 规范：
/// 1. 紧凑型标题栏（56dp）；
/// 2. 分组式圆角卡片（12dp 圆角，20dp 边距，0.5dp 发丝分割线）；
/// 3. 全量覆盖权限管控、记忆管理、执行深度、历史轨迹与模型服务商配置；
/// 4. 执行深度弹窗采用 OriginDialog 拟态单选交互。
class CustomAISettingsPage extends ConsumerStatefulWidget {
  final int ledgerId;

  const CustomAISettingsPage({
    super.key,
    required this.ledgerId,
  });

  @override
  ConsumerState<CustomAISettingsPage> createState() =>
      _CustomAISettingsPageState();
}

class _CustomAISettingsPageState extends ConsumerState<CustomAISettingsPage> {
  AgentExecutionSettings? _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final value = await ref.read(agentExecutionSettingsStoreProvider).read();
      if (mounted) {
        setState(() {
          _settings = value;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changeExecutionDepth() async {
    if (_settings == null || _isSaving || _isLoading) return;
    HapticFeedback.lightImpact();

    final l = AppLocalizations.of(context);
    final currentTurns = _settings!.maximumModelTurns;

    final depthOptions = [
      (2, l.agentExecutionDepthQuick, '2 回合 · 快速响应'),
      (AgentExecutionSettings.standardTurns, l.agentExecutionDepthStandard, '4 回合 · 智能适中'),
      (6, l.agentExecutionDepthDeep, '6 回合 · 深度推理'),
      (AgentExecutionSettings.maximumTurns, l.agentExecutionDepthCustom, '12 回合 · 完整分析'),
    ];

    final selected = await showOriginCustomDialog<int>(
      context,
      child: OriginDialog(
        title: l.agentExecutionDepthChooseTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: depthOptions.map((opt) {
            final turns = opt.$1;
            final title = opt.$2;
            final desc = opt.$3;
            final isSelected = turns == currentTurns;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10.0),
                onTap: () => Navigator.of(context).pop(turns),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? OriginTokens.primary(context)
                                    : OriginTokens.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: OriginTokens.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20.0,
                          color: OriginTokens.primary(context),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        cancelText: l.commonCancel,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );

    if (selected == null || selected == currentTurns || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(agentExecutionSettingsStoreProvider)
          .setMaximumModelTurns(selected);
      await _loadSettings();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _navigateTo(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final turns = _settings?.maximumModelTurns ?? AgentExecutionSettings.standardTurns;
    final depthLabel = switch (turns) {
      2 => l.agentExecutionDepthQuick,
      4 => l.agentExecutionDepthStandard,
      6 => l.agentExecutionDepthDeep,
      _ => l.agentExecutionDepthCustom,
    };

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.agentAssistantSettingsTitle,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 12.0),

          // 顶部描述小字
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 4.0,
            ),
            child: Text(
              l.agentAssistantSettingsSubtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 10.0),

          // 分组一：AI 核心能力与安全权限
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 4.0,
            ),
            child: Text(
              '智能控制与安全',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.agentAssistantPermissionsEntry,
                subtitle: l.agentAssistantPermissionsEntryDescription,
                leading: const Icon(
                  Icons.shield_outlined,
                  size: 20.0,
                  color: Color(0xFF1890FF),
                ),
                onTap: () => _navigateTo(const AgentPermissionsPage()),
              ),
              OriginSettingItem(
                title: l.agentAssistantMemoryEntry,
                subtitle: l.agentAssistantMemoryEntryDescription,
                leading: const Icon(
                  Icons.psychology_outlined,
                  size: 20.0,
                  color: Color(0xFF722ED1),
                ),
                onTap: () => _navigateTo(AgentMemoryPage(ledgerId: widget.ledgerId)),
              ),
              OriginSettingItem(
                title: l.agentAssistantActivityEntry,
                subtitle: l.agentAssistantActivityEntryDescription,
                leading: const Icon(
                  Icons.history_rounded,
                  size: 20.0,
                  color: Color(0xFF13C2C2),
                ),
                onTap: () => _navigateTo(AgentActivityPage(ledgerId: widget.ledgerId)),
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // 分组二：思考与执行深度
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 4.0,
            ),
            child: Text(
              '推理与深度设置',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.agentExecutionDepthEntry,
                subtitle: '$depthLabel（最多 $turns 轮思考迭代）',
                valueText: depthLabel,
                leading: const Icon(
                  Icons.tune_rounded,
                  size: 20.0,
                  color: Color(0xFFFA8C16),
                ),
                trailing: _isLoading || _isSaving
                    ? const SizedBox(
                        width: 16.0,
                        height: 16.0,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      )
                    : null,
                onTap: _changeExecutionDepth,
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // 分组三：大模型服务商与 API Key
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 4.0,
            ),
            child: Text(
              '模型与服务商管理',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: 'AI 大模型设置',
                subtitle: '配置默认模型、系统 Prompt 与全局参数',
                leading: const Icon(
                  Icons.smart_toy_outlined,
                  size: 20.0,
                  color: Color(0xFF52C41A),
                ),
                onTap: () => _navigateTo(const AISettingsPage()),
              ),
              OriginSettingItem(
                title: '服务商与 API Key',
                subtitle: '管理智谱 GLM、DeepSeek、OpenAI 等接入点',
                leading: const Icon(
                  Icons.key_rounded,
                  size: 20.0,
                  color: Color(0xFFEB2F96),
                ),
                onTap: () => _navigateTo(const AIProviderManagePage()),
              ),
            ],
          ),

          const SizedBox(height: 32.0),
        ],
      ),
    );
  }
}
