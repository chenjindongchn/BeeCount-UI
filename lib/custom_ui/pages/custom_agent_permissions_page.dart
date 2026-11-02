import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/permission/agent_tool_permission.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/ai/agent_tool_presentation.dart';
import '../../providers/ai_chat_providers.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_setting_card.dart';

/// vivo OriginOS 风格 AI 助手权限管理页面 (CustomAgentPermissionsPage)
///
/// 遵循设计规范：
/// 1. 紧凑型标题栏（OriginSmallTopAppBar），右上角采用 OriginOS 规范入口与恢复默认确认弹窗；
/// 2. 分组式圆角卡片（OriginSettingGroup），清晰划分只读查询工具与数据修改工具；
/// 3. 单项权限切换采用 OriginOS 规范单选对话框 (showOriginChoiceDialog)，提供同心圆单选与震动反馈；
/// 4. 100% 保持 Riverpod 业务逻辑与权限持久化复用，零破坏性侵入。
class CustomAgentPermissionsPage extends ConsumerStatefulWidget {
  const CustomAgentPermissionsPage({super.key});

  @override
  ConsumerState<CustomAgentPermissionsPage> createState() =>
      _CustomAgentPermissionsPageState();
}

class _CustomAgentPermissionsPageState
    extends ConsumerState<CustomAgentPermissionsPage> {
  Map<String, AgentToolPermission>? _permissions;
  final Set<String> _writing = <String>{};
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final values =
          await ref.read(agentToolPermissionStoreProvider).readAll();
      if (mounted) {
        setState(() {
          _permissions = values;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.of(context).agentPermissionWriteFailed;
        });
      }
    }
  }

  Future<void> _setPermission(
    String toolName,
    AgentToolPermission permission,
  ) async {
    if (_writing.contains(toolName) || _isRestoring) return;
    setState(() => _writing.add(toolName));
    try {
      await ref
          .read(agentToolPermissionStoreProvider)
          .setPermission(toolName, permission);
      if (mounted) {
        setState(() {
          _permissions = {...?_permissions, toolName: permission};
        });
      }
    } catch (_) {
      if (mounted) {
        _showToast(AppLocalizations.of(context).agentPermissionWriteFailed);
      }
    } finally {
      if (mounted) setState(() => _writing.remove(toolName));
    }
  }

  Future<void> _showPermissionChoice(
    AgentToolPermissionDescriptor descriptor,
    AgentToolPermission current,
  ) async {
    if (_isRestoring || _writing.contains(descriptor.toolName)) return;
    HapticFeedback.lightImpact();

    final l = AppLocalizations.of(context);
    final toolLabel = AgentToolPresentation.label(l, descriptor.toolName);

    final selected = await showOriginChoiceDialog<AgentToolPermission>(
      context,
      title: '$toolLabel 权限',
      selected: current,
      options: [
        OriginChoiceOption<AgentToolPermission>(
          value: AgentToolPermission.alwaysAllow,
          title: AgentToolPresentation.permissionLabel(
            l,
            AgentToolPermission.alwaysAllow,
          ),
          subtitle: '助手可直接调用，无需额外确认',
          icon: Icons.check_circle_outline_rounded,
        ),
        OriginChoiceOption<AgentToolPermission>(
          value: AgentToolPermission.ask,
          title: AgentToolPresentation.permissionLabel(
            l,
            AgentToolPermission.ask,
          ),
          subtitle: '调用该工具前，需要您的授权确认',
          icon: Icons.help_outline_rounded,
        ),
      ],
    );

    if (selected != null && selected != current && mounted) {
      await _setPermission(descriptor.toolName, selected);
    }
  }

  Future<void> _restoreDefaults() async {
    if (_isRestoring || _writing.isNotEmpty) return;
    final l = AppLocalizations.of(context);

    final confirmed = await showOriginConfirmDialog(
      context,
      title: l.agentPermissionsRestoreTitle,
      message: l.agentPermissionsRestoreDescription,
      confirmText: l.agentPermissionsRestoreConfirm,
      cancelText: l.commonCancel,
      isDanger: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      await ref.read(agentToolPermissionStoreProvider).restoreDefaults();
      if (mounted) {
        await _load();
        _showToast('已恢复默认权限');
      }
    } catch (_) {
      if (mounted) _showToast(l.agentPermissionWriteFailed);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPermissionBadge(
    BuildContext context,
    AgentToolPermission permission,
  ) {
    final (label, Color bgColor, Color textColor) = switch (permission) {
      AgentToolPermission.alwaysAllow => (
          '允许',
          const Color(0xFF52C41A).withValues(alpha: 0.12),
          const Color(0xFF389E0D),
        ),
      AgentToolPermission.ask => (
          '询问',
          const Color(0xFFFA8C16).withValues(alpha: 0.12),
          const Color(0xFFD46B08),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final permissions = _permissions;

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.agentPermissionsTitle,
        actions: [
          IconButton(
            tooltip: l.agentPermissionsRestoreDefaults,
            icon: Icon(
              Icons.restart_alt_rounded,
              size: 22.0,
              color: OriginTokens.textSecondary(context),
            ),
            onPressed: _writing.isNotEmpty || _isRestoring
                ? null
                : _restoreDefaults,
          ),
          const SizedBox(width: 4.0),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 12.0),

                // 顶部安全提示卡片
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OriginTokens.cardMargin,
                  ),
                  child: OriginCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(14.0),
                    color: OriginTokens.cardSecondary(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 22.0,
                          color: OriginTokens.primary(context),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            l.agentPermissionsIntro,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: OriginTokens.textSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OriginTokens.cardMargin,
                    ),
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13.0,
                          color: OriginTokens.expenseRed,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16.0),

                // 分组一：数据查询（只读工具）
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OriginTokens.cardMargin,
                    vertical: 4.0,
                  ),
                  child: Text(
                    l.agentPermissionsReadOnlySection,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ),
                ),
                OriginSettingGroup(
                  items: [
                    for (final d in AgentToolPermissionCatalog.descriptors
                        .where((d) => !d.mutatesLocalData))
                      _buildPermissionItem(context, d, permissions),
                  ],
                ),

                const SizedBox(height: 20.0),

                // 分组二：账目操作（写入与修改工具）
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OriginTokens.cardMargin,
                    vertical: 4.0,
                  ),
                  child: Text(
                    l.agentPermissionsWriteSection,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ),
                ),
                OriginSettingGroup(
                  items: [
                    for (final d in AgentToolPermissionCatalog.descriptors
                        .where((d) => d.mutatesLocalData))
                      _buildPermissionItem(context, d, permissions),
                  ],
                ),

                const SizedBox(height: 36.0),
              ],
            ),
    );
  }

  OriginSettingItem _buildPermissionItem(
    BuildContext context,
    AgentToolPermissionDescriptor descriptor,
    Map<String, AgentToolPermission>? permissions,
  ) {
    final l = AppLocalizations.of(context);
    final toolName = descriptor.toolName;
    final currentPerm =
        permissions?[toolName] ?? descriptor.defaultPermission;
    final isBusy = _writing.contains(toolName) || _isRestoring;

    return OriginSettingItem(
      title: AgentToolPresentation.label(l, toolName),
      subtitle: AgentToolPresentation.description(l, toolName),
      trailing: isBusy
          ? const SizedBox(
              width: 16.0,
              height: 16.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          : _buildPermissionBadge(context, currentPerm),
      onTap: isBusy
          ? null
          : () => _showPermissionChoice(descriptor, currentPerm),
    );
  }
}
