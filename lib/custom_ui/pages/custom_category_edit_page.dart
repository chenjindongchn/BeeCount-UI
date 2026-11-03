import 'dart:async';
import 'dart:io';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../data/repositories/local/local_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/category/category_migration_page.dart';
import '../../pages/category/editor/bindings/category_icon_catalog.dart';
import '../../pages/category/editor/bindings/category_icon_draft.dart';
import '../../pages/category/editor/bindings/category_line_icon_names.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/system/logger_service.dart';
import '../../utils/category_utils.dart';
import '../../utils/shared_ledger_picker_filter.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_text_field.dart';
import 'custom_category_detail_page.dart';

/// vivo OriginOS 风格自定义分类编辑/新建页面 (CustomCategoryEditPage)
///
/// 遵循 OriginUI 交互与排版规范：
/// 1. 顶栏右上角采用双圆点 (OriginMoreButton)，收拢“分类明细”、“迁移合并”与“删除分类”操作；
/// 2. 分类名称输入框采用标准 OriginTextField，上方带独立次级标题，彻底告别原版上下连体框样式；
/// 3. 保存主操作常驻置底 (Bottom CTA 原则)，尺寸 46dp，圆角 23dp，包裹 SafeArea；
/// 4. 采用 OriginCard 模块化分层，圆润温润，弹窗与抽屉均使用 OriginOS 统一标准。
class CustomCategoryEditPage extends ConsumerStatefulWidget {
  final db.Category? category;
  final db.Category? parentCategory;
  final String kind;

  const CustomCategoryEditPage({
    super.key,
    this.category,
    this.parentCategory,
    required this.kind,
  });

  @override
  ConsumerState<CustomCategoryEditPage> createState() =>
      _CustomCategoryEditPageState();
}

class _CustomCategoryEditPageState
    extends ConsumerState<CustomCategoryEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  Timer? _debounce;
  bool _busy = false;
  bool _picking = false;
  bool _duplicate = false;
  bool _isSubCategory = false;
  String _icon = 'category';
  String? _customPath;
  bool _newImage = false;
  Future<String?>? _resolvedIcon;
  BeeCategoryIconSource _iconSource = BeeCategoryIconSource.preset;
  db.Category? _parent;
  String? _nameErrorText;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _icon = categoryLineIconNames.containsKey(category?.icon)
        ? category!.icon!
        : 'category';
    _iconSource = category?.iconType == 'custom'
        ? BeeCategoryIconSource.custom
        : BeeCategoryIconSource.preset;
    _customPath = category?.customIconPath;
    _resolvePreview();

    _isSubCategory =
        category != null ? category.level == 2 : widget.parentCategory != null;
    _parent = widget.parentCategory;

    if (_isSubCategory && category?.parentId != null) {
      ref
          .read(repositoryProvider)
          .getCategoryById(category!.parentId!)
          .then((v) {
        if (mounted) setState(() => _parent = v);
      });
    }

    _nameController.addListener(() {
      _debounce?.cancel();
      if (_duplicate && mounted) {
        setState(() {
          _duplicate = false;
          _nameErrorText = null;
        });
      }
      _debounce = Timer(const Duration(milliseconds: 400), _checkDuplicate);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _resolvePreview() {
    final path = _customPath;
    _resolvedIcon = path == null
        ? null
        : path.startsWith('/')
            ? Future.value(path)
            : ref.read(categoryIconServiceProvider).resolveIconPath(path);
  }

  Future<void> _checkDuplicate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) return;
    try {
      final result = await ref.read(repositoryProvider).isCategoryNameDuplicate(
            name: name,
            kind: widget.kind,
            excludeId: widget.category?.id,
          );
      if (mounted && name == _nameController.text.trim()) {
        setState(() {
          _duplicate = result;
          _nameErrorText =
              result ? AppLocalizations.of(context).categoryNameDuplicate : null;
        });
      }
    } catch (e, s) {
      logger.error('CustomCategoryEditPage', '分类重名检查失败', e, s);
    }
  }

  Future<void> _selectParent() async {
    final repo = ref.read(repositoryProvider);
    final l10n = AppLocalizations.of(context);

    // 获取所有可用的一级分类并附加交易笔数
    var all = await repo.getTopLevelCategories(widget.kind);
    if (repo is LocalRepository) {
      final scope = await repo.db.loadLedgerPickerContext(null);
      all = await repo.db
          .filterCategoriesForLedger(all, scope, topLevelOnly: true);
    }

    final parentCandidates = await Future.wait(all.map((c) async {
      final count = await repo.getTransactionCountByCategory(c.id);
      final enabled = await repo.hasSubCategories(c.id) || count == 0;
      return (category: c, count: count, enabled: enabled);
    }));

    if (!mounted) return;

    final selected = await showOriginBottomSheet<db.Category>(
      context,
      builder: (bottomSheetContext) {
        final primary = ref.watch(primaryColorProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部标题
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  l10n.categorySelectParentTitle,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: OriginTokens.textPrimary(context),
                  ),
                ),
              ),
              const OriginDivider(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: parentCandidates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36.0),
                        child: Center(
                          child: Text(
                            l10n.categoryEmpty,
                            style: TextStyle(
                              fontSize: 14.0,
                              color: OriginTokens.textTertiary(context),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: parentCandidates.length,
                        separatorBuilder: (_, __) =>
                            const OriginDivider(startIndent: 60.0),
                        itemBuilder: (ctx, index) {
                          final item = parentCandidates[index];
                          final isSelected = _parent?.id == item.category.id;
                          final categoryName = CategoryUtils.getDisplayName(
                            item.category.name,
                            context,
                          );

                          return InkWell(
                            onTap: item.enabled
                                ? () {
                                    HapticFeedback.lightImpact();
                                    Navigator.pop(ctx, item.category);
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18.0,
                                vertical: 12.0,
                              ),
                              child: Row(
                                children: [
                                  RecordingCategoryIcon(
                                    category: item.category,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 14.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          categoryName,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: item.enabled
                                                ? (isSelected
                                                    ? primary
                                                    : OriginTokens.textPrimary(
                                                        context))
                                                : OriginTokens.textTertiary(
                                                    context),
                                          ),
                                        ),
                                        if (item.count > 0 || !item.enabled)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              item.enabled
                                                  ? l10n.tagTransactionCount(
                                                      item.count)
                                                  : l10n.tagTransactionCount(
                                                      item.count),
                                              style: TextStyle(
                                                fontSize: 12.0,
                                                color: OriginTokens.textTertiary(
                                                    context),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: primary,
                                      size: 20,
                                    )
                                  else if (!item.enabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 3.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: OriginTokens.cardSecondary(context),
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Text(
                                        '已有交易',
                                        style: TextStyle(
                                          fontSize: 11.0,
                                          color: OriginTokens.textTertiary(
                                              context),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12.0),
            ],
          ),
        );
      },
    );

    if (mounted && selected != null) {
      setState(() => _parent = selected);
    }
  }

  Future<void> _pickIcon() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    final l10n = AppLocalizations.of(context);
    try {
      final file = await ref
          .read(categoryIconPickerProvider)
          .pick(context, ref.read(primaryColorProvider));
      if (file == null || !mounted) return;
      await ref.read(categoryIconServiceProvider).validateImage(file);
      if (!mounted) return;
      setState(() {
        _customPath = file.path;
        _newImage = true;
        _iconSource = BeeCategoryIconSource.custom;
        _resolvePreview();
      });
      HapticFeedback.lightImpact();
    } catch (e, s) {
      logger.error('CustomCategoryEditPage', '选择自定义分类图标失败', e, s);
      if (mounted) {
        await showOriginCustomDialog<void>(
          context,
          child: OriginDialog(
            title: l10n.categoryCustomIconError,
            content: Text(
              '$e',
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            cancelText: l10n.commonConfirm,
            onCancel: () => Navigator.pop(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _saveCategory() async {
    if (_busy || _picking) return;

    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameErrorText = l10n.categoryNameRequired);
      return;
    }
    if (name.length > 10) {
      setState(() => _nameErrorText = l10n.categoryNameTooLong);
      return;
    }

    if (_isSubCategory && _parent == null) {
      await showOriginCustomDialog<void>(
        context,
        child: OriginDialog(
          title: l10n.categoryParentRequiredTitle,
          content: Text(
            l10n.categoryParentRequired,
            style: TextStyle(
              fontSize: 14.0,
              color: OriginTokens.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          cancelText: l10n.commonConfirm,
          onCancel: () => Navigator.pop(context),
        ),
      );
      return;
    }

    if (_iconSource == BeeCategoryIconSource.custom && _customPath == null) {
      await showOriginCustomDialog<void>(
        context,
        child: OriginDialog(
          title: l10n.categorySaveError,
          content: Text(
            l10n.categoryCustomIconRequired,
            style: TextStyle(
              fontSize: 14.0,
              color: OriginTokens.textPrimary(context),
            ),
            textAlign: TextAlign.center,
          ),
          cancelText: l10n.commonConfirm,
          onCancel: () => Navigator.pop(context),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    final database = ref.read(databaseProvider);
    final service = ref.read(categoryIconServiceProvider);

    try {
      if (await repo.isCategoryNameDuplicate(
        name: name,
        kind: widget.kind,
        excludeId: widget.category?.id,
      )) {
        if (mounted) {
          setState(() {
            _duplicate = true;
            _nameErrorText = l10n.categoryNameDuplicate;
          });
          await showOriginCustomDialog<void>(
            context,
            child: OriginDialog(
              title: l10n.categorySaveError,
              content: Text(
                l10n.categoryNameDuplicate,
                style: TextStyle(
                  fontSize: 14.0,
                  color: OriginTokens.textPrimary(context),
                ),
                textAlign: TextAlign.center,
              ),
              cancelText: l10n.commonConfirm,
              onCancel: () => Navigator.pop(context),
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      await database.transaction(() async {
        final id = widget.category?.id ??
            (_isSubCategory
                ? await repo.createSubCategory(
                    parentId: _parent!.id,
                    name: name,
                    kind: widget.kind,
                    icon: _icon,
                  )
                : await repo.createCategory(
                    name: name,
                    kind: widget.kind,
                    icon: _icon,
                  ));

        if (_iconSource == BeeCategoryIconSource.custom && _newImage) {
          _customPath = await service.saveCustomIcon(File(_customPath!), id);
          _newImage = false;
          _resolvePreview();
        }

        if (isEditing) {
          await repo.updateCategory(
            id,
            name: name,
            icon: _icon,
            parentId: _isSubCategory ? _parent?.id : null,
          );
        }

        await repo.updateCategoryIcon(
          id,
          iconType: _iconSource == BeeCategoryIconSource.custom
              ? 'custom'
              : 'material',
          icon: _icon,
          customIconPath: _iconSource == BeeCategoryIconSource.custom
              ? _customPath
              : null,
        );
      });

      if (!mounted) return;
      _refresh();
      HapticFeedback.lightImpact();
      showBeeToast(
        context,
        isEditing
            ? l10n.categoryUpdated(name)
            : _isSubCategory
                ? l10n.categorySubCategoryCreated(name)
                : l10n.categoryCreated(name),
      );
      Navigator.pop(context, true);
    } catch (e, s) {
      logger.error('CustomCategoryEditPage', '保存分类失败', e, s);
      if (mounted) {
        await showOriginCustomDialog<void>(
          context,
          child: OriginDialog(
            title: l10n.categorySaveError,
            content: Text(
              '$e',
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            cancelText: l10n.commonConfirm,
            onCancel: () => Navigator.pop(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(categoriesProvider);
    ref.invalidate(categoriesWithCountProvider);
    if (widget.kind == 'transfer') ref.invalidate(transferCategoryProvider);
    final ledgerId = ref.read(currentLedgerIdProvider);
    if (ledgerId > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));
  }

  Future<void> _deleteCategory() async {
    if (!isEditing || _busy || _picking) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(repositoryProvider);

    setState(() => _busy = true);
    try {
      var count = await repo.getTransactionCountByCategory(widget.category!.id);
      if (widget.category!.level == 1) {
        for (final c in await repo.getSubCategories(widget.category!.id)) {
          count += await repo.getTransactionCountByCategory(c.id);
        }
      }

      if (!mounted) return;

      if (count > 0) {
        await showOriginCustomDialog<void>(
          context,
          child: OriginDialog(
            title: l10n.categoryCannotDelete,
            content: Text(
              l10n.categoryCannotDeleteMessage(count),
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            cancelText: l10n.commonConfirm,
            onCancel: () => Navigator.pop(context),
          ),
        );
        return;
      }

      final confirmed = await showOriginConfirmDialog(
        context,
        title: l10n.categoryDeleteConfirmTitle,
        message: l10n.categoryDeleteConfirmMessage(widget.category!.name),
        confirmText: l10n.commonDelete,
        cancelText: l10n.commonCancel,
        isDanger: true,
      );

      if (confirmed != true || !mounted) return;

      await repo.deleteCategory(widget.category!.id);
      if (!mounted) return;
      _refresh();
      HapticFeedback.lightImpact();
      showBeeToast(context, l10n.categoryDeleted(widget.category!.name));
      Navigator.pop(context, true);
    } catch (e, s) {
      logger.error('CustomCategoryEditPage', '删除分类失败', e, s);
      if (mounted) {
        await showOriginCustomDialog<void>(
          context,
          child: OriginDialog(
            title: l10n.categoryDeleteError,
            content: Text(
              '$e',
              style: TextStyle(
                fontSize: 14.0,
                color: OriginTokens.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            cancelText: l10n.commonConfirm,
            onCancel: () => Navigator.pop(context),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget? _customPreview() {
    if (_customPath == null) return null;
    return FutureBuilder<String?>(
      future: _resolvedIcon,
      builder: (context, snap) => snap.connectionState != ConnectionState.done
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : snap.data == null
              ? const BeeLineIcon('ImageOff')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(snap.data!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: BeeLineIcon('ImageOff')),
                  ),
                ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2.0, bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
          color: OriginTokens.textSecondary(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final groups = categoryEditorIconGroups(l10n, widget.kind);

    BeeIconChoice<String> choice(String key) => BeeIconChoice(
          value: key,
          label: key,
          icon: BeeLineIcon(categoryLineIconNames[key] ?? 'Shapes', size: 22),
        );

    final kindTitle = widget.kind == 'expense'
        ? l10n.categoryExpenseType
        : widget.kind == 'income'
            ? l10n.categoryIncomeType
            : l10n.transferTitle;

    final kindIcon = widget.kind == 'transfer'
        ? Icons.swap_horiz_rounded
        : widget.kind == 'expense'
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded;

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: isEditing ? l10n.categoryEditTitle : l10n.categoryNewTitle,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: OriginTokens.textPrimary(context),
          ),
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            OriginMoreButton(
              items: [
                OriginMenuItem(
                  title: l10n.categoryDetailTooltip,
                  icon: const Icon(Icons.pie_chart_outline_rounded, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomCategoryDetailPage(
                          categoryId: widget.category!.id,
                          categoryName: widget.category!.name,
                          allLedgers: true,
                        ),
                      ),
                    );
                  },
                ),
                OriginMenuItem(
                  title: l10n.categoryMigrationTooltip,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryMigrationPage(
                          preselectedFromCategory: widget.category!,
                        ),
                      ),
                    );
                  },
                ),
                OriginMenuItem(
                  title: l10n.categoryDeleteTitle,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  isDestructive: true,
                  onTap: _deleteCategory,
                ),
              ],
            ),
        ],
      ),
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
              onPressed: _busy || _picking || _duplicate ? null : _saveCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(OriginTokens.buttonRadius),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.commonSave,
                      style: const TextStyle(
                        fontSize: 16.0,
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
          padding: const EdgeInsets.only(top: 8.0, bottom: 28.0),
          children: [
            // 1. 分类基本信息卡片
            OriginCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 分类名称（独立上方标题 + OriginTextField）
                  _buildFieldLabel(l10n.categoryNameLabel),
                  OriginTextField(
                    controller: _nameController,
                    hintText: l10n.categoryNameHint,
                    clearable: true,
                    maxLength: 10,
                    enabled: !_busy,
                    errorText: _duplicate
                        ? l10n.categoryNameDuplicate
                        : _nameErrorText,
                    onChanged: (text) {
                      if (_nameErrorText != null && text.trim().isNotEmpty) {
                        setState(() => _nameErrorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // 分类所属维度类型
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          kindIcon,
                          size: 18.0,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Text(
                        kindTitle,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: OriginTokens.textPrimary(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        widget.kind == 'expense'
                            ? l10n.categoryExpense
                            : widget.kind == 'income'
                                ? l10n.categoryIncome
                                : l10n.transferTitle,
                        style: TextStyle(
                          fontSize: 13.0,
                          color: OriginTokens.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  const OriginDivider(),
                  const SizedBox(height: 4.0),

                  // 是否为二级子分类开关
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.categorySubCategoryTitle,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: OriginTokens.textPrimary(context),
                      ),
                    ),
                    subtitle: Text(
                      _isSubCategory
                          ? l10n.categorySubCategoryDescriptionEnabled
                          : l10n.categorySubCategoryDescriptionDisabled,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: OriginTokens.textSecondary(context),
                      ),
                    ),
                    activeTrackColor: primaryColor,
                    activeThumbColor: Colors.white,
                    value: _isSubCategory,
                    onChanged: _busy ||
                            isEditing ||
                            widget.parentCategory != null
                        ? null
                        : (v) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _isSubCategory = v;
                              if (!v) _parent = null;
                            });
                          },
                  ),

                  // 若勾选为二级子分类，则显示选择父级分类入口
                  if (_isSubCategory) ...[
                    const OriginDivider(),
                    const SizedBox(height: 6.0),
                    InkWell(
                      onTap: _busy || widget.parentCategory != null
                          ? null
                          : _selectParent,
                      borderRadius: BorderRadius.circular(10.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            if (_parent == null)
                              Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: OriginTokens.cardSecondary(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.category_outlined,
                                  size: 18.0,
                                  color: OriginTokens.textSecondary(context),
                                ),
                              )
                            else
                              RecordingCategoryIcon(
                                category: _parent!,
                                size: 24,
                              ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.categoryParentCategoryTitle,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      color: OriginTokens.textPrimary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    _parent == null
                                        ? l10n.categoryParentCategoryHint
                                        : CategoryUtils.getDisplayName(
                                            _parent!.name,
                                            context,
                                          ),
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      color: _parent == null
                                          ? OriginTokens.textTertiary(context)
                                          : primaryColor,
                                      fontWeight: _parent == null
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.parentCategory == null)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: OriginTokens.textTertiary(context),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14.0),

            // 2. 分类图标选择卡片
            OriginCard(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.categoryIconLabel,
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: OriginTokens.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 14.0),
                  BeeCategoryIconEditor(
                    source: _iconSource,
                    value: _icon,
                    enabled: !_busy,
                    loading: _picking,
                    groups: [
                      for (var i = 0; i < groups.length; i++)
                        BeeCategoryIconGroup(
                          id: '$i',
                          label: groups[i].label,
                          items: groups[i].iconKeys.map(choice).toList(),
                        )
                    ],
                    commonItems: (widget.kind == 'expense'
                            ? [
                                'restaurant',
                                'local_cafe',
                                'directions_subway',
                                'shopping_basket',
                                'home',
                                'movie',
                                'book',
                                'favorite',
                                'card_giftcard',
                                'computer',
                                'fitness_center',
                                'pets',
                              ]
                            : [
                                'work',
                                'account_balance',
                                'savings',
                                'card_giftcard',
                                'paid',
                                'trending_up',
                                'wallet',
                                'emoji_events',
                                'handshake',
                                'undo',
                                'sync',
                                'category',
                              ])
                        .map(choice)
                        .toList(),
                    presetLabel: l10n.v4CategoryPresetIcons,
                    customLabel: l10n.categoryCustomIconTitle,
                    commonLabel: l10n.v4CategoryCommonIcons,
                    imageHint: l10n.v4CategoryImageHint,
                    chooseImageLabel: _customPath == null
                        ? l10n.categoryCustomIconTapToSelect
                        : l10n.categoryCustomIconTapToChange,
                    preview: _customPreview(),
                    onSourceChanged: (v) => setState(() => _iconSource = v),
                    onChanged: (v) => setState(() {
                      _icon = v;
                      _iconSource = BeeCategoryIconSource.preset;
                    }),
                    onChooseImage: _pickIcon,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
