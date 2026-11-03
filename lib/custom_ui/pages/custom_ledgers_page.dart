import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' show CloudBackendType;
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/ledger_display_item.dart';
import '../../pages/cloud/join_shared_ledger_page.dart';
import 'custom_budget_page.dart';
import '../../pages/main/ledgers/widgets/ledger_card.dart';
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../../utils/format_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_text_field.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_empty_state.dart';

/// vivo OriginOS 风格自定义账本管理页面 (CustomLedgersPage)
///
/// 核心特性：
/// 1. 底部提供符合 OriginUI 规范的置底大胶囊创建按钮，右上角集成快速刷新入口；
/// 2. 新建账本采用标准 OriginUI 底部滑升动效与纯净输入槽（去除 Material 浮动标签），视觉与手感全局统一；
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

  Future<void> _handleBudget(LedgerDisplayItem ledger) async {
    if (ref.read(currentLedgerIdProvider) != ledger.id) {
      ref.read(currentLedgerIdProvider.notifier).state = ledger.id;
      ref.invalidate(currentLedgerProvider);
      ref.invalidate(cachedTransactionsWithCategoryProvider);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomBudgetPage(),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final l = AppLocalizations.of(context);
    final initialCurrency = ref.read(baseCurrencyProvider);
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();

    final result = await showOriginCustomDialog<({String name, String currency, int monthStartDay})>(
      context,
      child: _CustomLedgerEditorDialog(
        title: l.ledgersNew,
        name: '',
        currency: initialCurrency,
        day: 1,
      ),
    );

    if (result == null || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final newLedgerId =
          await ref.read(databaseProvider).transaction(() async {
        final id = await repo.createLedger(
          name: result.name.trim(),
          currency: result.currency,
        );
        if (result.monthStartDay != 1) {
          await repo.updateLedger(id: id, monthStartDay: result.monthStartDay);
        }
        return id;
      });

      if (!mounted) return;
      final currentLedger = await ref.read(currentLedgerProvider.future);
      if (currentLedger == null) {
        ref.read(currentLedgerIdProvider.notifier).state = newLedgerId;
        ref.invalidate(currentLedgerProvider);
      }

      ref.read(ledgerListRefreshProvider.notifier).state++;
      PostProcessor.sync(ref, ledgerId: newLedgerId);

      if (!mounted) return;
      showBeeToast(context, '账本创建成功');
    } catch (e) {
      if (!mounted) return;
      showBeeToast(context, '创建失败: $e');
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
            tooltip: '刷新账本',
            icon: const Icon(Icons.refresh_rounded, size: 24),
            onPressed: () =>
                ref.read(ledgerListRefreshProvider.notifier).state++,
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
                  OriginEmptyState(
                    iconData: Icons.auto_stories_outlined,
                    title: l.ledgersEmpty,
                    message: '点击下方按钮新建账本，开始记录您的财务收支',
                    bottomSpacing: 12.0,
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
                        onBudget: () => _handleBudget(ledger),
                      ),
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OriginTokens.cardMargin,
            vertical: 12.0,
          ),
          child: SizedBox(
            height: OriginTokens.buttonHeight,
            child: ElevatedButton(
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
              child: Text(
                l.ledgersCreate,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 账本创建/编辑对话框 (遵循 OriginOS 对话框规范，全套采用 OriginDialog + OriginTextField)
class _CustomLedgerEditorDialog extends StatefulWidget {
  const _CustomLedgerEditorDialog({
    this.title,
    required this.name,
    required this.currency,
    required this.day,
  });

  final String? title;
  final String name, currency;
  final int day;

  @override
  State<_CustomLedgerEditorDialog> createState() =>
      _CustomLedgerEditorDialogState();
}

class _CustomLedgerEditorDialogState extends State<_CustomLedgerEditorDialog> {
  late final controller = TextEditingController(text: widget.name);
  late String currency = widget.currency;
  late int day = widget.day;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);

    return OriginDialog(
      title: widget.title ?? l.ledgersEdit,
      textAlign: TextAlign.center,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 纯净账本名称输入框（无 Floating Label，垂直居中纯净占位引导，带一键清空）
          OriginTextField(
            controller: controller,
            hintText: '请输入账本名称',
            clearable: true,
            borderRadius: 14.0,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            backgroundColor: OriginTokens.cardSecondary(context),
          ),
          const SizedBox(height: 12.0),
          // 币种与账期属性卡片
          Container(
            decoration: BoxDecoration(
              color: OriginTokens.cardSecondary(context),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!globalCurrencyLocked) ...[
                  _DialogPreferenceRow(
                    icon: Icons.monetization_on_outlined,
                    title: l.ledgerBaseCurrencyLabel,
                    value: displayCurrency(currency, context),
                    onTap: () async {
                      final code = await showCurrencyPickerSheet(
                        context,
                        selected: currency,
                        primaryColor: primaryColor,
                        title: l.ledgersSelectCurrency,
                      );
                      if (mounted && code != null) setState(() => currency = code);
                    },
                  ),
                  const OriginDivider(startIndent: 44.0, endIndent: 12.0),
                ],
                _DialogPreferenceRow(
                  icon: Icons.calendar_today_outlined,
                  title: l.ledgersMonthStartDay,
                  value: day == 1
                      ? l.ledgersMonthStartDayNatural
                      : l.ledgersMonthStartDayValue(day),
                  onTap: () async {
                    final selected = await showBeeSheet<int>(
                      context,
                      title: l.ledgersMonthStartDay,
                      child: SingleChildScrollView(
                        child: BeeMonthStartDayGrid(
                          value: day,
                          hint: l.ledgersMonthStartDayHint,
                          onSelected: (day) => Navigator.pop(context, day),
                        ),
                      ),
                    );
                    if (mounted && selected != null) setState(() => day = selected);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      customActions: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final isValid = value.text.trim().isNotEmpty;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final disabledBg =
                isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E5E7);
            final disabledFg =
                isDark ? const Color(0xFF666666) : const Color(0xFF9E9E9E);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OriginDialogCapsuleButton(
                  text: widget.title == l.ledgersNew
                      ? l.ledgersCreate
                      : l.commonSave,
                  backgroundColor: isValid ? primaryColor : disabledBg,
                  textColor: isValid ? Colors.white : disabledFg,
                  isPrimary: true,
                  onPressed: () {
                    if (!isValid) return;
                    Navigator.of(context).pop((
                      name: value.text.trim(),
                      currency: currency,
                      monthStartDay: day,
                    ));
                  },
                ),
                const SizedBox(height: 12.0),
                OriginDialogCapsuleButton(
                  text: l.commonCancel,
                  backgroundColor: OriginTokens.dialogButtonSecondary(context),
                  textColor: OriginTokens.textPrimary(context),
                  isPrimary: false,
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DialogPreferenceRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _DialogPreferenceRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  State<_DialogPreferenceRow> createState() => _DialogPreferenceRowState();
}

class _DialogPreferenceRowState extends State<_DialogPreferenceRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pressedBg =
        isDark ? const Color(0xFF333333) : const Color(0xFFEDEDED);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: _isPressed ? pressedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14.0),
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: 20.0,
              color: OriginTokens.primary(context),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: OriginTokens.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 13.5,
                color: OriginTokens.textSecondary(context),
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
      ),
    );
  }
}
