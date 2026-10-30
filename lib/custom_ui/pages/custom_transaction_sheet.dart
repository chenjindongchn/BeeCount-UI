import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../providers.dart';
import '../../providers/database_providers.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../pages/tag/widgets/tag_selector.dart';
import '../../pages/transaction/recording/bindings/amount_editor_sheet.dart';
import '../../pages/transaction/recording/bindings/recording_category_section.dart';
import '../../pages/transaction/recording/bindings/recording_save.dart';
import '../styles/origin_sheet_tokens.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../widgets/origin_keypad.dart';

/// 弹出 OriginOS 规范的定制记账底部抽屉
Future<void> showCustomTransactionSheet(
  BuildContext context, {
  String initialKind = 'expense',
  int? initialCategoryId,
  int? initialAccountId,
}) {
  return showOriginBottomSheet<void>(
    context,
    builder: (_) => CustomTransactionSheet(
      initialKind: initialKind,
      initialCategoryId: initialCategoryId,
      initialAccountId: initialAccountId,
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
  });

  final String initialKind;
  final int? initialCategoryId;
  final int? initialAccountId;

  @override
  ConsumerState<CustomTransactionSheet> createState() =>
      _CustomTransactionSheetState();
}

class _CustomTransactionSheetState
    extends ConsumerState<CustomTransactionSheet> {
  // 0=支出, 1=收入, 2=转账
  late int _selectedType;
  late int _ledgerId;

  // 金额相关
  String _amountExpression = '0';

  // 记账属性
  Category? _selectedCategory;
  final TextEditingController _noteController = TextEditingController();
  late DateTime _selectedDate;
  int? _selectedAccountId;
  List<int> _selectedTagIds = [];

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
    _selectedDate = DateTime.now();
    _ledgerId = ref.read(currentLedgerIdProvider);
    _selectedAccountId = widget.initialAccountId;
    _initDefaultAccount();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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

  // --- 键盘计算器逻辑 ---

  void _onDigit(String digit) {
    setState(() {
      if (_amountExpression == '0') {
        _amountExpression = digit;
      } else {
        // 限制小数位数最多2位
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

    if (_selectedType != 2 && _selectedCategory == null) {
      _showToast('请选择记账分类');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      if (_selectedType == 2) {
        // 转账逻辑
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
        final transferCat = await ref.read(transferCategoryProvider.future);
        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: const <File>[],
          excludeFromStats: false,
          excludeFromBudget: false,
          currencyCode: null as String?,
          nativeAmount: null as double?,
        );

        await persistRecordingDraft(
          ref,
          ledgerId: _ledgerId,
          category: transferCat,
          kind: 'transfer',
          result: resultRecord,
          editingId: null,
          onCreated: (_) {},
        );
      } else {
        // 支出 / 收入
        final AmountEditorResult resultRecord = (
          amount: amount,
          continueAdding: continueAdding,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          date: _selectedDate,
          accountId: _selectedAccountId,
          tagIds: _selectedTagIds,
          pendingAttachments: const <File>[],
          excludeFromStats: false,
          excludeFromBudget: false,
          currencyCode: null as String?,
          nativeAmount: null as double?,
        );

        await persistRecordingDraft(
          ref,
          ledgerId: _ledgerId,
          category: _selectedCategory!,
          kind: _currentKind,
          result: resultRecord,
          editingId: null,
          onCreated: (_) {},
        );
      }

      if (!mounted) return;

      if (continueAdding) {
        setState(() {
          _isSaving = false;
          _amountExpression = '0';
          _noteController.clear();
        });
        _showToast('已记一笔，请继续');
      } else {
        Navigator.of(context).pop();
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

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OriginSheetTokens.cornerRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 顶部拖拽热区条（OriginOS 规范）
            OriginSheetDragRegion(
              child: Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ),

            // 2. 居中类型切换 Segmented（无 X 号，严格符合要求）
            _buildTypeSegmented(context),

            const SizedBox(height: 10),

            // 3. 金额大字输入展示区
            _buildAmountDisplay(context),

            const SizedBox(height: 8),

            // 4. 中间内容区域（根据类型区分分类网格或转账账户选择）
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedType == 2)
                      _buildTransferAccounts(context)
                    else
                      _buildCategoryGrid(context),

                    const SizedBox(height: 8),

                    // 5. 备注输入栏
                    _buildNoteInput(context),

                    const SizedBox(height: 8),

                    // 6. 时间、账户、标签选择栏（严格位于备注正下方）
                    _buildMetaSelectorRow(context),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 7. OriginOS 风格数字键盘
            OriginKeypad(
              onDigit: _onDigit,
              onOperator: _onOperator,
              onBackspace: _onBackspace,
              onClear: _onClear,
              onDecimal: _onDecimal,
              onSave: () => _submit(continueAdding: false),
              onSaveAndContinue: () => _submit(continueAdding: true),
            ),
          ],
        ),
      ),
    );
  }

  /// 居中 Segmented 切换胶囊
  Widget _buildTypeSegmented(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segmentBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFECEEF2);

    return Center(
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: segmentBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSegmentItem(context, title: '支出', index: 0),
            _buildSegmentItem(context, title: '收入', index: 1),
            _buildSegmentItem(context, title: '转账', index: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem(
    BuildContext context, {
    required String title,
    required int index,
  }) {
    final isSelected = _selectedType == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (_selectedType != index) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedType = index;
            _selectedCategory = null; // 切换后重置选中分类
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3E3E42) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  )
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1D1D1F))
                : (isDark ? Colors.white54 : const Color(0xFF8E8E93)),
          ),
        ),
      ),
    );
  }

  /// 金额大字展示区
  Widget _buildAmountDisplay(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF2C2C2E),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    _amountExpression,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          ),
        ],
      ),
    );
  }

  /// 5 列精致分类图标网格
  Widget _buildCategoryGrid(BuildContext context) {
    final categoriesAsync = ref.watch(
      recordingCategoriesProvider((ledgerId: _ledgerId, kind: _currentKind)),
    );

    return categoriesAsync.when(
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(
        height: 140,
        child: Center(child: Text('分类加载失败')),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text('暂无分类')),
          );
        }

        // 默认选中第一个
        if (_selectedCategory == null && categories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedCategory == null) {
              setState(() => _selectedCategory = categories.first);
            }
          });
        }

        return Container(
          height: 155,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.vertical,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = _selectedCategory?.id == cat.id;
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final selectedBg = Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: isDark ? 0.25 : 0.15);
              final unselectedBg =
                  isDark ? const Color(0xFF28282C) : const Color(0xFFF4F5F7);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isSelected ? selectedBg : unselectedBg,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Center(
                        child: RecordingCategoryIcon(
                          category: cat,
                          size: 22,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : (isDark ? Colors.white70 : const Color(0xFF4A4A4F)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.white70 : const Color(0xFF333336)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 转账模式下的账户选择
  Widget _buildTransferAccounts(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider(_ledgerId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return accountsAsync.when(
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox(height: 100, child: Text('加载账户失败')),
      data: (accounts) {
        if (_transferToAccountId == null && accounts.length > 1) {
          _transferToAccountId = accounts[1].id;
        }

        final fromAcc = accounts.firstWhere(
          (a) => a.id == _selectedAccountId,
          orElse: () => accounts.first,
        );
        final toAcc = accounts.firstWhere(
          (a) => a.id == _transferToAccountId,
          orElse: () => accounts.last,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAccountPickerChip(
                context,
                label: '转出账户',
                accountName: fromAcc.name,
                onTap: () => _pickAccount(context, accounts, true),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              _buildAccountPickerChip(
                context,
                label: '转入账户',
                accountName: toAcc.name,
                onTap: () => _pickAccount(context, accounts, false),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountPickerChip(
    BuildContext context, {
    required String label,
    required String accountName,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF28282C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 备注输入栏
  Widget _buildNoteInput(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262629) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _noteController,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: '点击填写备注',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Icon(
              Icons.camera_alt_outlined,
              size: 20,
              color: isDark ? Colors.white38 : const Color(0xFF9E9E9E),
            ),
          ],
        ),
      ),
    );
  }

  /// 严格位于备注正下方：时间、账户、标签选择
  Widget _buildMetaSelectorRow(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider(_ledgerId));

    String accountTitle = '账户';
    accountsAsync.whenData((accounts) {
      final acc = accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
        orElse: () => accounts.first,
      );
      accountTitle = acc.name;
    });

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final timeStr = isToday
        ? '今天 ${DateFormat('HH:mm').format(_selectedDate)}'
        : DateFormat('MM-dd HH:mm').format(_selectedDate);

    final tagTitle = _selectedTagIds.isEmpty
        ? '标签'
        : '标签(${_selectedTagIds.length})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 时间选择
          _buildMetaChip(
            context,
            icon: Icons.calendar_today_outlined,
            title: timeStr,
            onTap: _pickDateTime,
          ),
          const SizedBox(width: 8),

          // 账户选择 (非转账模式下)
          if (_selectedType != 2) ...[
            _buildMetaChip(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: accountTitle,
              onTap: () {
                accountsAsync.whenData((accounts) {
                  _pickAccount(context, accounts, true);
                });
              },
            ),
            const SizedBox(width: 8),
          ],

          // 标签选择
          _buildMetaChip(
            context,
            icon: Icons.local_offer_outlined,
            title: tagTitle,
            onTap: _pickTags,
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF262629) : const Color(0xFFF3F4F6);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark ? Colors.white54 : const Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF424242),
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

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _pickAccount(
    BuildContext context,
    List<Account> accounts,
    bool isSourceAccount,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isSourceAccount ? '选择账户' : '选择转入账户',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  itemBuilder: (_, i) {
                    final acc = accounts[i];
                    return ListTile(
                      title: Text(acc.name),
                      onTap: () => Navigator.pop(ctx, acc),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        if (isSourceAccount) {
          _selectedAccountId = selected.id;
        } else {
          _transferToAccountId = selected.id;
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
