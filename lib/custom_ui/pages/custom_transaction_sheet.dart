import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../pages/transaction/recording/bindings/amount_editor_sheet.dart';
import '../../pages/transaction/recording/bindings/recording_save.dart';
import '../../pages/transaction/recording/bindings/recording_category_section.dart';
import '../../pages/transaction/recording/bindings/transfer_inline_accounts.dart';
import 'custom_category_edit_page.dart';
import '../../pages/attachment/attachment_preview_page.dart';
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../../services/attachment_service.dart';
import '../../services/data/note_history_service.dart';
import '../../utils/currencies.dart';
import '../../utils/format_money.dart';
import '../providers/amount_format_provider.dart';
import '../providers/frequent_notes_enabled_provider.dart';
import '../styles/origin_sheet_tokens.dart';
import '../styles/origin_tokens.dart';
import '../widgets/custom_account_grid_picker.dart';
import '../widgets/custom_transaction_flags_sheet.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../widgets/origin_date_picker.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_keypad.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_text_field.dart';
import '../widgets/origin_time_picker.dart';

/// 弹出 OriginOS 规范的定制记账底部抽屉
Future<bool?> showCustomTransactionSheet(
  BuildContext context, {
  String initialKind = 'expense',
  int? initialCategoryId,
  int? initialAccountId,
  int? initialToAccountId,
  DateTime? initialDate,
  List<int>? initialTagIds,
  double? initialAmount,
  String? initialNote,
  int? editingTransactionId,
  bool isCopy = false,
  bool excludeFromStats = false,
  bool excludeFromBudget = false,
}) {
  final isLandscape =
      MediaQuery.orientationOf(context) == Orientation.landscape;
  return showOriginBottomSheet<bool>(
    context,
    heightFactor: isLandscape ? 0.95 : 0.72,
    builder: (_) => CustomTransactionSheet(
      initialKind: initialKind,
      initialCategoryId: initialCategoryId,
      initialAccountId: initialAccountId,
      initialToAccountId: initialToAccountId,
      initialDate: initialDate,
      initialTagIds: initialTagIds,
      initialAmount: initialAmount,
      initialNote: initialNote,
      editingTransactionId: editingTransactionId,
      isCopy: isCopy,
      excludeFromStats: excludeFromStats,
      excludeFromBudget: excludeFromBudget,
      showDragHandle: true,
      dragHandleBarVisible: false,
    ),
  );
}

/// OriginUI 定制记账抽屉主体
class CustomTransactionSheet extends ConsumerStatefulWidget {
  const CustomTransactionSheet({
    super.key,
    this.initialKind = 'expense',
    this.initialCategoryId,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialDate,
    this.initialTagIds,
    this.initialAmount,
    this.initialNote,
    this.editingTransactionId,
    this.isCopy = false,
    this.excludeFromStats = false,
    this.excludeFromBudget = false,
    this.showDragHandle = true,
    this.dragHandleBarVisible = true,
    this.showTopBar = false,
    this.onClose,
  });

  final String initialKind;
  final int? initialCategoryId;
  final int? initialAccountId;
  final int? initialToAccountId;
  final DateTime? initialDate;
  final List<int>? initialTagIds;
  final double? initialAmount;
  final String? initialNote;
  final int? editingTransactionId;
  final bool isCopy;
  final bool excludeFromStats;
  final bool excludeFromBudget;
  final bool showDragHandle;

  /// 是否显示拉手横线（隐藏时仍保留同等高度与下拉关闭热区）
  final bool dragHandleBarVisible;
  final bool showTopBar;
  final VoidCallback? onClose;

  @override
  ConsumerState<CustomTransactionSheet> createState() =>
      _CustomTransactionSheetState();
}

class _CustomTransactionSheetState extends ConsumerState<CustomTransactionSheet>
    with SingleTickerProviderStateMixin {
  // 0=支出, 1=收入, 2=转账
  late int _selectedType;
  int? _animatingToPage;
  late int _ledgerId;
  late final PageController _pageController;
  late final AnimationController _cursorController;

  // 金额相关
  String _amountExpression = '0';

  // 多币种与汇率
  String? _pickedCurrency;
  double? _manualRate;
  bool _rateManuallySet = false;
  bool _fetchingRate = false;
  String? _rateFetchAttemptedFor;

  // 记账属性
  Category? _selectedCategory;
  int? _expandedParentId;
  final TextEditingController _noteController = TextEditingController();
  late DateTime _selectedDate;
  int? _selectedAccountId;
  List<int> _selectedTagIds = [];

  // 交易标记（不计入收支 / 不计入预算）
  late bool _excludeFromStats;
  late bool _excludeFromBudget;

  // 历史常用备注
  List<String> _frequentNotes = [];

  // 图片凭证附件
  List<File> _pendingAttachments = [];
  String? _attachmentDirectoryPath;

  // 转账专用属性
  int? _transferToAccountId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialKind == 'income'
        ? 1
        : widget.initialKind == 'transfer'
            ? 2
            : 0;
    _pageController = PageController(initialPage: _selectedType);
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _selectedDate = widget.initialDate ?? DateTime.now();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _selectedAccountId = widget.initialAccountId;
    _transferToAccountId = widget.initialToAccountId;
    _excludeFromStats = widget.excludeFromStats;
    _excludeFromBudget = widget.excludeFromBudget;

    if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
      _selectedTagIds = List.from(widget.initialTagIds!);
    }
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      final amt = widget.initialAmount!;
      if (amt == amt.roundToDouble()) {
        _amountExpression = amt.toInt().toString();
      } else {
        _amountExpression = amt.toStringAsFixed(2);
      }
    }
    if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
      _noteController.text = widget.initialNote!;
    }
    _noteController.addListener(_onNoteChanged);

    _initDefaultAccount();
    _loadFrequentNotes();
    ref.read(attachmentServiceProvider).getAttachmentDirectory().then((dir) {
      if (mounted) setState(() => _attachmentDirectoryPath = dir.path);
    });
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _pageController.dispose();
    _noteController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initDefaultAccount() async {
    if (_selectedAccountId != null) return;
    try {
      final acc = await defaultRecordingAccount(ref, _currentKind, _ledgerId);
      if (mounted && acc != null) {
        setState(() => _selectedAccountId = acc);
      }
    } catch (_) {}
  }

  String get _currentKind {
    switch (_selectedType) {
      case 1:
        return 'income';
      case 2:
        return 'transfer';
      default:
        return 'expense';
    }
  }

  Future<void> _updateDefaultAccountForKind(int index) async {
    if (index == 2 ||
        widget.initialAccountId != null ||
        widget.editingTransactionId != null) {
      return;
    }
    try {
      final kind = index == 1 ? 'income' : 'expense';
      final acc = await defaultRecordingAccount(ref, kind, _ledgerId);
      if (mounted) {
        setState(() => _selectedAccountId = acc);
      }
    } catch (_) {}
  }

  void _onTypeSelected(int index) {
    if (_selectedType == index) return;
    HapticFeedback.selectionClick();
    _animatingToPage = index;
    setState(() {
      _selectedType = index;
      _selectedCategory = null;
      _expandedParentId = null;
    });
    _updateDefaultAccountForKind(index);
    _loadFrequentNotes();
    _pageController
        .animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: OriginTokens.fastOutSlowIn,
    )
        .then((_) {
      if (mounted) {
        _animatingToPage = null;
      }
    });
  }

  void _onPageChanged(int index) {
    if (_animatingToPage != null) {
      if (index == _animatingToPage) {
        _animatingToPage = null;
      }
      return;
    }
    if (_selectedType != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedType = index;
        _selectedCategory = null;
        _expandedParentId = null;
      });
      _updateDefaultAccountForKind(index);
      _loadFrequentNotes();
    }
  }

  // --- 历史备注智能推荐 ---

  Future<void> _loadFrequentNotes() async {
    if (_selectedType == 2 || !ref.read(frequentNotesEnabledProvider)) {
      if (mounted) setState(() => _frequentNotes = []);
      return;
    }
    try {
      final repo = ref.read(repositoryProvider);
      final notes = await NoteHistoryService.getHistoryNotes(
        repository: repo,
        ledgerId: _ledgerId,
        scope: ref.read(noteHistoryScopeProvider),
        sort: ref.read(noteHistorySortProvider),
        categoryId: _selectedCategory?.id ?? widget.initialCategoryId,
        categorySyncId: ((_selectedCategory?.id ?? widget.initialCategoryId) ?? 0) < 0
            ? _selectedCategory?.syncId
            : null,
        limit: 8,
      );
      if (mounted) {
        final filtered = notes
            .map((e) => e.note.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        setState(() => _frequentNotes = filtered);
      }
    } catch (_) {}
  }

  // --- 多币种与汇率计算 ---

  String _txCurrency(List<Account> accounts) {
    final base = ref.watch(currentLedgerCurrencyProvider);
    if (ref.watch(currencyLockedProvider)) return base;
    if (_selectedType == 2) {
      // 转账以转出账户币种为准
      final fromAcc =
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
      return fromAcc?.currency.toUpperCase() ?? base;
    }
    if (_selectedAccountId != null) {
      final acc =
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
      if (acc != null) {
        return acc.currency.toUpperCase();
      }
    }
    return _pickedCurrency ?? base;
  }

  double _currentRate(String currency, String base) {
    if (ref.watch(currencyLockedProvider) || currency == base) return 1.0;
    if (_rateManuallySet && _manualRate != null && _manualRate! > 0) {
      return _manualRate!;
    }
    final rates = ref.watch(effectiveRatesForLedgerProvider).valueOrNull;
    final er = rates?[currency];
    final rate = er == null ? null : double.tryParse(er.rate);
    if (rate != null && rate.isFinite && rate > 0) {
      return rate;
    }
    return 1.0;
  }

  void _maybeAutoFetchRate(String txCurrency, String base) {
    if (ref.read(currencyLockedProvider) || txCurrency == base || _rateManuallySet || _fetchingRate) return;
    if (_rateFetchAttemptedFor == txCurrency) return;
    final rates = ref.read(effectiveRatesForLedgerProvider).valueOrNull;
    if (rates != null && rates.containsKey(txCurrency)) return;
    _rateFetchAttemptedFor = txCurrency;
    setState(() => _fetchingRate = true);
    refreshExchangeRatesFromUi(ref, force: true, extraQuotes: {txCurrency})
        .whenComplete(() {
      if (mounted) setState(() => _fetchingRate = false);
    });
  }

  Future<void> _pickCurrency(String currentCurrency, String baseCurrency) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showCurrencyPickerSheet(
      context,
      selected: currentCurrency,
      primaryColor: OriginTokens.primary(context),
      title: '选择交易币种',
      rateBase: baseCurrency,
    );
    if (picked == null || !mounted) return;
    final upper = picked.toUpperCase();
    setState(() {
      _pickedCurrency = upper == baseCurrency ? null : upper;
      _rateManuallySet = false;
      _manualRate = null;
      _selectedAccountId = null; // 币种变动后重置账户
    });
  }

  Future<void> _editRate(String currency, String base, double currentRate) async {
    final controller = TextEditingController(
      text: _manualRate?.toString() ?? currentRate.toStringAsFixed(4),
    );
    final confirmed = await showOriginConfirmDialog(
      context,
      title: '微调汇率',
      message: '1 $currency = ? $base',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: OriginTextField.compact(
          controller: controller,
          hintText: '输入汇率折算比例',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
      confirmText: '确定',
      cancelText: '取消',
    );
    if (confirmed == true && mounted) {
      final val = double.tryParse(controller.text.trim());
      if (val != null && val > 0) {
        setState(() {
          _manualRate = val;
          _rateManuallySet = true;
        });
      }
    }
  }

  // --- 图片附件处理 ---

  Future<void> _handleAttachmentAction(
      List<TransactionAttachment> savedAttachments) async {
    final totalCount = savedAttachments.length + _pendingAttachments.length;
    if (totalCount >= AttachmentService.maxAttachments) {
      _showToast('最多添加 ${AttachmentService.maxAttachments} 张图片凭证');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showOriginBottomSheet<int>(
      context,
      builder: (bottomSheetContext) => Container(
        decoration: BoxDecoration(
          color: OriginSheetTokens.cardColor(bottomSheetContext),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(OriginSheetTokens.cornerRadius),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.of(bottomSheetContext).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍摄小票/凭证'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onTap: () => Navigator.of(bottomSheetContext).pop(0),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从手机相册选择'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onTap: () => Navigator.of(bottomSheetContext).pop(1),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;
    final service = ref.read(attachmentServiceProvider);

    if (source == 0) {
      final file = await service.takePhoto();
      if (file != null && mounted) {
        setState(() => _pendingAttachments.add(file));
      }
    } else if (source == 1) {
      final files = await service.pickFromGallery(
        maxCount: AttachmentService.maxAttachments - totalCount,
      );
      if (files.isNotEmpty && mounted) {
        setState(() => _pendingAttachments.addAll(files));
      }
    }
  }

  void _previewAttachments(List<TransactionAttachment> savedAttachments) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewPage(
          attachments: savedAttachments,
          initialIndex: 0,
          allowDelete: true,
          allowAdd: (savedAttachments.length + _pendingAttachments.length) <
              AttachmentService.maxAttachments,
          pendingFiles: _pendingAttachments,
          onPendingFilesChanged: (files) {
            if (mounted) setState(() => _pendingAttachments = files);
          },
          transactionId: widget.editingTransactionId,
        ),
      ),
    );
  }

  // --- 键盘计算器逻辑 ---

  void _onDigit(String digit) {
    setState(() {
      if (_amountExpression == '0') {
        _amountExpression = digit;
      } else {
        final parts = _amountExpression.split(RegExp(r'[\+\-]'));
        final currentNumber = parts.last;
        if (currentNumber.contains('.')) {
          final decParts = currentNumber.split('.');
          if (decParts.length > 1 && decParts[1].length >= 2) {
            return;
          }
        }
        if (_amountExpression.length < 15) {
          _amountExpression += digit;
        }
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      if (_amountExpression.endsWith('+') || _amountExpression.endsWith('-')) {
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1) + op;
      } else {
        _evaluateExpression();
        _amountExpression += op;
      }
    });
  }

  void _onDecimal() {
    setState(() {
      final parts = _amountExpression.split(RegExp(r'[\+\-]'));
      final currentNumber = parts.last;
      if (!currentNumber.contains('.')) {
        if (currentNumber.isEmpty) {
          _amountExpression += '0.';
        } else {
          _amountExpression += '.';
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amountExpression.length <= 1) {
        _amountExpression = '0';
      } else {
        _amountExpression =
            _amountExpression.substring(0, _amountExpression.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _amountExpression = '0';
    });
  }

  double _evaluateExpression() {
    try {
      String expr = _amountExpression;
      if (expr.endsWith('+') || expr.endsWith('-')) {
        expr = expr.substring(0, expr.length - 1);
      }
      final regex = RegExp(r'([\+\-]?[0-9]*\.?[0-9]+)');
      final matches = regex.allMatches(expr);
      double total = 0.0;
      for (final match in matches) {
        final val = double.tryParse(match.group(0) ?? '') ?? 0.0;
        total += val;
      }
      final formatted = total.toStringAsFixed(2);
      return double.parse(formatted);
    } catch (_) {
      return 0.0;
    }
  }

  // --- 保存记账 ---

  Future<void> _submit({required bool continueAdding}) async {
    if (_isSaving) return;

    final amount = _evaluateExpression();
    if (amount <= 0) {
      _showToast('请输入有效金额');
      return;
    }

    final categories = ref
        .read(
          recordingCategoriesProvider((ledgerId: _ledgerId, kind: _currentKind)),
        )
        .valueOrNull;
    Category? initialMatch;
    if (widget.initialCategoryId != null && categories != null) {
      initialMatch =
          categories.where((c) => c.id == widget.initialCategoryId).firstOrNull;
    }
    final catToSave =
        _selectedCategory ?? initialMatch ?? categories?.firstOrNull;

    if (_selectedType != 2 && catToSave == null) {
      _showToast('请选择记账分类');
      return;
    }

    final accounts =
        ref.read(accountsStreamProvider(_ledgerId)).valueOrNull ?? [];
    final baseCurrency = ref.read(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency(accounts);
    final currentRate = _currentRate(txCurrency, baseCurrency);

    // 计算折本位币金额 snapshot
    final nativeAmount =
        (txCurrency == baseCurrency) ? amount : (amount * currentRate);

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_selectedType == 2) {
        if (_selectedAccountId == null || _transferToAccountId == null) {
          _showToast('请选择转出与转入账户');
          setState(() => _isSaving = false);
          return;
        }
        if (_selectedAccountId == _transferToAccountId) {
          _showToast('转出与转入账户不能相同');
          setState(() => _isSaving = false);
          return;
        }

        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: _pendingAttachments,
          excludeFromStats: _excludeFromStats,
          excludeFromBudget: _excludeFromBudget,
          currencyCode: txCurrency,
          nativeAmount: nativeAmount,
        );

        await persistTransferDraft(
          ref,
          ledgerId: _ledgerId,
          result: resultRecord,
          fromAccountId: _selectedAccountId!,
          toAccountId: _transferToAccountId!,
          editingId: widget.editingTransactionId,
          onCreated: (_) {},
        );
      } else {
        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: _pendingAttachments,
          excludeFromStats: _excludeFromStats,
          excludeFromBudget: _excludeFromBudget,
          currencyCode: txCurrency,
          nativeAmount: nativeAmount,
        );

        await persistRecordingDraft(
          ref,
          ledgerId: _ledgerId,
          category: catToSave!,
          kind: _currentKind,
          result: resultRecord,
          editingId: widget.editingTransactionId,
          onCreated: (_) {},
        );
      }

      // 保存附件（编辑模式有新增附件时）
      if (widget.editingTransactionId != null &&
          _pendingAttachments.isNotEmpty) {
        final service = ref.read(attachmentServiceProvider);
        final existingCount = ref
                .read(
                    transactionAttachmentsProvider(widget.editingTransactionId!))
                .valueOrNull
                ?.length ??
            0;
        await service.saveAttachments(
          transactionId: widget.editingTransactionId!,
          sourceFiles: _pendingAttachments,
          startIndex: existingCount,
        );
        ref.read(attachmentListRefreshProvider.notifier).state++;
      }

      // 实时更新系统桌面小组件
      if (mounted) {
        unawaited(updateAppWidget(ref, context));
      }

      if (!mounted) return;

      if (continueAdding) {
        setState(() {
          _isSaving = false;
          _amountExpression = '0';
          _noteController.clear();
          _pendingAttachments.clear();
        });
        _loadFrequentNotes();
        _showToast('已记一笔，请继续');
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('保存失败: $e');
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI 组件构建 ---

  @override
  Widget build(BuildContext context) {
    final cardBg = OriginSheetTokens.cardColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final accountsAsync = ref.watch(accountsStreamProvider(_ledgerId));
    final accounts = accountsAsync.valueOrNull ?? [];
    final baseCurrency = ref.watch(currentLedgerCurrencyProvider);
    final txCurrency = _txCurrency(accounts);
    final showFrequentNotes = ref.watch(frequentNotesEnabledProvider);

    // 尝试拉取外币汇率
    _maybeAutoFetchRate(txCurrency, baseCurrency);

    final savedAttachments = widget.editingTransactionId != null
        ? ref
                .watch(transactionAttachmentsProvider(
                    widget.editingTransactionId!))
                .valueOrNull ??
            <TransactionAttachment>[]
        : <TransactionAttachment>[];

    if (isLandscape) {
      return Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(OriginSheetTokens.cornerRadius),
          ),
        ),
        child: Column(
          children: [
            if (widget.showDragHandle)
              OriginSheetDragRegion(
                child: SizedBox(
                  height: 12,
                  child: widget.dragHandleBarVisible
                      ? Center(
                          child: Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 11,
                    child: Column(
                      children: [
                        _buildTopHeader(context),
                        const SizedBox(height: 4),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: 3,
                            onPageChanged: _onPageChanged,
                            itemBuilder: (context, index) {
                              switch (index) {
                                case 0:
                                  return _buildCategoryGrid(context,
                                      kind: 'expense', crossAxisCount: 4);
                                case 1:
                                  return _buildCategoryGrid(context,
                                      kind: 'income', crossAxisCount: 4);
                                case 2:
                                  return _buildTransferAccounts(
                                      context, accounts);
                                default:
                                  return const SizedBox.shrink();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 0.6,
                    indent: 4,
                    endIndent: 4,
                    color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                  ),
                  Expanded(
                    flex: 12,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: MediaQuery.of(context).padding.right > 0
                            ? MediaQuery.of(context).padding.right
                            : 6.0,
                        bottom: bottomInset > 0 ? bottomInset * 0.35 : 2.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildAmountDisplay(context,
                                  accounts: accounts,
                                  txCurrency: txCurrency,
                                  baseCurrency: baseCurrency,
                                  compact: true),
                              const SizedBox(height: 2),
                              _buildNoteInput(context, savedAttachments),
                              if (showFrequentNotes && _frequentNotes.isNotEmpty)
                                _buildFrequentNotesRow(context),
                              _buildAttachmentThumbnails(
                                  context, savedAttachments),
                              const SizedBox(height: 3),
                              _buildMetaSelectorRow(context),
                            ],
                          ),
                          OriginKeypad(
                            keyHeight: 36,
                            onDigit: _onDigit,
                            onOperator: _onOperator,
                            onBackspace: _onBackspace,
                            onClear: _onClear,
                            onDecimal: _onDecimal,
                            onSave: () => _submit(continueAdding: false),
                            onSaveAndContinue: () =>
                                _submit(continueAdding: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OriginSheetTokens.cornerRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 顶部拖拽热区条
          if (widget.showDragHandle)
            OriginSheetDragRegion(
              child: SizedBox(
                height: 16,
                child: widget.dragHandleBarVisible
                    ? Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )
                    : null,
              ),
            ),

          // 2. 顶部导航栏（账本名称胶囊 + 居中类型切换 + 返回按钮）
          _buildTopHeader(context),

          const SizedBox(height: 2),

          // 3. 支持左右滑动切换的分类网格与转账视图
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: 3,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _buildCategoryGrid(context, kind: 'expense');
                  case 1:
                    return _buildCategoryGrid(context, kind: 'income');
                  case 2:
                    return _buildTransferAccounts(context, accounts);
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),

          // 4. 金额大字输入展示区（左侧承接支出账户选择，右侧承接币种与金额大字）
          _buildAmountDisplay(context,
              accounts: accounts,
              txCurrency: txCurrency,
              baseCurrency: baseCurrency),

          const SizedBox(height: 4),

          // 5. 备注输入栏（包含标签「#」入口与拍照相机入口）
          _buildNoteInput(context, savedAttachments),

          // 5.1 历史常用备注横向流（支持在设置中开关控制，固定在此展示，点击后不消失）
          if (showFrequentNotes && _frequentNotes.isNotEmpty)
            _buildFrequentNotesRow(context),

          // 5.2 图片凭证缩略图流（存在已有/新增小票时展开）
          if (savedAttachments.isNotEmpty || _pendingAttachments.isNotEmpty)
            _buildAttachmentThumbnails(context, savedAttachments),

          const SizedBox(height: 5),

          // 6. 元数据胶囊栏（日期、时间、不计入收支/预算标记）
          _buildMetaSelectorRow(context),

          const SizedBox(height: 4),

          // 7. OriginOS 风格数字键盘
          Padding(
            padding: EdgeInsets.only(
                bottom: bottomInset > 0 ? bottomInset * 0.35 : 2.0),
            child: OriginKeypad(
              onDigit: _onDigit,
              onOperator: _onOperator,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onDecimal: _onDecimal,
              onSave: () => _submit(continueAdding: false),
              onSaveAndContinue: () => _submit(continueAdding: true),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部栏容器（包含就地切换账本、返回与类型切换）
  Widget _buildTopHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ledgersAsync = ref.watch(localLedgersProvider);
    final hasMultipleLedgers = (ledgersAsync.valueOrNull?.length ?? 0) > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 左侧：返回键（如 showTopBar）或账本切换图标按钮
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showTopBar) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose ?? () => Navigator.maybePop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                      ),
                    ),
                  ),
                  if (hasMultipleLedgers) const SizedBox(width: 8),
                ],

                // 账本图标按钮：仅在存在多份账本时显示，点击可就地换账本
                if (hasMultipleLedgers)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _showLedgerSwitchDialog,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF28282C)
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.book_outlined,
                          size: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 居中：支出、收入、转账 Segmented
          _buildTypeSegmented(context),
        ],
      ),
    );
  }

  void _showLedgerSwitchDialog() {
    showOriginLedgerPickerDialog(context).then((_) {
      if (!mounted) return;
      final newLedgerId = ref.read(currentLedgerIdProvider);
      if (newLedgerId != _ledgerId) {
        setState(() {
          _ledgerId = newLedgerId;
          _selectedCategory = null;
          _selectedAccountId = null;
          _transferToAccountId = null;
          _expandedParentId = null;
        });
        _initDefaultAccount();
        _loadFrequentNotes();
      }
    });
  }

  /// 居中 Segmented 切换胶囊
  Widget _buildTypeSegmented(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 196,
        child: OriginSegmentedControl<int>(
          items: const [0, 1, 2],
          selectedItem: _selectedType,
          height: 30,
          onSelected: _onTypeSelected,
          labelBuilder: (index) {
            switch (index) {
              case 0:
                return '支出';
              case 1:
                return '收入';
              case 2:
                return '转账';
              default:
                return '';
            }
          },
        ),
      ),
    );
  }

  /// 金额输入展示区（左侧承接支出账户选择，右侧承接币种与金额大字输入）
  Widget _buildAmountDisplay(
    BuildContext context, {
    required List<Account> accounts,
    required String txCurrency,
    required String baseCurrency,
    bool compact = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = getCurrencySymbol(txCurrency);
    final isForeign = txCurrency != baseCurrency;
    final rate = _currentRate(txCurrency, baseCurrency);
    final amountVal = _evaluateExpression();
    final convertedAmount = amountVal * rate;

    // 当前选中的账户名称（默认或用户选中的支出/收入账户）
    String accountTitle = '选择账户';
    if (accounts.isNotEmpty && _selectedAccountId != null) {
      final acc =
          accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
      if (acc != null) {
        accountTitle = acc.name;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 4 : 8, 16, compact ? 1 : 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 账户选择胶囊（非转账模式下，承接在价格输入行左侧）
              if (_selectedType != 2) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pickAccount(context, accounts, true),
                  child: Container(
                    height: compact ? 28 : 32,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF28282C)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(compact ? 14 : 16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: compact ? 13 : 15,
                          color: isDark ? Colors.white70 : const Color(0xFF424242),
                        ),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: Text(
                            accountTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 11.5 : 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: compact ? 14 : 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // 点击币种符号：弹出币种选择器（锁定币种时彻底隐藏）
              if (!ref.watch(currencyLockedProvider)) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _pickCurrency(txCurrency, baseCurrency),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF28282C)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          symbol.isNotEmpty ? symbol : txCurrency,
                          style: TextStyle(
                            fontSize: compact ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF2C2C2E),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // 金额大字显示与光标
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _amountExpression,
                        style: TextStyle(
                          fontSize: compact ? 22 : 26,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                        ),
                      ),
                      FadeTransition(
                        opacity: _cursorController,
                        child: Container(
                          width: 1.8,
                          height: compact ? 22 : 26,
                          margin: const EdgeInsets.only(left: 2.5),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 外币折算行（微型 OriginUI 汇率卡片）
          if (isForeign) ...[
            const SizedBox(height: 3),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _editRate(txCurrency, baseCurrency, rate),
              child: Row(
                children: [
                  Text(
                    '≈ ${getCurrencySymbol(baseCurrency)}${formatMoneyCompact(convertedAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: OriginTokens.primary(context),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(1 $txCurrency = ${rate.toStringAsFixed(4)} $baseCurrency)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.edit_outlined,
                    size: 10.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: compact ? 2 : 3),
          Divider(
            height: 1,
            thickness: 0.6,
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }

  /// 分类网格（支持一级分类 + 二级子分类滑动展开 + 末尾快捷「+ 添加」）
  Widget _buildCategoryGrid(
    BuildContext context, {
    required String kind,
    int crossAxisCount = 5,
  }) {
    final categoriesAsync = ref.watch(
      recordingCategoriesProvider((ledgerId: _ledgerId, kind: kind)),
    );

    return categoriesAsync.when(
      loading: () => _buildCategoryGridSkeleton(context,
          crossAxisCount: crossAxisCount),
      error: (_, __) => const Center(child: Text('分类加载失败')),
      data: (allCategories) {
        if (allCategories.isEmpty) {
          return Center(
            child: TextButton.icon(
              onPressed: () => _openCategoryEdit(),
              icon: const Icon(Icons.add),
              label: const Text('添加新分类'),
            ),
          );
        }

        // 分割一级分类
        final parents =
            allCategories.where((c) => c.level == 1).toList();

        // 默认选中
        Category? initialMatch;
        if (widget.initialCategoryId != null && _currentKind == kind) {
          initialMatch = allCategories
              .where((c) => c.id == widget.initialCategoryId)
              .firstOrNull;
        }
        final currentSelected =
            (_currentKind == kind && _selectedCategory != null)
                ? _selectedCategory
                : (initialMatch ?? parents.firstOrNull);

        // 如果当前选中的分类有二级子分类，或者父级展开中
        final activeParentId = _expandedParentId ??
            (currentSelected?.parentId ?? currentSelected?.id);
        final subCategories = activeParentId != null
            ? allCategories.where((c) => c.parentId == activeParentId).toList()
            : <Category>[];

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Column(
          children: [
            // 1. 一级分类网格 + 末尾添加按钮
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.vertical,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.92,
                  ),
                  itemCount: parents.length + 1, // +1 给末尾「+ 添加」
                  itemBuilder: (context, index) {
                    if (index == parents.length) {
                      // 末尾添加分类按钮
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openCategoryEdit,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black26,
                                  style: BorderStyle.solid,
                                  width: 1.2,
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '添加',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final cat = parents[index];
                    final isParentActive =
                        (currentSelected?.id == cat.id ||
                            currentSelected?.parentId == cat.id);
                    final hasChildren =
                        allCategories.any((c) => c.parentId == cat.id);

                    final selectedBg = Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: isDark ? 0.25 : 0.15);
                    final unselectedBg = isDark
                        ? const Color(0xFF28282C)
                        : const Color(0xFFF4F5F7);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategory = cat;
                          _expandedParentId = hasChildren ? cat.id : null;
                        });
                        _loadFrequentNotes();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isParentActive
                                      ? selectedBg
                                      : unselectedBg,
                                  shape: BoxShape.circle,
                                  border: isParentActive
                                      ? Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: RecordingCategoryIcon(
                                    category: cat,
                                    size: 19,
                                    color: isParentActive
                                        ? Theme.of(context).colorScheme.primary
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF4A4A4F)),
                                  ),
                                ),
                              ),
                              if (hasChildren)
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isParentActive
                                          ? Theme.of(context).colorScheme.primary
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.black26),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isParentActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isParentActive
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF333336)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. 二级子分类展开滑动胶囊栏
            if (subCategories.isNotEmpty)
              Container(
                height: 32,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: subCategories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      // 父分类自身
                      final parentCat = parents
                          .where((p) => p.id == activeParentId)
                          .firstOrNull;
                      final isSelected =
                          currentSelected?.id == parentCat?.id;
                      return _buildSubCategoryChip(
                        context,
                        label: '全部',
                        isSelected: isSelected,
                        onTap: () {
                          if (parentCat != null) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = parentCat);
                            _loadFrequentNotes();
                          }
                        },
                      );
                    }
                    final child = subCategories[idx - 1];
                    final isSelected = currentSelected?.id == child.id;
                    return _buildSubCategoryChip(
                      context,
                      label: child.name,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = child);
                        _loadFrequentNotes();
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSubCategoryChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = OriginTokens.primary(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? const Color(0xFF28282C) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: primary, width: 1.0)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? primary
                  : (isDark ? Colors.white70 : const Color(0xFF4A4A4F)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCategoryEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomCategoryEditPage(kind: _currentKind),
      ),
    );
    if (mounted) {
      ref.invalidate(
        recordingCategoriesProvider((ledgerId: _ledgerId, kind: _currentKind)),
      );
    }
  }

  /// 分类网格骨架屏
  Widget _buildCategoryGridSkeleton(BuildContext context,
      {int crossAxisCount = 5}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleColor =
        isDark ? const Color(0xFF28282C) : const Color(0xFFF4F5F7);
    final labelColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.92,
        ),
        itemCount: 10,
        itemBuilder: (context, index) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(color: circleColor, shape: BoxShape.circle),
            ),
            const SizedBox(height: 2),
            Container(
              width: 26,
              height: 7,
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 转账模式下的账户选择（强化过滤与同币种智能匹配）
  Widget _buildTransferAccounts(
      BuildContext context, List<Account> allAccounts) {
    final eligible = allAccounts
        .where((a) => isTransferInlineAccountEligible(a,
            pinnedIds: const {},
            editing: widget.editingTransactionId != null))
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (eligible.isEmpty) {
      return const Center(child: Text('暂无可转账账户，请先添加账户'));
    }

    _selectedAccountId ??= eligible.first.id;
    if (_transferToAccountId == null && eligible.length > 1) {
      _transferToAccountId = eligible[1].id;
    }

    final fromAcc = eligible
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull ??
        eligible.first;
    final toAcc = eligible
            .where((a) => a.id == _transferToAccountId)
            .firstOrNull ??
        (eligible.length > 1 ? eligible[1] : eligible.first);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAccountPickerChip(
              context,
              label: '转出账户',
              accountName: fromAcc.name,
              currency: fromAcc.currency,
              onTap: () => _pickAccount(context, eligible, true),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            _buildAccountPickerChip(
              context,
              label: '转入账户',
              accountName: toAcc.name,
              currency: toAcc.currency,
              onTap: () => _pickAccount(context, eligible, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPickerChip(
    BuildContext context, {
    required String label,
    required String accountName,
    required String currency,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF28282C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              currency,
              style: TextStyle(
                fontSize: 9.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 备注输入栏（最左侧承接「#」标签选择标志，右侧包含拍照相机入口）
  Widget _buildNoteInput(
    BuildContext context,
    List<TransactionAttachment> savedAttachments,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalAttachments =
        savedAttachments.length + _pendingAttachments.length;
    final hasTags = _selectedTagIds.isNotEmpty;
    final primary = OriginTokens.primary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OriginTextField.compact(
        controller: _noteController,
        hintText: '点击填写备注',
        clearable: true,
        prefixIcon: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            _pickTags();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: hasTags
                        ? primary
                        : (isDark ? Colors.white54 : const Color(0xFF757575)),
                  ),
                ),
                if (hasTags) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${_selectedTagIds.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        suffixIcon: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleAttachmentAction(savedAttachments),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 20,
                  color: totalAttachments > 0
                      ? OriginTokens.primary(context)
                      : (isDark ? Colors.white54 : const Color(0xFF757575)),
                ),
                if (totalAttachments > 0)
                  Positioned(
                    right: 0,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: OriginTokens.primary(context),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 10,
                        minHeight: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 历史高频备注快捷胶囊流（固定展示，支持点击切换/选中态高亮）
  Widget _buildFrequentNotesRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = OriginTokens.primary(context);

    return Container(
      height: 26,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _frequentNotes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final note = _frequentNotes[index];
          final isSelected = _noteController.text.trim() == note.trim();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              if (isSelected) {
                _noteController.clear();
              } else {
                _noteController.text = note;
              }
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary.withValues(alpha: isDark ? 0.3 : 0.15)
                    : (isDark
                        ? const Color(0xFF262629)
                        : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(13),
                border: isSelected
                    ? Border.all(color: primary.withValues(alpha: 0.6), width: 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? primary
                        : (isDark ? Colors.white70 : const Color(0xFF555555)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 小票凭证缩略图展示流（可删除、大图画廊预览）
  Widget _buildAttachmentThumbnails(
    BuildContext context,
    List<TransactionAttachment> savedAttachments,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = savedAttachments.length + _pendingAttachments.length;

    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: totalCount +
            (totalCount < AttachmentService.maxAttachments ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == totalCount) {
            // 末尾添加图片按键
            return GestureDetector(
              onTap: () => _handleAttachmentAction(savedAttachments),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black12,
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            );
          }

          // 已有远程/本地附件
          final isSaved = index < savedAttachments.length;
          Widget imageWidget;
          if (isSaved) {
            final att = savedAttachments[index];
            final fullPath = _attachmentDirectoryPath != null
                ? '$_attachmentDirectoryPath/${att.fileName}'
                : '';
            imageWidget = fullPath.isNotEmpty
                ? Image.file(
                    File(fullPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 20),
                  )
                : const Icon(Icons.image, size: 20);
          } else {
            final file =
                _pendingAttachments[index - savedAttachments.length];
            imageWidget = Image.file(file, fit: BoxFit.cover);
          }

          return GestureDetector(
            onTap: () => _previewAttachments(savedAttachments),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: imageWidget,
                  ),
                ),
                // 仅针对待上传附件允许在此快速直接删除
                if (!isSaved)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _pendingAttachments
                              .removeAt(index - savedAttachments.length);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 元数据选择栏：日期、时间、记账标记（账户与标签已优化至专属行）
  Widget _buildMetaSelectorRow(BuildContext context) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final dateStr = isToday ? '今天' : DateFormat('MM-dd').format(_selectedDate);
    final timeStr = DateFormat('HH:mm').format(_selectedDate);

    // 标记状态胶囊文字与激活状态
    String flagTitle = '标记';
    bool flagActive = false;
    if (_excludeFromStats && _excludeFromBudget) {
      flagTitle = '不计收支/预算';
      flagActive = true;
    } else if (_excludeFromStats) {
      flagTitle = '不计收支';
      flagActive = true;
    } else if (_excludeFromBudget) {
      flagTitle = '不计预算';
      flagActive = true;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 原厂规范日期胶囊
          _buildMetaChip(
            context,
            icon: Icons.calendar_today_outlined,
            title: dateStr,
            onTap: _pickDate,
          ),
          const SizedBox(width: 6),

          // 原厂规范时间胶囊
          _buildMetaChip(
            context,
            icon: Icons.access_time_rounded,
            title: timeStr,
            onTap: _pickTime,
          ),

          // 交易高级标记（仅在非转账模式下可见）
          if (_selectedType != 2) ...[
            const SizedBox(width: 6),
            _buildMetaChip(
              context,
              icon: Icons.bookmark_border_rounded,
              title: flagTitle,
              isActive: flagActive,
              onTap: _pickFlags,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = OriginTokens.primary(context);
    final bg = isActive
        ? primary.withValues(alpha: isDark ? 0.3 : 0.15)
        : (isDark ? const Color(0xFF262629) : const Color(0xFFF3F4F6));
    final textColor = isActive
        ? primary
        : (isDark ? Colors.white70 : const Color(0xFF424242));
    final iconColor = isActive
        ? primary
        : (isDark ? Colors.white54 : const Color(0xFF757575));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? Border.all(color: primary.withValues(alpha: 0.5), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: iconColor,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 弹窗选择逻辑 ---

  Future<void> _pickFlags() async {
    final result = await CustomTransactionFlagsSheet.show(
      context,
      excludeFromStats: _excludeFromStats,
      excludeFromBudget: _excludeFromBudget,
      kind: _currentKind,
    );
    if (result != null && mounted) {
      setState(() {
        _excludeFromStats = result.excludeFromStats;
        _excludeFromBudget = result.excludeFromBudget;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showOriginDatePicker(
      context,
      initial: _selectedDate,
      minDate: DateTime(2000, 1, 1),
      maxDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selectedDate.hour,
        _selectedDate.minute,
        _selectedDate.second,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showOriginTimePicker(
      context,
      initial: TimeOfDay(
        hour: _selectedDate.hour,
        minute: _selectedDate.minute,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
        _selectedDate.second,
      );
    });
  }

  Future<void> _pickAccount(
    BuildContext context,
    List<Account> accounts,
    bool isSourceAccount,
  ) async {
    final currentId =
        isSourceAccount ? _selectedAccountId : _transferToAccountId;

    final selectedId = await CustomAccountGridPicker.show(
      context,
      accounts: accounts,
      currentAccountId: currentId,
      showNoAccountOption: _selectedType != 2 && isSourceAccount,
      title: isSourceAccount ? '选择账户' : '选择转入账户',
    );

    if (selectedId != null && mounted) {
      setState(() {
        final newId = selectedId == CustomAccountGridPicker.noAccountId
            ? null
            : selectedId;
        if (isSourceAccount) {
          _selectedAccountId = newId;
        } else {
          _transferToAccountId = newId;
        }
      });
    }
  }

  Future<void> _pickTags() async {
    final result = await TagSelector.show(
      context,
      selectedTagIds: _selectedTagIds,
    );
    if (result != null && mounted) {
      setState(() => _selectedTagIds = result);
    }
  }
}
