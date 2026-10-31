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
import '../widgets/origin_menu.dart';
import '../widgets/origin_card.dart';

/// vivo OriginOS 风格自定义账本管理页面 (CustomLedgersPage)
///
/// 核心特性：
/// 1. 右上角统一接入 2 个点入口 (OriginMoreButton)，点击呼出高质感展开式气泡菜单；
/// 2. 气泡菜单集成：新建账本、刷新列表等；
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
    final l = AppLocalizations.of(context);
    final nameController = TextEditingController();
    var selectedCurrency = ref.read(baseCurrencyProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OriginTokens.dialogRadius),
          ),
          title: Text(l.ledgersCreate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l.ledgersName,
                  hintText: '例如：日常开销、旅游账本',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.ledgersCurrency),
                  TextButton(
                    onPressed: () {
                      final currencies = ['CNY', 'USD', 'EUR', 'HKD', 'JPY'];
                      final idx = currencies.indexOf(selectedCurrency);
                      final next = currencies[(idx + 1) % currencies.length];
                      setDialogState(() => selectedCurrency = next);
                    },
                    child: Text(
                      selectedCurrency,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.commonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.commonConfirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final repo = ref.read(repositoryProvider);
      final id = await repo.createLedger(
        name: name,
        currency: selectedCurrency,
      );

      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        ref.read(currentLedgerIdProvider.notifier).state = id;
        ref.invalidate(currentLedgerProvider);
      }

      ref.read(ledgerListRefreshProvider.notifier).state++;
      unawaited(PostProcessor.sync(ref, ledgerId: id));

      if (!mounted) return;
      showBeeToast(context, '账本创建成功', tone: BeeTone.success);
    } catch (e) {
      if (!mounted) return;
      showBeeToast(context, '创建失败: $e', tone: BeeTone.error);
    }
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
              ],
            ),
    );
  }
}
