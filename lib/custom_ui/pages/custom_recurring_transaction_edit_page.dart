import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/shared/currency/currency_flag.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../../pages/transaction/recurring/bindings/recurring_editor_controls.dart'
    show recurringEditorIntervalLabel, recurringEditorFrequencyLabel;
import '../../providers.dart';
import '../../services/data/recurring_transaction_service.dart';
import '../../services/system/logger_service.dart';
import '../../utils/category_utils.dart';
import '../../utils/currencies.dart';
import '../styles/origin_tokens.dart';
import '../widgets/custom_account_grid_picker.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_category_selector_sheet.dart';
import '../widgets/origin_date_picker.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_setting_card.dart';

/// vivo OriginOS 风格周期账单编辑与添加页面 (CustomRecurringTransactionEditPage)
class CustomRecurringTransactionEditPage extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;

  const CustomRecurringTransactionEditPage({super.key, this.recurring});

  @override
  ConsumerState<CustomRecurringTransactionEditPage> createState() =>
      _CustomRecurringTransactionEditPageState();
}

class _CustomRecurringTransactionEditPageState
    extends ConsumerState<CustomRecurringTransactionEditPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late String _type;
  late RecurringFrequency _frequency;
  late int _interval;
  late DateTime _startDate;
  DateTime? _endDate;
  late int _dayOfMonth;
  Category? _selectedCategory;
  int? _selectedAccountId;
  int? _selectedToAccountId;
  int? _selectedLedgerId;
  late bool _enabled;

  bool _saving = false;
  bool _initializing = true;
  String? _currencyCode;
  String? _ledgerCurrency;
  String? _ledgerName;
  String? _accountName;
  String? _toAccountName;
  String? _loadError;

  bool get _isEditing => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.recurring;
    _type = rule?.type ?? 'expense';
    _frequency = RecurringFrequency.fromString(rule?.frequency ?? 'monthly');
    _interval = rule?.interval ?? 1;
    _startDate = rule?.startDate ?? DateTime.now();
    _endDate = rule?.endDate;
    _dayOfMonth = rule?.dayOfMonth ?? DateTime.now().day;
    _selectedAccountId = rule?.accountId;
    _selectedToAccountId = rule?.toAccountId;
    _enabled = rule?.enabled ?? true;
    _selectedLedgerId = rule?.ledgerId ?? ref.read(currentLedgerIdProvider);
    _currencyCode = rule?.currencyCode?.toUpperCase();

    if (rule != null) {
      _amountController.text = rule.amount.toStringAsFixed(2);
      _noteController.text = rule.note ?? '';
    }

    _amountController.addListener(_onAmountChanged);
    _initialize();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _initializing = true;
      _loadError = null;
    });

    try {
      await _loadLedgerCurrency();
      if (!mounted) return;

      final rule = widget.recurring;
      if (rule != null) {
        final repo = ref.read(repositoryProvider);
        final category = rule.categoryId == null
            ? null
            : await repo.getCategoryById(rule.categoryId!);
        final from = rule.accountId == null
            ? null
            : await repo.getAccount(rule.accountId!);
        final to = rule.toAccountId == null
            ? null
            : await repo.getAccount(rule.toAccountId!);

        if (!mounted) return;
        setState(() {
          _selectedCategory = category;
          _accountName = from?.name;
          _toAccountName = to?.name;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _loadLedgerCurrency() async {
    final ledgerId = _selectedLedgerId;
    if (ledgerId == null) return;
    final ledger = await ref.read(repositoryProvider).getLedgerById(ledgerId);
    if (!mounted || ledgerId != _selectedLedgerId) return;
    setState(() {
      _ledgerName = ledger?.name;
      _ledgerCurrency = (ledger?.currency.isNotEmpty ?? false)
          ? ledger!.currency.toUpperCase()
          : 'CNY';
      if (_currencyCode?.toUpperCase() == _ledgerCurrency) {
        _currencyCode = null;
      }
    });
  }

  String _effectiveCurrency() =>
      _currencyCode ??
      _ledgerCurrency ??
      ref.read(currentLedgerCurrencyProvider);

  void _selectType(String value) {
    if (_type == value) return;
    setState(() {
      _type = value;
      _selectedCategory = null;
      if (value != 'transfer') {
        _selectedToAccountId = null;
        _toAccountName = null;
      }
    });
  }

  Future<void> _selectLedger() async {
    final ledgers = ref.read(localLedgersProvider).valueOrNull ?? [];
    if (ledgers.length <= 1) return;
    final l = AppLocalizations.of(context);

    final selected = await showOriginChoiceDialog<int>(
      context,
      title: l.ledgerSelectTitle,
      selected: _selectedLedgerId ?? ref.read(currentLedgerIdProvider),
      options: [
        for (final ledger in ledgers)
          OriginChoiceOption(
            value: ledger.id,
            title: ledger.name,
            subtitle: ledger.currency,
            icon: Icons.book_outlined,
          ),
      ],
    );

    if (selected != null && mounted && selected != _selectedLedgerId) {
      setState(() => _selectedLedgerId = selected);
      await _loadLedgerCurrency();
    }
  }

  Future<void> _selectCurrency() async {
    final l = AppLocalizations.of(context);
    final String base =
        _ledgerCurrency ?? ref.read(currentLedgerCurrencyProvider);
    final picked = await showCurrencyPickerSheet(
      context,
      selected: _effectiveCurrency(),
      primaryColor: ref.read(primaryColorProvider),
      title: l.txCurrencyPickerTitle,
      rateBase: base,
    );

    if (picked == null || !mounted) return;
    final upper = picked.toUpperCase();
    if (upper == _effectiveCurrency()) return;

    setState(() {
      _currencyCode = upper == base.toUpperCase() ? null : upper;
      // 币种联动：清空已选账户，避免币种不一致
      _selectedAccountId = null;
      _selectedToAccountId = null;
      _accountName = null;
      _toAccountName = null;
    });
  }

  Future<void> _selectCategory() async {
    final picked = await OriginCategorySelectorSheet.show(
      context,
      currentCategoryId: _selectedCategory?.id,
      ledgerId: _selectedLedgerId,
      initialKind: _type,
    );

    if (picked != null && mounted) {
      setState(() => _selectedCategory = picked);
    }
  }

  Future<void> _selectAccount({required bool isFromAccount}) async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);
    final currency = _effectiveCurrency().toUpperCase();
    final allAccounts = await repo.getAllAccounts();
    var accounts = allAccounts
        .where((a) => a.currency.toUpperCase() == currency && !a.hidden)
        .toList();

    if (!isFromAccount && _selectedAccountId != null) {
      accounts = accounts.where((a) => a.id != _selectedAccountId).toList();
    }
    if (!mounted) return;

    final selectedId = await CustomAccountGridPicker.show(
      context,
      accounts: accounts,
      currentAccountId:
          isFromAccount ? _selectedAccountId : _selectedToAccountId,
      showNoAccountOption: _type != 'transfer' && isFromAccount,
      title: isFromAccount
          ? (_type == 'transfer' ? l.transferFromAccount : l.accountSelectTitle)
          : l.transferToAccount,
      ledgerId: _selectedLedgerId,
    );

    if (!mounted || selectedId == null) return;

    setState(() {
      final realId =
          selectedId == CustomAccountGridPicker.noAccountId ? null : selectedId;
      if (isFromAccount) {
        _selectedAccountId = realId;
        _accountName =
            accounts.where((a) => a.id == realId).firstOrNull?.name;
        if (_type == 'transfer' && realId == _selectedToAccountId) {
          _selectedToAccountId = null;
          _toAccountName = null;
        }
      } else {
        _selectedToAccountId = realId;
        _toAccountName =
            accounts.where((a) => a.id == realId).firstOrNull?.name;
      }
    });
  }

  Future<void> _selectFrequency() async {
    final l = AppLocalizations.of(context);
    final picked = await showOriginChoiceDialog<RecurringFrequency>(
      context,
      title: l.recurringTransactionFrequency,
      selected: _frequency,
      options: [
        OriginChoiceOption(
          value: RecurringFrequency.daily,
          title: l.recurringTransactionDaily,
        ),
        OriginChoiceOption(
          value: RecurringFrequency.weekly,
          title: l.recurringTransactionWeekly,
        ),
        OriginChoiceOption(
          value: RecurringFrequency.monthly,
          title: l.recurringTransactionMonthly,
        ),
        OriginChoiceOption(
          value: RecurringFrequency.yearly,
          title: l.recurringTransactionYearly,
        ),
      ],
    );

    if (picked != null && mounted) {
      setState(() {
        _frequency = picked;
        if (_frequency == RecurringFrequency.daily) {
          _interval = 1;
        }
      });
    }
  }

  Future<void> _selectInterval() async {
    final l = AppLocalizations.of(context);
    final options = List.generate(12, (i) => i + 1);
    final picked = await showOriginChoiceDialog<int>(
      context,
      title: l.recurringTransactionInterval,
      selected: _interval,
      options: [
        for (final n in options)
          OriginChoiceOption(
            value: n,
            title: recurringEditorIntervalLabel(l, _frequency, n),
          ),
      ],
    );

    if (picked != null && mounted) {
      setState(() => _interval = picked);
    }
  }

  Future<void> _selectDayOfMonth() async {
    final l = AppLocalizations.of(context);
    final options = List.generate(31, (i) => i + 1);
    final picked = await showOriginChoiceDialog<int>(
      context,
      title: l.recurringTransactionDayOfMonth,
      selected: _dayOfMonth,
      options: [
        for (final day in options)
          OriginChoiceOption(
            value: day,
            title: '$day',
          ),
      ],
    );

    if (picked != null && mounted) {
      setState(() => _dayOfMonth = picked);
    }
  }

  Future<void> _selectDate({required bool isStartDate}) async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = isStartDate ? today : _startDate;
    var initial = isStartDate ? _startDate : (_endDate ?? _startDate);
    if (initial.isBefore(minDate)) initial = minDate;

    final picked = await showOriginDatePicker(
      context,
      initial: initial,
      minDate: minDate,
      maxDate: DateTime(2100),
      title: isStartDate
          ? l.recurringTransactionStartDate
          : l.recurringTransactionEndDate,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  bool _isFormValid() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return false;

    if (_selectedLedgerId == null) return false;

    if (_type != 'transfer' && _selectedCategory == null) return false;

    if (_type == 'transfer') {
      if (_selectedAccountId == null || _selectedToAccountId == null) {
        return false;
      }
      if (_selectedAccountId == _selectedToAccountId) {
        return false;
      }
    }

    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = AppLocalizations.of(context);

    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showBeeToast(context, '请输入有效金额', tone: BeeTone.error);
      return;
    }

    if (_type != 'transfer' && _selectedCategory == null) {
      showBeeToast(context, '请选择分类', tone: BeeTone.error);
      return;
    }

    if (_type == 'transfer') {
      if (_selectedAccountId == null) {
        showBeeToast(context, '请选择转出账户', tone: BeeTone.error);
        return;
      }
      if (_selectedToAccountId == null) {
        showBeeToast(context, '请选择转入账户', tone: BeeTone.error);
        return;
      }
      if (_selectedAccountId == _selectedToAccountId) {
        showBeeToast(context, '转出账户和转入账户不能相同', tone: BeeTone.error);
        return;
      }
    }

    final repo = ref.read(repositoryProvider);
    final int ledgerId = _selectedLedgerId ?? ref.read(currentLedgerIdProvider);
    if (ledgerId <= 0) {
      showBeeToast(context, '请选择有效账本', tone: BeeTone.error);
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await repo.updateRecurringTransaction(
          id: widget.recurring!.id,
          ledgerId: ledgerId,
          type: _type,
          amount: amount,
          categoryId: _type == 'transfer' ? null : _selectedCategory!.id,
          accountId: _selectedAccountId,
          toAccountId: _selectedToAccountId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _frequency == RecurringFrequency.monthly ? _dayOfMonth : null,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
          enabled: _enabled,
          currencyCode: _currencyCode,
        );
      } else {
        await repo.addRecurringTransaction(
          ledgerId: ledgerId,
          type: _type,
          amount: amount,
          categoryId: _type == 'transfer' ? null : _selectedCategory!.id,
          accountId: _selectedAccountId,
          toAccountId: _selectedToAccountId,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          frequency: _frequency.value,
          interval: _interval,
          dayOfMonth: _frequency == RecurringFrequency.monthly ? _dayOfMonth : null,
          dayOfWeek: null,
          monthOfYear: null,
          startDate: _startDate,
          endDate: _endDate,
          currencyCode: _currencyCode,
        );
      }

      ref.invalidate(allRecurringTransactionsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e, stackTrace) {
      logger.error('周期账单保存', '保存失败', e, stackTrace);
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving || widget.recurring == null) return;
    final l = AppLocalizations.of(context);

    final confirmed = await showOriginConfirmDialog(
      context,
      title: l.commonDelete,
      message: l.recurringTransactionDeleteConfirm,
      confirmText: l.commonDelete,
      cancelText: l.commonCancel,
      isDanger: true,
    );

    if (confirmed != true || !mounted || _saving) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .deleteRecurringTransaction(widget.recurring!.id);
      ref.invalidate(allRecurringTransactionsProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error, stack) {
      logger.error('周期账单删除', '删除失败', error, stack);
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $error', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final currency = _effectiveCurrency();
    final ledgers = ref.watch(localLedgersProvider).valueOrNull ?? const [];
    final hasMultipleLedgers = ledgers.length > 1;

    final primaryColor = OriginTokens.primary(context);

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: _isEditing
            ? l.recurringTransactionEdit
            : l.recurringTransactionAdd,
        leading: BackButton(
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: _saving || _initializing ? null : _delete,
            ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${l.commonError}: $_loadError'),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _initialize,
                        child: Text(l.v4RecordingRetry),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 24.0),
                  children: [
                    // 1. 类型切换 (支出/收入/转账) - 保持与卡片 20dp 边距对齐
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: OriginTokens.cardMargin,
                      ),
                      child: OriginSegmentedControl<String>(
                        items: const ['expense', 'income', 'transfer'],
                        selectedItem: _type,
                        onSelected: _saving ? (_) {} : _selectType,
                        labelBuilder: (type) => switch (type) {
                          'expense' => l.categoryExpense,
                          'income' => l.categoryIncome,
                          'transfer' => l.transferTitle,
                          _ => '',
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. 金额输入卡片
                    OriginCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 14.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.importFieldAmount,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: OriginTokens.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Text(
                                getCurrencySymbol(currency),
                                style: TextStyle(
                                  fontSize: 26.0,
                                  fontWeight: FontWeight.bold,
                                  color: OriginTokens.textPrimary(context),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  enabled: !_saving,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.bold,
                                    color: OriginTokens.textPrimary(context),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color:
                                          OriginTokens.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 3. 基础属性配置 (账本/币种/分类/账户)
                    OriginSettingGroup(
                      items: [
                        if (hasMultipleLedgers)
                          OriginSettingItem(
                            title: l.ledgerSelectTitle,
                            valueText: _ledgerName ?? l.ledgerSelect,
                            leading: Icon(
                              Icons.book_outlined,
                              size: 20,
                              color: primaryColor,
                            ),
                            onTap: _saving ? null : _selectLedger,
                          ),
                        OriginSettingItem(
                          title: l.txCurrencyLabel,
                          valueText: displayCurrency(currency, context),
                          leading: currencyFlag(
                            context,
                            currency,
                            width: 20,
                            height: 14,
                            radius: 3,
                          ),
                          onTap: _saving ? null : _selectCurrency,
                        ),
                        if (_type != 'transfer')
                          OriginSettingItem(
                            title: l.categoryTitle,
                            valueText: _selectedCategory == null
                                ? l.commonSearch
                                : CategoryUtils.getDisplayName(
                                    _selectedCategory!.name,
                                    context,
                                  ),
                            leading: _selectedCategory == null
                                ? Icon(
                                    Icons.category_outlined,
                                    size: 20,
                                    color: primaryColor,
                                  )
                                : RecordingCategoryIcon(
                                    category: _selectedCategory!,
                                    size: 20,
                                  ),
                            onTap: _saving ? null : _selectCategory,
                          ),
                        OriginSettingItem(
                          title: _type == 'transfer'
                              ? l.transferFromAccount
                              : l.accountSelectTitle,
                          valueText: _accountName ?? l.accountNone,
                          leading: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: primaryColor,
                          ),
                          onTap: _saving
                              ? null
                              : () => _selectAccount(isFromAccount: true),
                        ),
                        if (_type == 'transfer')
                          OriginSettingItem(
                            title: l.transferToAccount,
                            valueText: _toAccountName ?? l.accountNone,
                            leading: Icon(
                              Icons.swap_horiz_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            onTap: _saving
                                ? null
                                : () => _selectAccount(isFromAccount: false),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 4. 周期规则设置 (频率/间隔/每月几日/起止日期)
                    OriginSettingGroup(
                      items: [
                        OriginSettingItem(
                          title: l.recurringTransactionFrequency,
                          valueText:
                              recurringEditorFrequencyLabel(l, _frequency),
                          leading: Icon(
                            Icons.repeat_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          onTap: _saving ? null : _selectFrequency,
                        ),
                        if (_frequency != RecurringFrequency.daily)
                          OriginSettingItem(
                            title: l.recurringTransactionInterval,
                            valueText: recurringEditorIntervalLabel(
                              l,
                              _frequency,
                              _interval,
                            ),
                            leading: Icon(
                              Icons.timelapse_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            onTap: _saving ? null : _selectInterval,
                          ),
                        if (_frequency == RecurringFrequency.monthly)
                          OriginSettingItem(
                            title: l.recurringTransactionDayOfMonth,
                            valueText: '$_dayOfMonth 日',
                            leading: Icon(
                              Icons.calendar_view_day_rounded,
                              size: 20,
                              color: primaryColor,
                            ),
                            onTap: _saving ? null : _selectDayOfMonth,
                          ),
                        OriginSettingItem(
                          title: l.recurringTransactionStartDate,
                          valueText: DateFormat.yMd().format(_startDate),
                          leading: Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          onTap: _saving
                              ? null
                              : () => _selectDate(isStartDate: true),
                        ),
                        OriginSettingItem(
                          title: l.recurringTransactionEndDate,
                          valueText: _endDate == null
                              ? l.recurringTransactionNoEndDate
                              : DateFormat.yMd().format(_endDate!),
                          leading: Icon(
                            Icons.event_available_rounded,
                            size: 20,
                            color: primaryColor,
                          ),
                          trailing: _endDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _endDate = null),
                                )
                              : null,
                          onTap: _saving
                              ? null
                              : () => _selectDate(isStartDate: false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 5. 备注独立小节标题与输入卡片
                    OriginSectionTitle(
                      title: l.importFieldNote,
                      margin: const EdgeInsets.fromLTRB(
                        OriginTokens.cardMargin,
                        4.0,
                        OriginTokens.cardMargin,
                        6.0,
                      ),
                    ),
                    OriginCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: TextField(
                        controller: _noteController,
                        enabled: !_saving,
                        maxLines: 2,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: '请输入备注',
                          hintStyle: TextStyle(
                            fontSize: 14.0,
                            color: OriginTokens.textTertiary(context),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14.0,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
      // 底部常驻保存大按钮
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OriginTokens.cardMargin,
            8.0,
            OriginTokens.cardMargin,
            12.0,
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
              onPressed:
                  _saving || _initializing || !_isFormValid() ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          l.commonSave,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
