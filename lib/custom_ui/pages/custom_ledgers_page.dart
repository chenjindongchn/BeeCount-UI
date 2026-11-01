import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show CloudBackendType;
import 'package:beecount_ui/beecount_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ledger_display_item.dart';
import '../../pages/budget/budget_page.dart';
import '../../pages/cloud/join_shared_ledger_page.dart';
import '../../pages/main/ledgers/widgets/ledger_card.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/format_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_menu.dart';

/// vivo OriginOS 风格自定义账本管理页面 (CustomLedgersPage)
///
/// 核心特性：
/// 1. 底部提供符合 OriginUI 规范的胶囊创建按钮，右上角集成快速刷新入口；
/// 2. 新建账本采用标准 OriginDialog 贴底弹窗，包含平滑滑入、软键盘避让与单选币种交互；
/// 3. 复用已有 LedgerCard 及底层数据驱动，保持上游 upstream 零冲突。
class CustomLedgersPage extends ConsumerStatefulWidget {
  const CustomLedgersPage({super.key, this.autoOpenCreateDialog = false});

  final bool autoOpenCreateDialog;

  @override
  ConsumerState<CustomLedgersPage> createState() => _CustomLedgersPageState();
}

class _CustomLedgersPageState extends ConsumerState<CustomLedgersPage> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCreateDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCreateDialog();
      });
    }
  }

  Future<void> _handleTap(LedgerDisplayItem ledger) async {
    final l = AppLocalizations.of(context);
    ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
    ref.invalidate(cachedTransactionsWithCategoryProvider);
    showBeeToast(
      context,
      l.ledgersSwitched(translateLedgerName(context, ledger.name)),
      tone: BeeTone.success,
    );
  }

  Future<void> _showCreateDialog() async {
    final currency = ref.read(baseCurrencyProvider);
    await showOriginCustomDialog<bool>(
      context,
      child: _OriginCreateLedgerDialog(initialCurrency: currency),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currentId = ref.watch(currentLedgerIdProvider);
    final localAsync = ref.watch(localLedgersProvider);
    final remoteAsync = ref.watch(remoteLedgersProvider);
    final beeCloud = ref.watch(activeCloudConfigProvider).valueOrNull?.type ==
        CloudBackendType.beecountCloud;

    final local = localAsync.valueOrNull ?? [];
    final remote = remoteAsync.valueOrNull ?? [];
    final empty = local.isEmpty &&
        remote.isEmpty &&
        !remoteAsync.isLoading &&
        !remoteAsync.hasError;

    final primaryColor = Theme.of(context).colorScheme.primary;

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.ledgersTitle,
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: l.ledgersCreate,
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _showCreateDialog,
          ),
          OriginMoreButton(
            items: [
              OriginMenuItem(
                title: l.ledgersCreate,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onTap: _showCreateDialog,
              ),
              OriginMenuItem(
                title: '刷新账本',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onTap: () =>
                    ref.read(ledgerListRefreshProvider.notifier).state++,
              ),
            ],
          ),
        ],
      ),
      body: localAsync.isLoading && local.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                OriginTokens.cardMargin,
                8.0,
                OriginTokens.cardMargin,
                24.0,
              ),
              children: [
                if (beeCloud) ...[
                  OriginCard(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const JoinSharedLedgerPage(),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(OriginTokens.cardRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.group_add_outlined,
                              size: 22,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.sharedJoinPageTitle,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                  color: OriginTokens.textPrimary(context),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: OriginTokens.textTertiary(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (empty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0),
                    child: Center(
                      child: Text(
                        l.ledgersEmpty,
                        style: TextStyle(
                          color: OriginTokens.textTertiary(context),
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ),
                ],
                if (local.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 4.0,
                      top: 4.0,
                      bottom: 8.0,
                    ),
                    child: Text(
                      '${l.ledgersLocal} (${local.length})',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: OriginTokens.textTertiary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...local.map(
                    (ledger) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: LedgerCard(
                        ledger: ledger,
                        selected: ledger.id == currentId,
                        onTap: () => _handleTap(ledger),
                        onBudget: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BudgetPage(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // 移动到最底部的创建账本按钮
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: OriginTokens.buttonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            OriginTokens.buttonRadius,
                          ),
                        ),
                      ),
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        l.ledgersCreate,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// vivo OriginOS 风格新建账本对话框 (OriginCreateLedgerDialog)
class _OriginCreateLedgerDialog extends ConsumerStatefulWidget {
  final String initialCurrency;

  const _OriginCreateLedgerDialog({
    required this.initialCurrency,
  });

  @override
  ConsumerState<_OriginCreateLedgerDialog> createState() =>
      _OriginCreateLedgerDialogState();
}

class _OriginCreateLedgerDialogState
    extends ConsumerState<_OriginCreateLedgerDialog> {
  late final TextEditingController _nameController;
  late String _selectedCurrency;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _selectedCurrency = widget.initialCurrency;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickCurrency() async {
    final l = AppLocalizations.of(context);
    final chosen = await showOriginChoiceDialog<String>(
      context,
      title: l.ledgersCurrency,
      selected: _selectedCurrency,
      options: const [
        OriginChoiceOption(value: 'CNY', title: '人民币 (CNY)', subtitle: '¥'),
        OriginChoiceOption(value: 'USD', title: '美元 (USD)', subtitle: '\$'),
        OriginChoiceOption(value: 'EUR', title: '欧元 (EUR)', subtitle: '€'),
        OriginChoiceOption(value: 'HKD', title: '港币 (HKD)', subtitle: 'HK\$'),
        OriginChoiceOption(value: 'JPY', title: '日元 (JPY)', subtitle: '¥'),
      ],
    );
    if (chosen != null && mounted) {
      setState(() => _selectedCurrency = chosen);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.ledgersName);
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(repositoryProvider);
      final id = await repo.createLedger(
        name: name,
        currency: _selectedCurrency,
      );

      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        ref.read(currentLedgerIdProvider.notifier).state = id;
        ref.invalidate(currentLedgerProvider);
      }

      ref.read(ledgerListRefreshProvider.notifier).state++;
      unawaited(PostProcessor.sync(ref, ledgerId: id));

      if (mounted) {
        showBeeToast(context, '账本创建成功', tone: BeeTone.success);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '创建失败: $e', tone: BeeTone.error);
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: OriginDialog(
        alignment: Alignment.bottomCenter,
        title: l.ledgersCreate,
        textAlign: TextAlign.center,
        confirmText: _submitting ? '...' : l.commonConfirm,
        onConfirm: _submit,
        cancelText: l.commonCancel,
        onCancel: () => Navigator.of(context).pop(false),
        stackActions: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12.0),
            // 账本名称输入槽
            Container(
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                borderRadius: BorderRadius.circular(14.0),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 10.0,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 20.0,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 10.0),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 15.0,
                        color: OriginTokens.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: '例如：日常开销、旅游账本',
                        hintStyle: TextStyle(
                          fontSize: 14.0,
                          color: OriginTokens.textTertiary(context),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) {
                        if (_error != null) {
                          setState(() => _error = null);
                        }
                      },
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _nameController,
                    builder: (_, val, __) {
                      if (val.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          _nameController.clear();
                          if (_error != null) {
                            setState(() => _error = null);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 18.0,
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6.0),
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.0,
                    color: OriginTokens.expenseRed,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12.0),
            // 结算币种选择行
            Container(
              decoration: BoxDecoration(
                color: OriginTokens.cardSecondary(context),
                borderRadius: BorderRadius.circular(14.0),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14.0),
                  onTap: _pickCurrency,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.currency_exchange_rounded,
                              size: 20.0,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 10.0),
                            Text(
                              l.ledgersCurrency,
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w500,
                                color: OriginTokens.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                _selectedCurrency,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18.0,
                              color: OriginTokens.textTertiary(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
