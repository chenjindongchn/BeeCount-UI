import 'dart:convert';

import 'package:agentcore/agentcore.dart' show AgentNativeModelPhase;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agent_ui/flutter_agent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../agent/permission/agent_authorization_gate.dart';
import '../../ai/core/bill_info.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../models/assistant_execution_metadata.dart';
import '../../models/assistant_follow_up_metadata.dart';
import '../../pages/ai/agent_message_visibility.dart';
import '../../pages/ai/ai_settings_page.dart';
import 'custom_ai_settings_page.dart';
import '../../pages/ai/chat/bindings/agent_execution_timeline.dart';
import '../../pages/shared/selectors/ledger_selector_dialog.dart';
import '../../pages/transaction/transaction_editor_page.dart';
import '../../providers.dart';
import '../../providers/ai_chat_providers.dart';
import '../../services/ai/agent_app_facade.dart';
import '../../services/ai/ai_chat_service.dart';
import '../../services/ai/bill_card_info_builder.dart';
import '../../services/billing/post_processor.dart';
import '../../services/system/logger_service.dart';
import '../../utils/image_billing_helper.dart';
import '../../utils/voice_billing_helper.dart';
import '../styles/origin_tokens.dart';
import '../widgets/ai/origin_ai_empty_state.dart';
import '../widgets/ai/origin_ai_input_dock.dart';
import '../widgets/ai/origin_ai_message_bubble.dart';
import '../widgets/ai/origin_bill_card.dart';
import '../widgets/ai/origin_tool_authorization_dialog.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_scaffold.dart';

/// vivo OriginOS / 蓝心小V 风格 AI 智能记账助手页面 (CustomAIChatPage)
///
/// 遵循设计哲学与开发铁律：
/// 1. 100% 保持蓝心小V视觉精髓：去卡片化通透气泡、全圆弧悬浮大胶囊输入 Dock、大标题向导页；
/// 2. 100% 保留 BeeCount 原有的记账核心入口、多账本支持、撤销/编辑、云同步与权限配置；
/// 3. 逻辑完全复用 Riverpod 既有状态，不涂改核心数据库与业务算法。
class CustomAIChatPage extends ConsumerStatefulWidget {
  const CustomAIChatPage({super.key});

  @override
  ConsumerState<CustomAIChatPage> createState() => _CustomAIChatPageState();
}

class _CustomAIChatPageState extends ConsumerState<CustomAIChatPage>
    with WidgetsBindingObserver {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AIChatService _chatService;
  late final AgentConversationScrollCoordinator _chatScrollCoordinator =
      AgentConversationScrollCoordinator(_scrollController);

  int? _conversationId;
  bool _isLoading = false;
  AIConfigValidationResult? _apiValidation;
  bool _followLatest = true;
  bool _isUserScrolling = false;
  bool _isFirstLoad = true;
  bool _hasLiveAgentMessage = false;
  String _streamingAgentText = '';
  AgentNativeModelPhase? _agentModelPhase;
  List<AgentExecutionStep> _agentExecutionSteps = const [];
  AIResponse? _liveAgentResponse;
  int? _liveAssistantMessageId;
  String? _activeAgentRunId;
  bool _isAuthorizationDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _chatService = ref.read(aiChatServiceProvider);
    WidgetsBinding.instance.addObserver(this);
    _initConversation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateApiConfig();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _validateApiConfig();
    }
  }

  Future<void> _validateApiConfig() async {
    try {
      final result = await AIChatService.validateApiKey();
      if (!mounted) return;
      setState(() => _apiValidation = result);
    } catch (e, st) {
      logger.error('AIChat', 'API 配置检查失败', e, st);
      if (!mounted) return;
      setState(() {
        _apiValidation = AIConfigValidationResult.invalid('配置检查失败');
      });
    }
  }

  Future<void> _initConversation() async {
    final repo = ref.read(repositoryProvider);
    final activeConv = await repo.getActiveConversation();

    if (activeConv != null) {
      if (mounted) {
        setState(() {
          _conversationId = activeConv.id;
        });
      }
    } else {
      final newId = await repo.createConversation(
        ConversationsCompanion.insert(
          title: Value('新对话'),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (mounted) {
        setState(() {
          _conversationId = newId;
        });
      }
    }

    if (!mounted || _conversationId == null) return;
    ref.read(currentConversationIdProvider.notifier).state = _conversationId;
  }

  @override
  Widget build(BuildContext context) {
    if (_conversationId == null) {
      return const OriginScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(_conversationId!));
    final l10n = AppLocalizations.of(context);

    return OriginScaffold(
      resizeToAvoidBottomInset: true,
      appBar: OriginSmallTopAppBar(
        title: l10n.aiChatTitle,
        actions: [
          // vivo OriginOS 规范顶栏两个点设置入口
          IconButton(
            tooltip: l10n.agentAssistantSettingsTitle,
            icon: OriginMoreIcon(
              size: 20.0,
              color: OriginTokens.textPrimary(context),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomAISettingsPage(
                  ledgerId: ref.read(currentLedgerIdProvider),
                  conversationId: _conversationId,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4.0),
        ],
      ),
      body: Column(
        children: [
          // API 配置警告横幅
          if (_apiValidation != null && !_apiValidation!.isValid)
            _buildApiWarningBanner(context),

          // 对话主视图
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                final displayMessages = AgentMessageVisibility.forLiveResponse(
                  messages,
                  liveResponse: _liveAgentResponse,
                  persistedMessageId: _liveAssistantMessageId,
                );

                if (_isFirstLoad && displayMessages.isNotEmpty) {
                  _isFirstLoad = false;
                  _chatScrollCoordinator.requestInitialPositioning();
                }

                if (displayMessages.isEmpty && !_hasLiveAgentMessage) {
                  return OriginAiEmptyState(
                    onSelectPrompt: (prompt) => _sendMessageText(prompt),
                  );
                }

                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth != 0) return false;
                    if (notification is ScrollStartNotification &&
                        notification.dragDetails != null) {
                      _isUserScrolling = true;
                      _followLatest = false;
                      _chatScrollCoordinator.onUserScroll();
                    }
                    if (notification is ScrollEndNotification && _isUserScrolling) {
                      _isUserScrolling = false;
                      _followLatest = _scrollController.hasClients &&
                          _scrollController.position.extentAfter <= 50;
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayMessages.length +
                        (_hasLiveAgentMessage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == displayMessages.length) {
                        return _buildLiveAgentBubble();
                      }

                      final message = displayMessages[index];
                      return _buildMessageItem(message);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('加载失败: $err')),
            ),
          ),

          // 提示语：移动到输入框上方固定居中
          _buildFooterNotice(context),

          // 蓝心小V同款：悬浮胶囊输入 Dock
          OriginAiInputDock(
            controller: _inputController,
            isLoading: _isLoading,
            onSend: _sendMessage,
            onStop: _stopCurrentAgentRun,
            onTakePhoto: () => ImageBillingHelper.openCameraForBilling(context, ref),
            onPickImage: () => ImageBillingHelper.pickImageForBilling(context, ref),
            onVoice: () => VoiceBillingHelper.startVoiceBilling(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildApiWarningBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 6.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF332015) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isDark ? const Color(0xFF664422) : const Color(0xFFFFD591),
          width: OriginTokens.hairline,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16.0,
            color: Color(0xFFFA8C16),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              l10n.aiChatConfigWarning,
              style: TextStyle(
                fontSize: 12.0,
                color: OriginTokens.textPrimary(context),
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AISettingsPage()),
              );
              if (mounted) await _validateApiConfig();
            },
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(
                l10n.aiChatGoToSettings,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFA8C16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNotice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
      child: Center(
        child: Text(
          '内容由 AI 生成，请核对重要财务信息',
          style: TextStyle(
            fontSize: 11.0,
            color: OriginTokens.textTertiary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(Message message) {
    // 记账结果卡片类型
    if (message.messageType == 'bill_card' && message.metadata != null) {
      final parsed = _parseBillMetadata(message);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < parsed.bills.length; i++)
            OriginBillCard(
              billInfo: parsed.bills[i],
              transactionId: i < parsed.txIds.length ? parsed.txIds[i] : null,
              isUndone: i < parsed.txIds.length &&
                  parsed.undoneIds.contains(parsed.txIds[i]),
              onUndo: i < parsed.txIds.length &&
                      !parsed.undoneIds.contains(parsed.txIds[i])
                  ? () => _handleUndoOne(message.id, parsed.txIds[i])
                  : null,
              onEdit: i < parsed.txIds.length &&
                      !parsed.undoneIds.contains(parsed.txIds[i])
                  ? () => _handleEdit(message.id, parsed.txIds[i])
                  : null,
              onChangeLedger: i < parsed.txIds.length &&
                      !parsed.undoneIds.contains(parsed.txIds[i])
                  ? () => _handleChangeLedger(message.id, parsed.txIds[i])
                  : null,
            ),
        ],
      );
    }

    // 用户消息
    if (message.role == 'user') {
      return OriginAiMessageBubble(
        content: message.content,
        isUser: true,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: message.content));
          _showToast(AppLocalizations.of(context).aiChatCopied);
        },
        onDelete: () => _deleteMessage(message),
      );
    }

    // AI 助手回复
    return OriginAiMessageBubble(
      content: message.content,
      isUser: false,
      onCopy: () {
        Clipboard.setData(ClipboardData(text: message.content));
        _showToast(AppLocalizations.of(context).aiChatCopied);
      },
      onDelete: () => _deleteMessage(message),
      extraContent: _buildActivityTimeline(message),
    );
  }

  Widget? _buildActivityTimeline(Message message) {
    final steps = AssistantExecutionMetadata.decode(message.metadata);
    if (steps.isEmpty) return null;
    return Container(
      margin: const EdgeInsets.only(top: 6.0, bottom: 4.0),
      child: AgentExecutionTimeline(
        key: ValueKey('execution-${message.id}'),
        steps: const [],
        displaySteps: steps,
        isStreaming: false,
      ),
    );
  }

  Widget _buildLiveAgentBubble() {
    final response = _liveAgentResponse;
    if (response != null) {
      if (response.type == 'bill_card' && response.bills.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < response.bills.length; index++)
              OriginBillCard(
                billInfo: response.bills[index],
                transactionId: index < response.transactionIds.length
                    ? response.transactionIds[index]
                    : null,
              ),
          ],
        );
      }
      return OriginAiMessageBubble(
        content: response.text,
        isUser: false,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: response.text));
          _showToast(AppLocalizations.of(context).aiChatCopied);
        },
      );
    }

    // 流式生成与思考中
    return OriginAiMessageBubble(
      content: _streamingAgentText,
      isUser: false,
      extraContent: AgentExecutionTimeline(
        key: ValueKey('execution-live-$_activeAgentRunId'),
        steps: _agentExecutionSteps,
        isStreaming: _isLoading,
        streamingText: _streamingAgentText,
        modelPhase: _agentModelPhase,
      ),
    );
  }

  void _stopCurrentAgentRun() {
    final runId = _activeAgentRunId;
    if (!_isLoading || runId == null) return;
    _chatService.cancelAgentRun(runId);
    if (_isAuthorizationDialogOpen && mounted) {
      Navigator.of(context).pop(AgentToolAuthorizationChoice.deny);
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (!mounted || text.isEmpty || _isLoading) return;
    _inputController.clear();
    await _sendMessageText(text);
  }

  Future<void> _sendMessageText(String text, {bool readOnly = false}) async {
    if (!mounted || text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _followLatest = true;
      _isUserScrolling = false;
    });

    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'user',
          content: text,
          messageType: 'text',
          metadata: Value(jsonEncode({'contextLedgerId': ledgerId})),
          createdAt: Value(DateTime.now()),
        ),
      );
      if (!mounted) return;

      _scrollToBottom();

      final chatService = _chatService;
      final currentLocale = Localizations.localeOf(context);
      final l10n = AppLocalizations.of(context);
      final agentRunId = const Uuid().v4();

      setState(() {
        _hasLiveAgentMessage = true;
        _streamingAgentText = '';
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
        _activeAgentRunId = agentRunId;
      });
      _scrollToBottom();

      AIResponse? response;
      await for (final event in chatService.processMessageEvents(
        text,
        ledgerId: ledgerId,
        runId: agentRunId,
        conversationId: _conversationId,
        languageCode: currentLocale.languageCode,
        l10n: l10n,
        readOnly: readOnly,
      )) {
        if (!mounted) break;
        switch (event) {
          case AgentModelActivityEvent(:final phase):
            setState(() => _agentModelPhase = phase);
          case AgentTextDeltaEvent(:final text):
            setState(() {
              _streamingAgentText += text;
              _agentModelPhase = AgentNativeModelPhase.generating;
            });
          case AgentToolAuthorizationRequestedEvent(:final request):
            setState(() {
              _agentModelPhase = null;
              _agentExecutionSteps = [
                ..._agentExecutionSteps,
                AgentExecutionStep(
                  toolName: request.toolName,
                  arguments: request.arguments,
                  status: AgentExecutionStepStatus.waiting,
                ),
              ];
            });
            _isAuthorizationDialogOpen = true;
            final choice = mounted
                ? await showOriginToolAuthorizationDialog(
                    context: context,
                    request: request,
                  )
                : AgentToolAuthorizationChoice.deny;
            _isAuthorizationDialogOpen = false;
            chatService.resolveToolAuthorization(request.authorizationId, choice);
          case AgentToolStartedEvent(:final toolName, :final callId, :final arguments):
            setState(() {
              _agentModelPhase = null;
              _agentExecutionSteps = _updateExecutionStep(
                toolName: toolName,
                callId: callId,
                arguments: arguments,
                status: AgentExecutionStepStatus.running,
              );
            });
          case AgentToolCompletedEvent(
              :final toolName,
              :final callId,
              :final arguments,
              :final result,
              :final error,
              :final succeeded,
            ):
            setState(() {
              _agentExecutionSteps = _updateExecutionStep(
                toolName: toolName,
                callId: callId,
                arguments: arguments,
                status: succeeded
                    ? AgentExecutionStepStatus.completed
                    : AgentExecutionStepStatus.failed,
                result: result,
                error: error,
              );
            });
          case AgentRunCompletedEvent(:final result):
            response = result.response;
        }
        _scrollToBottomSmooth();
      }

      if (!mounted) return;
      response ??= AIResponse.error(l10n.agentRunFailed);
      setState(() => _liveAgentResponse = response);

      final assistantMessageId = await repo.createMessage(
        MessagesCompanion.insert(
          conversationId: _conversationId!,
          role: 'assistant',
          content: response.text,
          messageType: response.type,
          metadata: _responseMetadata(response, ledgerId),
          transactionId: response.transactionId != null
              ? Value(response.transactionId)
              : const Value.absent(),
          createdAt: Value(DateTime.now()),
        ),
      );
      if (!mounted) return;

      setState(() {
        _liveAssistantMessageId = assistantMessageId;
        if (_followLatest) _chatScrollCoordinator.request();
      });

      if (response.type == 'bill_card' && response.transactionId != null) {
        ref.read(statsRefreshProvider.notifier).state++;
        final billLedgerId = response.billInfo?.ledgerId ?? ledgerId;
        await PostProcessor.sync(ref, ledgerId: billLedgerId);
      }

      if (!mounted) return;
      setState(() {
        _hasLiveAgentMessage = false;
        _streamingAgentText = '';
        _agentModelPhase = null;
        _agentExecutionSteps = const [];
        _liveAgentResponse = null;
        _liveAssistantMessageId = null;
      });
    } catch (e) {
      if (mounted) _showToast('发送失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLiveAgentMessage = false;
          _streamingAgentText = '';
          _agentModelPhase = null;
          _agentExecutionSteps = const [];
          _liveAgentResponse = null;
          _liveAssistantMessageId = null;
          _activeAgentRunId = null;
          _isAuthorizationDialogOpen = false;
        });
      }
    }
  }

  Value<String?> _responseMetadata(AIResponse response, int ledgerId) {
    final metadata = <String, Object?>{
      'contextLedgerId': ledgerId,
      'analysisTemplatesAllowed': response.allowPromptSuggestions,
    };
    metadata.addAll(AssistantExecutionMetadata.encode(
      AgentExecutionTimeline.projectSteps(
        AppLocalizations.of(context),
        _agentExecutionSteps,
        finished: true,
      ),
    ));
    if (response.bills.isNotEmpty) {
      metadata.addAll(Map<String, Object?>.from(jsonDecode(_encodeBillMetadata(
        response.bills,
        response.transactionIds,
        const <int>{},
      )) as Map));
    }
    if (response.action != null) metadata['action'] = response.action!.name;
    if (response.followUpSuggestions.isNotEmpty) {
      metadata.addAll(AssistantFollowUpMetadata.encode(
        response.followUpSuggestions,
        ledgerId: ledgerId,
      ));
    }
    return metadata.isEmpty ? const Value.absent() : Value(jsonEncode(metadata));
  }

  List<AgentExecutionStep> _updateExecutionStep({
    required String toolName,
    required String callId,
    required Map<String, Object?> arguments,
    required AgentExecutionStepStatus status,
    Map<String, Object?>? result,
    String? error,
  }) {
    final steps = [..._agentExecutionSteps];
    var index = -1;
    if (callId.isNotEmpty) {
      for (var i = steps.length - 1; i >= 0; i--) {
        if (steps[i].callId == callId) {
          index = i;
          break;
        }
      }
    }
    if (index < 0) {
      for (var i = steps.length - 1; i >= 0; i--) {
        final candidate = steps[i];
        if (candidate.toolName == toolName &&
            (candidate.status == AgentExecutionStepStatus.waiting ||
                candidate.status == AgentExecutionStepStatus.running)) {
          index = i;
          break;
        }
      }
    }

    final current = index >= 0 ? steps[index] : null;
    final next = AgentExecutionStep(
      toolName: toolName,
      arguments: arguments.isEmpty ? (current?.arguments ?? arguments) : arguments,
      callId: callId.isEmpty ? current?.callId : callId,
      status: status,
      result: result,
      error: error,
    );
    if (index >= 0) {
      steps[index] = next;
    } else {
      steps.add(next);
    }
    return steps;
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted && _followLatest) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomSmooth() {
    if (!_followLatest) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted && _followLatest) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _handleUndoOne(int messageId, int transactionId) async {
    final success = await _chatService.undoTransaction(transactionId);
    if (!success) {
      if (mounted) _showToast(AppLocalizations.of(context).aiChatUndoFailed);
      return;
    }

    final repo = ref.read(repositoryProvider);
    final message = await repo.getMessageById(messageId);
    if (message == null || message.metadata == null) {
      if (mounted) _showToast(AppLocalizations.of(context).aiChatUndone);
      return;
    }

    final parsed = _parseBillMetadata(message);
    final newUndone = {...parsed.undoneIds, transactionId};
    await repo.updateMessage(message.copyWith(
      metadata: Value(_encodeBillMetadata(
        parsed.bills,
        parsed.txIds,
        newUndone,
        existingMetadata: message.metadata,
      )),
    ));

    ref.read(statsRefreshProvider.notifier).state++;

    final idx = parsed.txIds.indexOf(transactionId);
    if (idx >= 0 && idx < parsed.bills.length) {
      final ledgerId = parsed.bills[idx].ledgerId;
      if (ledgerId != null) {
        await PostProcessor.sync(ref, ledgerId: ledgerId);
      }
    }

    if (mounted) _showToast(AppLocalizations.of(context).aiChatUndone);
  }

  Future<void> _handleEdit(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final transaction = await repo.getTransactionById(transactionId);
      if (transaction == null) {
        if (mounted) _showToast(AppLocalizations.of(context).aiChatTransactionNotFound);
        return;
      }

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
              initialKind: transaction.type,
              quickAdd: true,
              initialCategoryId: transaction.categoryId,
              initialAmount: transaction.amount,
              initialDate: transaction.happenedAt,
              initialNote: transaction.note,
              editingTransactionId: transaction.id,
              initialAccountId: transaction.accountId,
              initialToAccountId: transaction.toAccountId,
            ),
          ),
        );

        if (mounted) {
          await _refreshBillCard(messageId, transactionId);
        }
      }
    } catch (e) {
      if (mounted) _showToast(AppLocalizations.of(context).aiChatOpenEditorFailed);
    }
  }

  Future<void> _refreshBillCard(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final message = await repo.getMessageById(messageId);
      if (message == null || message.metadata == null) return;

      final transaction = await repo.getTransactionById(transactionId);
      if (transaction == null) return;

      final category = transaction.categoryId == null
          ? null
          : await repo.getCategoryById(transaction.categoryId!);
      final account = transaction.accountId == null
          ? null
          : await repo.getAccount(transaction.accountId!);
      final toAccount = transaction.toAccountId == null
          ? null
          : await repo.getAccount(transaction.toAccountId!);
      final tagsByTransaction = await repo.getTagsForTransactions([transactionId]);
      final updatedBillInfo = buildBillCardInfoFromTransaction(
        amount: transaction.amount,
        time: transaction.happenedAt,
        note: transaction.note,
        category: category?.name,
        transactionType: transaction.type,
        account: account?.name,
        fromAccount: account?.name,
        toAccount: toAccount?.name,
        tags: tagsByTransaction[transactionId]?.map((tag) => tag.name).toList(),
        currency: transaction.currencyCode ?? account?.currency,
        ledgerId: transaction.ledgerId,
      );

      final parsed = _parseBillMetadata(message);
      final idx = parsed.txIds.indexOf(transactionId);
      if (idx < 0 || idx >= parsed.bills.length) return;

      final newBills = List<BillInfo>.from(parsed.bills);
      newBills[idx] = updatedBillInfo;

      await repo.updateMessage(message.copyWith(
        metadata: Value(_encodeBillMetadata(
          newBills,
          parsed.txIds,
          parsed.undoneIds,
          existingMetadata: message.metadata,
        )),
      ));
    } catch (e, st) {
      logger.error('AIChat', '刷新账单卡片失败', e, st);
    }
  }

  Future<void> _handleChangeLedger(int messageId, int transactionId) async {
    try {
      final repo = ref.read(repositoryProvider);
      final transaction = await repo.getTransactionById(transactionId);
      if (transaction == null) {
        if (mounted) _showToast(AppLocalizations.of(context).aiChatTransactionNotFound);
        return;
      }

      if (!mounted) return;
      final selectedLedgerId = await showLedgerSelector(
        context,
        currentLedgerId: transaction.ledgerId,
      );

      if (selectedLedgerId == null || selectedLedgerId == transaction.ledgerId) return;

      await repo.updateTransactionLedger(id: transactionId, ledgerId: selectedLedgerId);

      final message = await repo.getMessageById(messageId);
      if (message != null && message.metadata != null) {
        final parsed = _parseBillMetadata(message);
        final idx = parsed.txIds.indexOf(transactionId);
        if (idx >= 0 && idx < parsed.bills.length) {
          final newBills = List<BillInfo>.from(parsed.bills);
          newBills[idx] = parsed.bills[idx].copyWith(ledgerId: selectedLedgerId);
          await repo.updateMessage(message.copyWith(
            metadata: Value(_encodeBillMetadata(
              newBills,
              parsed.txIds,
              parsed.undoneIds,
              existingMetadata: message.metadata,
            )),
          ));
        }

        ref.read(statsRefreshProvider.notifier).state++;
        await PostProcessor.sync(ref, ledgerId: transaction.ledgerId);
        await PostProcessor.sync(ref, ledgerId: selectedLedgerId);

        if (mounted) setState(() {});
      }

      if (mounted) _showToast(AppLocalizations.of(context).commonSuccess);
    } catch (e) {
      if (mounted) _showToast(AppLocalizations.of(context).commonFailed);
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showOriginConfirmDialog(
      context,
      title: l10n.commonDelete,
      message: l10n.aiChatDeleteMessageConfirm,
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDanger: true,
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(repositoryProvider);
      await repo.deleteMessage(message.id);
      if (mounted) _showToast(l10n.aiChatMessageDeleted);
    } catch (e) {
      if (mounted) _showToast(l10n.commonFailed);
    }
  }

  ({List<BillInfo> bills, List<int> txIds, Set<int> undoneIds})
      _parseBillMetadata(Message m) {
    final raw = jsonDecode(m.metadata!) as Map<String, dynamic>;
    if (raw['bills'] is List) {
      final bills = (raw['bills'] as List)
          .whereType<Map>()
          .map((j) => BillInfo.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      final txIds = ((raw['txIds'] as List?) ?? const []).whereType<int>().toList();
      final undoneIds =
          ((raw['undoneIds'] as List?) ?? const []).whereType<int>().toSet();
      return (bills: bills, txIds: txIds, undoneIds: undoneIds);
    }

    final billJson = raw['billInfo'] is Map
        ? Map<String, dynamic>.from(raw['billInfo'] as Map)
        : raw;
    final bill = BillInfo.fromJson(billJson);
    final txId = m.transactionId;
    final isUndone = raw['isUndone'] == true;
    return (
      bills: [bill],
      txIds: txId != null ? <int>[txId] : <int>[],
      undoneIds: (isUndone && txId != null) ? <int>{txId} : <int>{},
    );
  }

  String _encodeBillMetadata(
    List<BillInfo> bills,
    List<int> txIds,
    Set<int> undoneIds, {
    String? existingMetadata,
  }) {
    return jsonEncode({
      if (existingMetadata != null)
        ...jsonDecode(existingMetadata) as Map<String, dynamic>,
      'bills': bills.map((b) => b.toJson()).toList(),
      'txIds': txIds,
      'undoneIds': undoneIds.toList(),
    });
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final runId = _activeAgentRunId;
    if (runId != null) _chatService.cancelAgentRun(runId);
    _inputController.dispose();
    _chatScrollCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
