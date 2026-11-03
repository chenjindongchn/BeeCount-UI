import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beecount_ui/beecount_ui.dart' show showBeeToast, BeeTone;

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../data/db.dart' as db;
import '../../data/repositories/local/local_repository.dart';
import '../../services/billing/post_processor.dart';
import '../../utils/currencies.dart';
import '../../utils/account_type_utils.dart';
import '../../providers/credit_card_reminder_providers.dart';
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../providers/amount_format_provider.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_text_field.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_switch.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_bottom_sheet.dart';

/// vivo OriginOS 风格账户创建与编辑页面 (CustomAccountEditPage)
///
/// 遵循全局定制铁律与 OriginUI 规范：
/// 1. 采用 OriginScaffold + OriginSmallTopAppBar 紧凑标题栏；
/// 2. 核心保存操作置底常驻（46dp 高度 / 23dp 圆角胶囊大按钮）；
/// 3. 账户分类采用灵动分段胶囊（日常/估值）与触觉反馈网格卡片；
/// 4. 12dp 圆角分组卡片，收拢基础信息、信用卡/银行卡扩展项与备注；
/// 5. 纯 Riverpod 驱动，复用底层仓库与平账、重名校验逻辑，保持与上游零冲突。
class CustomAccountEditPage extends ConsumerStatefulWidget {
  final db.Account? account; // null 表示新建账户，非 null 为编辑
  final int ledgerId;

  const CustomAccountEditPage({
    super.key,
    this.account,
    required this.ledgerId,
  });

  @override
  ConsumerState<CustomAccountEditPage> createState() =>
      _CustomAccountEditPageState();
}

class _CustomAccountEditPageState extends ConsumerState<CustomAccountEditPage> {
  // 日常账户类型（走流水）
  static const List<String> tradableAccountTypes = [
    'cash',
    'bank_card',
    'credit_card',
    'alipay',
    'wechat',
    'other',
  ];

  // 估值账户类型（只记当前价值 / 欠款，不走流水）
  static const List<String> valuationAccountTypes = [
    'real_estate',
    'vehicle',
    'investment',
    'insurance',
    'social_fund',
    'loan',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _initialBalanceController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _cardLastFourController;
  late final TextEditingController _noteController;

  late String _selectedType;
  late String _selectedCurrency;
  int? _billingDay;
  int? _paymentDueDay;
  bool _reminderEnabled = false;
  int _reminderDaysBefore = 3;

  bool _saving = false;
  bool _pickingCurrency = false;
  bool _balanceLoaded = true;
  bool _balanceLoadFailed = false;
  bool _creditOverpayment = false;
  double? _loadedCurrentBalance;

  bool _isNameDuplicate = false;
  String? _nameErrorText;
  String? _balanceErrorText;
  int _typeTab = 0; // 0 = 日常账户, 1 = 估值账户

  bool get isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account?.name ?? '');
    final hasEditableCurrentBalance =
        widget.account != null && !isValuationOnlyType(widget.account!.type);
    _balanceLoaded = !hasEditableCurrentBalance;
    _initialBalanceController = TextEditingController(
      text: !hasEditableCurrentBalance &&
              widget.account?.initialBalance != null &&
              widget.account!.initialBalance != 0.0
          ? widget.account!.initialBalance.abs().toStringAsFixed(2)
          : '',
    );
    _creditLimitController = TextEditingController(
      text: widget.account?.creditLimit != null
          ? widget.account!.creditLimit!.toStringAsFixed(2)
          : '',
    );
    _bankNameController =
        TextEditingController(text: widget.account?.bankName ?? '');
    _cardLastFourController =
        TextEditingController(text: widget.account?.cardLastFour ?? '');
    _noteController = TextEditingController(text: widget.account?.note ?? '');
    _selectedType = widget.account?.type ?? 'cash';
    _selectedCurrency = widget.account?.currency ??
        (ref.read(currencyLockedProvider)
            ? ref.read(currentLedgerCurrencyProvider)
            : 'CNY');
    _billingDay = widget.account?.billingDay;
    _paymentDueDay = widget.account?.paymentDueDay;
    _typeTab = isValuationOnlyType(_selectedType) ? 1 : 0;

    if (hasEditableCurrentBalance) {
      _loadEditableCurrentBalance();
    }
    _loadReminderSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    _creditLimitController.dispose();
    _bankNameController.dispose();
    _cardLastFourController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEditableCurrentBalance() async {
    try {
      final balance = await ref
          .read(repositoryProvider)
          .getAccountBalance(widget.account!.id);
      if (!mounted) return;
      setState(() {
        _loadedCurrentBalance = balance;
        _creditOverpayment = balance > 0;
        _initialBalanceController.text =
            (_selectedType == 'credit_card' ? balance.abs() : balance)
                .toStringAsFixed(2);
        _balanceLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _balanceLoadFailed = true);
      showBeeToast(
        context,
        '${AppLocalizations.of(context).commonError}: $error',
        tone: BeeTone.error,
      );
    }
  }

  Future<void> _loadReminderSettings() async {
    if (widget.account != null) {
      final prefs = await SharedPreferences.getInstance();
      final enabled =
          prefs.getBool('cc_reminder_enabled_${widget.account!.id}') ?? false;
      final daysBefore =
          prefs.getInt('cc_reminder_days_${widget.account!.id}') ?? 3;
      if (mounted) {
        setState(() {
          _reminderEnabled = enabled;
          _reminderDaysBefore = daysBefore;
        });
      }
    }
  }

  Future<void> _saveReminderSettings(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cc_reminder_enabled_$accountId', _reminderEnabled);
    await prefs.setInt('cc_reminder_days_$accountId', _reminderDaysBefore);

    if (_reminderEnabled && _paymentDueDay != null) {
      await CreditCardReminderService.scheduleReminder(
        accountId: accountId,
        accountName: _nameController.text.trim(),
        paymentDueDay: _paymentDueDay!,
        daysBefore: _reminderDaysBefore,
      );
    } else {
      await CreditCardReminderService.cancelReminder(accountId);
    }
  }

  Future<void> _checkNameDuplicate(String name) async {
    final draftName = name.trim();
    if (draftName.isEmpty) {
      setState(() {
        _isNameDuplicate = false;
        _nameErrorText = null;
      });
      return;
    }
    try {
      final accounts = await ref.read(repositoryProvider).getAllAccounts();
      if (!mounted || _nameController.text.trim() != draftName) return;
      final duplicate = accounts.any((account) =>
          account.id != widget.account?.id && account.name == draftName);
      setState(() {
        _isNameDuplicate = duplicate;
        _nameErrorText = duplicate
            ? AppLocalizations.of(context).accountNameDuplicate
            : null;
      });
    } catch (_) {
      if (!mounted || _nameController.text.trim() != draftName) return;
      setState(() => _nameErrorText = AppLocalizations.of(context).commonError);
    }
  }

  void _selectType(String type) {
    if (isEditing &&
        isValuationOnlyType(type) !=
            isValuationOnlyType(widget.account!.type)) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      final oldType = _selectedType;
      if (oldType != type &&
          (oldType == 'credit_card' || type == 'credit_card')) {
        final parsed = double.tryParse(_initialBalanceController.text);
        if (parsed != null) {
          final signed = oldType == 'credit_card'
              ? (_creditOverpayment ? parsed : -parsed)
              : parsed;
          _creditOverpayment = signed > 0;
          _initialBalanceController.text =
              (type == 'credit_card' ? signed.abs() : signed)
                  .toStringAsFixed(2);
        }
      }
      _selectedType = type;
      if (oldType == 'credit_card' && type != 'credit_card') {
        _creditLimitController.clear();
        _billingDay = null;
        _paymentDueDay = null;
        _reminderEnabled = false;
      }
      final wasBankOrCredit =
          oldType == 'bank_card' || oldType == 'credit_card';
      final isBankOrCredit = type == 'bank_card' || type == 'credit_card';
      if (wasBankOrCredit && !isBankOrCredit) {
        _bankNameController.clear();
        _cardLastFourController.clear();
      }
    });
  }

  Future<void> _pickCurrency() async {
    if (_saving || _pickingCurrency) return;
    setState(() => _pickingCurrency = true);
    try {
      if (isEditing &&
          await ref
              .read(repositoryProvider)
              .hasTransactions(widget.account!.id)) {
        if (mounted) {
          await _showOriginNotice(
              AppLocalizations.of(context).accountCurrencyLocked);
        }
        return;
      }
      if (!mounted) return;
      final picked = await showCurrencyPickerSheet(
        context,
        selected: _selectedCurrency,
        primaryColor: ref.read(primaryColorProvider),
        title: AppLocalizations.of(context).ledgersSelectCurrency,
      );
      if (mounted && picked != null) {
        setState(() => _selectedCurrency = picked);
      }
    } catch (error) {
      if (mounted) {
        showBeeToast(
          context,
          '${AppLocalizations.of(context).commonError}: $error',
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingCurrency = false);
    }
  }

  Future<void> _showOriginNotice(String message) {
    final l = AppLocalizations.of(context);
    return showOriginCustomDialog<void>(
      context,
      child: OriginDialog(
        title: l.commonNotice,
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: OriginTokens.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
        confirmText: l.commonConfirm,
        onConfirm: () => Navigator.pop(context),
      ),
    );
  }

  Future<bool?> _promptBalanceAdjustmentChoice({
    required double currentBalance,
    required double targetBalance,
    required AppLocalizations l10n,
  }) async {
    final difference = targetBalance - currentBalance;
    final symbol = getCurrencySymbol(_selectedCurrency);
    String amount(double value) =>
        '${value < 0 ? '−' : ''}$symbol${value.abs().toStringAsFixed(2)}';
    final signedDifference =
        '${difference > 0 ? '+' : difference < 0 ? '−' : ''}'
        '$symbol${difference.abs().toStringAsFixed(2)}';

    return showOriginBottomSheet<bool>(
      context,
      builder: (sheetContext) {
        var createTransaction = false;
        return StatefulBuilder(
          builder: (ctx, setChoice) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const OriginSheetDragHandle(),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        l10n.accountBalanceAdjustmentTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.accountBalanceAdjustmentChooseAction,
                      style: TextStyle(
                        fontSize: 13,
                        color: OriginTokens.textSecondary(sheetContext),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // 差额对比卡片
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: OriginTokens.cardSecondary(sheetContext),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.accountBalanceCurrent,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: OriginTokens.textSecondary(sheetContext),
                                ),
                              ),
                              Text(
                                amount(currentBalance),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.accountBalanceAfterAdjustment,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: OriginTokens.textSecondary(sheetContext),
                                ),
                              ),
                              Text(
                                amount(targetBalance),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const OriginDivider(startIndent: 0, endIndent: 0),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.accountBalanceDifference,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: OriginTokens.textSecondary(sheetContext),
                                ),
                              ),
                              Text(
                                signedDifference,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: difference > 0
                                      ? OriginTokens.resolveIncomeColor(sheetContext, ref)
                                      : difference < 0
                                          ? OriginTokens.resolveExpenseColor(sheetContext, ref)
                                          : OriginTokens.textSecondary(sheetContext),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildChoiceTile(
                      sheetContext,
                      title: l10n.accountBalanceAdjustmentOnly,
                      desc: l10n.accountBalanceAdjustmentOnlyMessage,
                      selected: !createTransaction,
                      onTap: () => setChoice(() => createTransaction = false),
                    ),
                    const SizedBox(height: 10),
                    _buildChoiceTile(
                      sheetContext,
                      title: l10n.accountBalanceAdjustmentCreate,
                      desc: l10n.accountBalanceAdjustmentCreateMessage,
                      selected: createTransaction,
                      onTap: () => setChoice(() => createTransaction = true),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: OriginTokens.buttonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ref.read(primaryColorProvider),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(OriginTokens.buttonRadius),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(sheetContext, createTransaction),
                        child: Text(
                          createTransaction
                              ? l10n.accountBalanceAdjustmentConfirmCreate
                              : l10n.accountBalanceAdjustmentConfirmOnly,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChoiceTile(
    BuildContext context, {
    required String title,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = ref.watch(primaryColorProvider);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.08)
              : OriginTokens.cardSecondary(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? primary
                          : OriginTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? primary : OriginTokens.textSecondary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateBalance(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty && !isEditing) return null;
    final parsed = double.tryParse(text);
    if (parsed == null ||
        !parsed.isFinite ||
        (_selectedType == 'credit_card' && parsed < 0)) {
      return AppLocalizations.of(context).creditCardAmountInvalid;
    }
    return null;
  }

  String _getBalanceLabel(AppLocalizations l) {
    if (_selectedType == 'credit_card') {
      return _creditOverpayment ? l.creditCardOverpayment : l.creditCardOwed;
    }
    if (isValuationOnlyType(_selectedType)) {
      return isLiabilityType(_selectedType)
          ? l.valuationCurrentDebt
          : l.valuationCurrentValue;
    }
    return isEditing ? l.accountBalance : l.accountInitialBalance;
  }

  String _getBalanceHint(AppLocalizations l) {
    if (isValuationOnlyType(_selectedType)) {
      return isLiabilityType(_selectedType)
          ? l.valuationDebtHint
          : l.valuationAccountHint;
    }
    switch (_selectedType) {
      case 'credit_card':
        return _creditOverpayment
            ? l.creditCardOverpaymentHint
            : l.creditCardDebtHint;
      default:
        return l.accountInitialBalanceHint;
    }
  }

  Future<void> _save() async {
    if (_saving || _pickingCurrency) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_balanceLoaded || _balanceLoadFailed) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedType == 'credit_card' &&
        _reminderEnabled &&
        _paymentDueDay == null) {
      showBeeToast(
        context,
        AppLocalizations.of(context).creditCardReminderDueRequired,
        tone: BeeTone.error,
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(
          () => _nameErrorText = AppLocalizations.of(context).accountNameRequired);
      return;
    }
    final balanceErr = _validateBalance(_initialBalanceController.text);
    if (balanceErr != null) {
      setState(() => _balanceErrorText = balanceErr);
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(repositoryProvider);
      final accounts = await repo.getAllAccounts();
      if (!mounted) return;

      if (accounts.any((account) =>
          account.name == name && account.id != widget.account?.id)) {
        setState(() {
          _isNameDuplicate = true;
          _nameErrorText = AppLocalizations.of(context).accountNameDuplicate;
        });
        return;
      }

      final initialBalanceText = _initialBalanceController.text.trim();
      final enteredBalance =
          initialBalanceText.isEmpty ? 0.0 : double.parse(initialBalanceText);
      var initialBalance = enteredBalance;
      if (_selectedType == 'credit_card') {
        initialBalance = enteredBalance == 0
            ? 0
            : (_creditOverpayment ? enteredBalance : -enteredBalance);
      }
      if (_selectedType == 'loan' && initialBalance > 0) {
        initialBalance = -initialBalance;
      }

      final isCreditCard = _selectedType == 'credit_card';
      final creditLimitText = _creditLimitController.text.trim();
      final creditLimit = isCreditCard && creditLimitText.isNotEmpty
          ? double.parse(creditLimitText)
          : null;

      if (isEditing) {
        String? currencyToUpdate;
        if (_selectedCurrency != widget.account!.currency) {
          final hasTransactions =
              await repo.hasTransactions(widget.account!.id);
          if (hasTransactions) {
            if (mounted) {
              await _showOriginNotice(
                  AppLocalizations.of(context).accountCurrencyLocked);
            }
            return;
          }
          currencyToUpdate = _selectedCurrency;
        }

        var balanceNeedsUpdate = false;
        var createBalanceAdjustment = false;
        final targetBalance = initialBalance;
        if (!isValuationOnlyType(widget.account!.type) &&
            !isValuationOnlyType(_selectedType)) {
          final currentBalance =
              await repo.getAccountBalance(widget.account!.id);
          if (!mounted) return;
          if ((targetBalance - (_loadedCurrentBalance ?? currentBalance))
                  .abs() >=
              0.0000001) {
            final choice = await _promptBalanceAdjustmentChoice(
              currentBalance: currentBalance,
              targetBalance: targetBalance,
              l10n: AppLocalizations.of(context),
            );
            if (!mounted || choice == null) return;
            balanceNeedsUpdate = true;
            createBalanceAdjustment = choice;
          }
        }

        final wasCreditCard = widget.account!.type == 'credit_card';
        final isBankOrCredit =
            _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final bankName =
            isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFour =
            isBankOrCredit ? _cardLastFourController.text.trim() : null;
        final noteText = _noteController.text.trim();

        Future<void> persist() async {
          await repo.updateAccount(
            widget.account!.id,
            name: name,
            type: _selectedType,
            currency: currencyToUpdate,
            creditLimit: isCreditCard ? creditLimit : null,
            billingDay: isCreditCard ? _billingDay : null,
            paymentDueDay: isCreditCard ? _paymentDueDay : null,
            clearCreditCardFields: wasCreditCard,
            bankName: bankName ?? '',
            cardLastFour: cardLastFour ?? '',
            note: noteText,
          );

          if (balanceNeedsUpdate) {
            await repo.setAccountBalance(
              ledgerId: widget.ledgerId,
              accountId: widget.account!.id,
              targetBalance: targetBalance,
              createBalanceAdjustment: createBalanceAdjustment,
            );
          }
        }

        if (repo is LocalRepository) {
          await repo.db.transaction(persist);
        } else {
          await persist();
        }

        if (balanceNeedsUpdate) {
          ref.invalidate(accountStatsProvider(widget.account!.id));
          ref.read(statsRefreshProvider.notifier).state++;
          ref.read(tagListRefreshProvider.notifier).state++;
        }

        if (isCreditCard || wasCreditCard) {
          await _saveReminderSettings(widget.account!.id);
        }
      } else {
        final isBankOrCredit =
            _selectedType == 'bank_card' || _selectedType == 'credit_card';
        final bankNameText =
            isBankOrCredit ? _bankNameController.text.trim() : null;
        final cardLastFourText =
            isBankOrCredit ? _cardLastFourController.text.trim() : null;
        final noteText = _noteController.text.trim();

        final id = await repo.createAccount(
          ledgerId: widget.ledgerId,
          name: name,
          type: _selectedType,
          currency: _selectedCurrency,
          initialBalance: initialBalance,
          creditLimit: creditLimit,
          billingDay: isCreditCard ? _billingDay : null,
          paymentDueDay: isCreditCard ? _paymentDueDay : null,
          bankName: bankNameText != null && bankNameText.isNotEmpty
              ? bankNameText
              : null,
          cardLastFour: cardLastFourText != null && cardLastFourText.isNotEmpty
              ? cardLastFourText
              : null,
          note: noteText.isNotEmpty ? noteText : null,
        );

        if (isCreditCard) {
          await _saveReminderSettings(id);
        }
      }

      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(
          context,
          '${AppLocalizations.of(context).commonError}: $e',
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || _pickingCurrency || !isEditing) return;
    final l = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);
    setState(() => _saving = true);
    try {
      final count = await repo.getTransactionCountByAccount(widget.account!.id);
      if (!mounted) return;

      final confirmed = await showOriginCustomDialog<bool>(
        context,
        child: OriginDialog(
          title: count > 0 ? l.accountDeleteWarningTitle : l.commonConfirm,
          content: Text(
            count > 0
                ? l.accountDeleteWarningMessage(count)
                : l.accountDeleteConfirm,
            style: TextStyle(
              fontSize: 14,
              color: OriginTokens.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          confirmText: l.commonDelete,
          isDanger: true,
          cancelText: l.commonCancel,
          onConfirm: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );

      if (confirmed != true || !mounted) return;
      await repo.deleteAccount(widget.account!.id);
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showBeeToast(
          context,
          '${AppLocalizations.of(context).commonError}: $error',
          tone: BeeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleHidden() async {
    if (_saving || _pickingCurrency || !isEditing) return;
    final l = AppLocalizations.of(context);
    final account = widget.account!;
    final repo = ref.read(repositoryProvider);
    setState(() => _saving = true);

    try {
      if (account.hidden) {
        await repo.setAccountHidden(account.id, false);
        if (mounted) {
          PostProcessor.sync(ref, ledgerId: widget.ledgerId);
          showBeeToast(context, l.accountRestoredToast, tone: BeeTone.success);
          Navigator.pop(context, true);
        }
        return;
      }

      final recurring =
          await repo.getActiveRecurringCountByAccount(account.id);
      if (!mounted) return;

      final confirmed = await showOriginCustomDialog<bool>(
        context,
        child: OriginDialog(
          title: l.accountHideConfirmTitle,
          content: Text(
            recurring > 0
                ? '${l.accountHideConfirmBody}\n${l.accountHideRecurringWarn(recurring)}'
                : l.accountHideConfirmBody,
            style: TextStyle(
              fontSize: 14,
              color: OriginTokens.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          confirmText: l.accountHide,
          cancelText: l.commonCancel,
          onConfirm: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      );

      if (confirmed != true || !mounted) return;
      await repo.setAccountHidden(account.id, true);

      final income = await ref.read(defaultIncomeAccountIdProvider.future);
      final expense = await ref.read(defaultExpenseAccountIdProvider.future);
      var cleared = false;
      if (income == account.id) {
        await ref
            .read(defaultAccountSetterProvider)
            .setDefaultIncomeAccountId(null);
        ref.invalidate(defaultIncomeAccountIdProvider);
        cleared = true;
      }
      if (expense == account.id) {
        await ref
            .read(defaultAccountSetterProvider)
            .setDefaultExpenseAccountId(null);
        ref.invalidate(defaultExpenseAccountIdProvider);
        cleared = true;
      }

      if (mounted) {
        PostProcessor.sync(ref, ledgerId: widget.ledgerId);
        showBeeToast(
          context,
          cleared
              ? '${l.accountHiddenToast} · ${l.accountHideClearedDefault}'
              : l.accountHiddenToast,
          tone: BeeTone.success,
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickDay(String title, int? currentDay, ValueChanged<int?> onSelected) {
    showOriginBottomSheet<void>(
      context,
      builder: (ctx) {
        final primary = ref.watch(primaryColorProvider);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OriginSheetDragHandle(),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.start,
                  children: [
                    for (var day = 1; day <= 28; day++) ...[
                      SizedBox(
                        width: (MediaQuery.of(ctx).size.width - 40 - 24) / 4,
                        height: 44,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onSelected(day);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: currentDay == day
                                  ? primary.withValues(alpha: 0.12)
                                  : OriginTokens.cardSecondary(ctx),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: currentDay == day
                                    ? primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '$day 日',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: currentDay == day
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: currentDay == day
                                    ? primary
                                    : OriginTokens.textPrimary(ctx),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (currentDay != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onSelected(null);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      AppLocalizations.of(ctx).commonRemove,
                      style: const TextStyle(color: OriginTokens.expenseRed),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = ref.watch(primaryColorProvider);
    final isCredit = _selectedType == 'credit_card';
    final isBank = _selectedType == 'bank_card';
    final editableBalance =
        !isEditing || !isValuationOnlyType(widget.account!.type);

    return PopScope(
      canPop: !_saving,
      child: OriginScaffold(
        appBar: OriginSmallTopAppBar(
          title: isEditing ? l.accountEditTitle : l.accountNewTitle,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: OriginTokens.textPrimary(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              OriginTokens.cardMargin,
              8,
              OriginTokens.cardMargin,
              12,
            ),
            child: SizedBox(
              width: double.infinity,
              height: OriginTokens.buttonHeight,
              child: ElevatedButton(
                onPressed: _saving ||
                        _pickingCurrency ||
                        _isNameDuplicate ||
                        !_balanceLoaded ||
                        _balanceLoadFailed
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primary.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(OriginTokens.buttonRadius),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        l.commonSave,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            children: [
              // 1. 账户分类选择卡片
              _buildTypeCard(l, primary, isDark),

              // 2. 基本信息卡片
              _buildBasicInfoCard(l, primary, editableBalance, isCredit, isDark),

              // 3. 信用卡属性卡片（信用卡专属）
              if (isCredit)
                _buildCreditCardSettings(l, primary, isDark),

              // 4. 银行卡属性卡片（银行卡或信用卡）
              if (isBank || isCredit)
                _buildBankCardSettings(l, isDark),

              // 5. 备注卡片
              _buildNoteCard(l, isDark),

              // 6. 编辑模式管理区
              if (isEditing)
                _buildDangerSection(l),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. 账户类型选择卡片
  Widget _buildTypeCard(AppLocalizations l, Color primary, bool isDark) {
    final activeTypes =
        _typeTab == 0 ? tradableAccountTypes : valuationAccountTypes;

    return OriginCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OriginSegmentedControl<int>(
            items: const [0, 1],
            selectedItem: _typeTab,
            labelBuilder: (tab) =>
                tab == 0 ? l.accountGroupTradable : l.accountTabValuation,
            onSelected: (val) {
              if (isEditing &&
                  (val == 0) != !isValuationOnlyType(widget.account!.type)) {
                return;
              }
              HapticFeedback.lightImpact();
              setState(() => _typeTab = val);
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth = (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final type in activeTypes)
                    _buildTypeItem(
                      type: type,
                      label: getAccountTypeLabel(context, type),
                      width: itemWidth,
                      selected: _selectedType == type,
                      enabled: !isEditing ||
                          isValuationOnlyType(type) ==
                              isValuationOnlyType(widget.account!.type),
                      primary: primary,
                      isDark: isDark,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeItem({
    required String type,
    required String label,
    required double width,
    required bool selected,
    required bool enabled,
    required Color primary,
    required bool isDark,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? () => _selectType(type) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: isDark ? 0.22 : 0.1)
                : OriginTokens.cardSecondary(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AccountTypeIcon(type: type, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? primary : OriginTokens.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: OriginTokens.textSecondary(context),
        ),
      ),
    );
  }

  /// 2. 基本信息卡片
  Widget _buildBasicInfoCard(
    AppLocalizations l,
    Color primary,
    bool editableBalance,
    bool isCredit,
    bool isDark,
  ) {
    return OriginCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 账户名称（带上方文字说明）
          _buildFieldLabel(l.accountNameLabel),
          OriginTextField(
            controller: _nameController,
            hintText: l.accountNameHint,
            clearable: true,
            errorText: _nameErrorText,
            onChanged: _checkNameDuplicate,
          ),

          // 金额设置（带上方文字说明，排在币种上方）
          if (editableBalance) ...[
            const SizedBox(height: 16),
            _buildFieldLabel(_getBalanceLabel(l)),
            OriginTextField(
              controller: _initialBalanceController,
              hintText: _getBalanceHint(l),
              errorText: _balanceErrorText,
              onChanged: (v) {
                if (_balanceErrorText != null) {
                  setState(() => _balanceErrorText = _validateBalance(v));
                }
              },
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              prefixIcon: ref.watch(currencyLockedProvider)
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        getCurrencySymbol(_selectedCurrency),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              suffixIcon: !_balanceLoaded
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ],

          // 信用卡欠款/多缴模式切换（紧随初始资金）
          if (isCredit) ...[
            const SizedBox(height: 12),
            OriginSegmentedControl<bool>(
              items: const [false, true],
              selectedItem: _creditOverpayment,
              labelBuilder: (overpayment) =>
                  overpayment ? l.creditCardOverpayment : l.creditCardOwed,
              onSelected: (v) {
                HapticFeedback.lightImpact();
                setState(() => _creditOverpayment = v);
              },
            ),
          ],

          // 币种选择（调整至初始资金下方；锁定币种时彻底隐藏）
          if (!ref.watch(currencyLockedProvider)) ...[
            const SizedBox(height: 16),
            const OriginDivider(startIndent: 0, endIndent: 0),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickCurrency,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: OriginTokens.textSecondary(context),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      l.ledgersCurrency,
                      style: TextStyle(
                        fontSize: 14,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      displayCurrency(_selectedCurrency, context),
                      style: TextStyle(
                        fontSize: 14,
                        color: OriginTokens.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: OriginTokens.textSecondary(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 3. 信用卡属性卡片
  Widget _buildCreditCardSettings(
    AppLocalizations l,
    Color primary,
    bool isDark,
  ) {
    return OriginCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.credit_card_rounded,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 8),
              Text(
                l.creditCardSettings,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 信用额度
          _buildFieldLabel(l.creditLimit),
          OriginTextField(
            controller: _creditLimitController,
            hintText: l.creditLimitHint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),
          const OriginDivider(startIndent: 0, endIndent: 0),
          const SizedBox(height: 10),

          // 账单日 & 还款日
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDay(
                    l.billingDay,
                    _billingDay,
                    (day) => setState(() => _billingDay = day),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.billingDay,
                          style: TextStyle(
                            fontSize: 12,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _billingDay == null
                              ? l.selectDay
                              : l.dayOfMonth(_billingDay!),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _billingDay == null
                                ? OriginTokens.textSecondary(context)
                                : OriginTokens.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                height: 24,
                width: 1,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: () => _pickDay(
                    l.paymentDueDay,
                    _paymentDueDay,
                    (day) => setState(() => _paymentDueDay = day),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.paymentDueDay,
                          style: TextStyle(
                            fontSize: 12,
                            color: OriginTokens.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _paymentDueDay == null
                              ? l.selectDay
                              : l.dayOfMonth(_paymentDueDay!),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _paymentDueDay == null
                                ? OriginTokens.textSecondary(context)
                                : OriginTokens.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const OriginDivider(startIndent: 0, endIndent: 0),
          const SizedBox(height: 12),

          // 还款提醒开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.creditCardReminderTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.creditCardReminderDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: OriginTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              OriginSwitch(
                value: _reminderEnabled,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _reminderEnabled = v);
                },
              ),
            ],
          ),

          // 提前提醒天数胶囊
          if (_reminderEnabled) ...[
            const SizedBox(height: 14),
            OriginSegmentedControl<int>(
              items: const [1, 3, 5, 7],
              selectedItem: _reminderDaysBefore,
              labelBuilder: (day) => l.creditCardReminderDaysBefore(day),
              onSelected: (v) {
                HapticFeedback.lightImpact();
                setState(() => _reminderDaysBefore = v);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// 4. 银行卡属性卡片
  Widget _buildBankCardSettings(AppLocalizations l, bool isDark) {
    return OriginCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.accountMetaInfo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(l.accountBankName),
                    OriginTextField(
                      controller: _bankNameController,
                      hintText: l.accountBankNameHint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(l.accountCardLastFour),
                    OriginTextField(
                      controller: _cardLastFourController,
                      hintText: l.accountCardLastFourHint,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. 备注卡片
  Widget _buildNoteCard(AppLocalizations l, bool isDark) {
    return OriginCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel(l.accountNote),
          OriginTextField(
            controller: _noteController,
            hintText: l.accountNoteHint,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// 6. 编辑模式管理区
  Widget _buildDangerSection(AppLocalizations l) {
    return OriginCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: _toggleHidden,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    widget.account!.hidden
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 20,
                    color: OriginTokens.textPrimary(context),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.account!.hidden ? l.accountUnhide : l.accountHide,
                    style: TextStyle(
                      fontSize: 15,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: OriginTokens.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
          const OriginDivider(startIndent: 48, endIndent: 0),
          InkWell(
            onTap: _delete,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: OriginTokens.expenseRed,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l.commonDelete,
                    style: const TextStyle(
                      fontSize: 15,
                      color: OriginTokens.expenseRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: OriginTokens.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
