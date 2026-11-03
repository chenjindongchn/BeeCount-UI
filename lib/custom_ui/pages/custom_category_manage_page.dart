import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';

import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import 'custom_category_edit_page.dart';
import '../../pages/shared/resources/bindings/recording_category_icon.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/category_package_service.dart';
import '../../services/data/seed_service.dart';
import '../../services/system/logger_service.dart';
import '../../utils/category_utils.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_segmented_control.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import '../widgets/origin_empty_state.dart';

/// vivo OriginOS 风格自定义分类管理页面 (CustomCategoryManagePage)
///
/// 核心特性：
/// 1. 右上角采用统一的 2 个点入口 (OriginMoreButton)，点击呼出高质感展开式气泡菜单；
/// 2. 气泡菜单集成：新建分类、分享分类、导入分类包、恢复默认分类、清除未使用分类；
/// 3. 支持平滑切换“支出”与“收入”维度；
/// 4. 纯 Riverpod 驱动，复用底层分类业务逻辑，与上游 upstream 保持零冲突。
class CustomCategoryManagePage extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0: 支出, 1: 收入

  const CustomCategoryManagePage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<CustomCategoryManagePage> createState() =>
      _CustomCategoryManagePageState();
}

class _CustomCategoryManagePageState
    extends ConsumerState<CustomCategoryManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addCategory({String? kind}) async {
    final categoryKind =
        kind ?? (_tabController.index == 0 ? 'expense' : 'income');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomCategoryEditPage(kind: categoryKind),
      ),
    );
  }

  /// 分享分类
  Future<void> _shareCategories() async {
    final l10n = AppLocalizations.of(context);
    final scope = await showOriginCustomDialog<String>(
      context,
      child: OriginDialog(
        title: l10n.categoryShareScopeTitle,
        textAlign: TextAlign.center,
        content: Container(
          decoration: BoxDecoration(
            color: OriginTokens.cardSecondary(context),
            borderRadius: BorderRadius.circular(14.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeeMenuRow(
                leading: const BeeLineIcon('ListFilter'),
                title: _tabController.index == 0
                    ? l10n.categoryShareScopeExpense
                    : l10n.categoryShareScopeIncome,
                onTap: () => Navigator.pop(context, 'current'),
              ),
              const OriginDivider(startIndent: 44.0, endIndent: 12.0),
              BeeMenuRow(
                leading: const BeeLineIcon('Layers'),
                title: l10n.categoryShareScopeAll,
                onTap: () => Navigator.pop(context, 'all'),
              ),
            ],
          ),
        ),
        cancelText: l10n.commonCancel,
        onCancel: () => Navigator.pop(context),
      ),
    );

    if (scope == null || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      String? filterKind;
      if (scope == 'current') {
        filterKind = _tabController.index == 0 ? 'expense' : 'income';
      }

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final fileName = 'beecount_categories_$timestamp.zip';

      String outputPath;
      if (Platform.isAndroid) {
        const downloadPath = '/storage/emulated/0/Download/BeeCount';
        final dir = Directory(downloadPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        outputPath = '$downloadPath/$fileName';
      } else {
        final tempDir = await getTemporaryDirectory();
        outputPath = '${tempDir.path}/$fileName';
      }

      await CategoryPackageService.exportPackage(
        repository: repo,
        outputPath: outputPath,
        filterKind: filterKind,
      );

      if (!mounted) return;

      if (Platform.isAndroid) {
        showBeeToast(
          context,
          l10n.categoryShareSuccess(
              outputPath.replaceAll('/storage/emulated/0/', '')),
        );
      } else {
        await SharePlus.instance.share(ShareParams(
          files: [XFile(outputPath)],
          subject: l10n.categoryShareSubject,
        ));
      }
    } catch (e) {
      logger.error('CategoryManage', '分享分类失败: $e');
      if (!mounted) return;
      showBeeToast(context, l10n.categoryShareFailed);
    }
  }

  /// 导入分类
  Future<void> _importCategories() async {
    final l10n = AppLocalizations.of(context);
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
      } catch (e) {
        result = await FilePicker.platform.pickFiles(type: FileType.any);
      }

      if (result == null || result.files.isEmpty || !mounted) return;
      final filePath = result.files.first.path;
      if (filePath == null) {
        showBeeToast(context, l10n.configImportNoFilePath);
        return;
      }

      if (!filePath.toLowerCase().endsWith('.zip')) {
        showBeeToast(context, l10n.categoryImportInvalidFile);
        return;
      }

      if (!mounted) return;

      final mode = await showOriginCustomDialog<String>(
        context,
        child: OriginDialog(
          title: l10n.categoryImportModeTitle,
          textAlign: TextAlign.center,
          content: Container(
            decoration: BoxDecoration(
              color: OriginTokens.cardSecondary(context),
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeeMenuRow(
                  leading: const BeeLineIcon('GitMerge'),
                  title: l10n.categoryImportModeMerge,
                  subtitle: l10n.categoryImportModeMergeDesc,
                  onTap: () => Navigator.pop(context, 'merge'),
                ),
                const OriginDivider(startIndent: 44.0, endIndent: 12.0),
                BeeMenuRow(
                  leading: const BeeLineIcon('RefreshCw'),
                  title: l10n.categoryImportModeOverwrite,
                  subtitle: l10n.categoryImportModeOverwriteDesc,
                  onTap: () => Navigator.pop(context, 'overwrite'),
                ),
              ],
            ),
          ),
          cancelText: l10n.commonCancel,
          onCancel: () => Navigator.pop(context),
        ),
      );

      if (mode == null || !mounted) return;

      final repo = ref.read(repositoryProvider);
      final importResult = await CategoryPackageService.importPackage(
        filePath: filePath,
        repository: repo,
        mode: mode,
      );

      if (!mounted) return;
      showBeeToast(
        context,
        l10n.categoryImportSuccessDetail(
          importResult.imported,
          importResult.skipped,
          importResult.iconsImported,
        ),
      );
      ref.invalidate(categoriesWithCountProvider);
    } catch (e) {
      logger.error('CategoryManage', '导入分类失败: $e');
      if (!mounted) return;
      showBeeToast(context, l10n.categoryImportFailed);
    }
  }

  /// 生成默认分类
  Future<void> _generateDefaultCategories() async {
    final l10n = AppLocalizations.of(context);
    final kind = _tabController.index == 0 ? 'expense' : 'income';
    final kindName =
        kind == 'expense' ? l10n.categoryExpense : l10n.categoryIncome;

    final useHierarchical = await showOriginCustomDialog<bool>(
      context,
      child: StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          var selectedMode = false;
          return OriginDialog(
            title: '${l10n.categoryGenerateDefault} · $kindName',
            textAlign: TextAlign.center,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: OriginTokens.cardSecondary(dialogCtx),
                    borderRadius: BorderRadius.circular(14.0),
                  ),
                  child: Column(
                    children: [
                      BeeRadioTile<bool>(
                        value: false,
                        groupValue: selectedMode,
                        label: l10n.categoryGenerateDefaultFlat,
                        onChanged: (value) =>
                            setDialogState(() => selectedMode = value),
                      ),
                      const OriginDivider(startIndent: 44.0, endIndent: 12.0),
                      BeeRadioTile<bool>(
                        value: true,
                        groupValue: selectedMode,
                        label: l10n.categoryGenerateDefaultHierarchical,
                        onChanged: (value) =>
                            setDialogState(() => selectedMode = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    l10n.categoryGenerateDefaultHint,
                    style: TextStyle(
                      fontSize: 12.0,
                      color: OriginTokens.textTertiary(dialogCtx),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            confirmText: l10n.commonConfirm,
            cancelText: l10n.commonCancel,
            onConfirm: () => Navigator.pop(dialogCtx, selectedMode),
            onCancel: () => Navigator.pop(dialogCtx),
          );
        },
      ),
    );

    if (useHierarchical == null || !mounted) return;

    try {
      final createdCount = await SeedService.addDefaultCategories(
        repository: ref.read(repositoryProvider),
        l10n: l10n,
        kind: kind,
        hierarchical: useHierarchical,
      );
      if (!mounted) return;
      if (createdCount == 0) {
        showBeeToast(context, l10n.categoryGenerateDefaultNoChanges);
        return;
      }

      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      ref.invalidate(categoriesWithCountProvider);
      showBeeToast(context, l10n.categoryGenerateDefaultSuccess(createdCount));
    } catch (e) {
      logger.error('CategoryManage', '生成默认分类失败: $e');
      if (!mounted) return;
      showBeeToast(context, l10n.categoryGenerateDefaultFailed);
    }
  }

  /// 清空未使用的分类
  Future<void> _clearUnusedCategories() async {
    final l10n = AppLocalizations.of(context);
    final categoriesWithCount =
        ref.read(categoriesWithCountProvider).valueOrNull ?? [];
    final unusedCategories =
        categoriesWithCount.where((item) => item.transactionCount == 0).toList();

    if (unusedCategories.isEmpty) {
      showBeeToast(context, l10n.categoryClearUnusedEmpty);
      return;
    }

    final toDeleteList = <String>[];
    for (final item in unusedCategories) {
      final categoryName =
          CategoryUtils.getDisplayName(item.category.name, context);
      toDeleteList.add(categoryName);
    }

    final confirm = await showOriginConfirmDialog(
      context,
      title: l10n.categoryClearUnusedTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoryClearUnusedMessage(unusedCategories.length),
            style: TextStyle(
              fontSize: 14.0,
              color: OriginTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 14.0),
          Text(
            l10n.categoryClearUnusedListTitle,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: OriginTokens.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: OriginTokens.cardSecondary(context),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Text(
              toDeleteList.join('\n'),
              style: TextStyle(
                fontSize: 13.0,
                color: OriginTokens.textSecondary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      confirmText: l10n.commonDelete,
      cancelText: l10n.commonCancel,
      isDanger: true,
    );

    if (confirm != true || !mounted) return;

    try {
      final repo = ref.read(repositoryProvider);
      final ids = unusedCategories.map((item) => item.category.id).toList();
      await repo.deleteCategoriesByIds(ids);

      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      ref.invalidate(categoriesWithCountProvider);
      if (!mounted) return;
      showBeeToast(context, l10n.categoryClearUnusedSuccess(ids.length));
    } catch (e) {
      logger.error('CategoryManage', '清空未使用分类失败: $e');
      if (!mounted) return;
      showBeeToast(context, l10n.categoryClearUnusedFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesWithCountAsync = ref.watch(categoriesWithCountProvider);
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l10n.categoryTitle,
        leading: const BackButton(),
        actions: [
          OriginMoreButton(
            items: [
              OriginMenuItem(
                title: l10n.categoryNew,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onTap: () => _addCategory(),
              ),
              OriginMenuItem(
                title: l10n.categoryShare,
                icon: const Icon(Icons.share_outlined, size: 20),
                onTap: _shareCategories,
              ),
              OriginMenuItem(
                title: l10n.categoryImport,
                icon: const Icon(Icons.file_download_outlined, size: 20),
                onTap: _importCategories,
              ),
              OriginMenuItem(
                title: l10n.categoryGenerateDefault,
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                onTap: _generateDefaultCategories,
              ),
              OriginMenuItem(
                title: l10n.categoryClearUnused,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                isDestructive: true,
                onTap: _clearUnusedCategories,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 8.0,
            ),
            child: OriginSegmentedControl<int>(
              items: const [0, 1],
              selectedItem: _tabController.index,
              tabController: _tabController,
              onSelected: (val) {
                _tabController.animateTo(
                  val,
                  duration: const Duration(milliseconds: 250),
                  curve: OriginTokens.fastOutSlowIn,
                );
              },
              labelBuilder: (val) =>
                  val == 0 ? l10n.categoryExpense : l10n.categoryIncome,
            ),
          ),
          Expanded(
            child: categoriesWithCountAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(l10n.categoryLoadFailed(error.toString())),
              ),
              data: (categoriesWithCount) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _CustomCategoryList(
                      kind: 'expense',
                      categoriesWithCount: categoriesWithCount,
                      onAddCategory: () => _addCategory(kind: 'expense'),
                    ),
                    _CustomCategoryList(
                      kind: 'income',
                      categoriesWithCount: categoriesWithCount,
                      onAddCategory: () => _addCategory(kind: 'income'),
                    ),
                  ],
                );
              },
            ),
          ),
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
              onPressed: () {
                HapticFeedback.lightImpact();
                _addCategory();
              },
              child: Text(
                l10n.categoryNew,
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

class _CustomCategoryList extends ConsumerWidget {
  final String kind;
  final List<({db.Category category, int transactionCount})> categoriesWithCount;
  final VoidCallback onAddCategory;

  const _CustomCategoryList({
    required this.kind,
    required this.categoriesWithCount,
    required this.onAddCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final byId = {
      for (final row in categoriesWithCount) row.category.id: row.category
    };

    final filtered = categoriesWithCount
        .where((r) => r.category.kind == kind && r.category.level == 1)
        .toList()
      ..sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));

    BeeManagedCategory data(
      db.Category cat,
      int count, {
      List<BeeManagedCategory> children = const [],
      bool isDefault = false,
    }) =>
        BeeManagedCategory(
          id: '${cat.id}',
          name: CategoryUtils.getDisplayName(cat.name, context),
          icon: RecordingCategoryIcon(
            category: cat,
            size: 19,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          detail:
              '${children.isEmpty ? '' : '${children.length} ${l10n.categorySubCategoryTitle} · '}${l10n.ledgersRecords('$count')}',
          children: children,
          isDefault: isDefault,
        );

    final items = filtered.map((item) {
      final children = categoriesWithCount
          .where((r) => r.category.parentId == item.category.id)
          .toList()
        ..sort((a, b) => a.category.sortOrder.compareTo(b.category.sortOrder));
      return data(
        item.category,
        item.transactionCount,
        children: children.map((c) => data(c.category, c.transactionCount)).toList(),
      );
    }).toList();

    if (items.isEmpty) {
      return OriginEmptyState(
        iconData: Icons.category_outlined,
        title: l10n.categoryEmpty,
        message: '点击下方按钮新建分类，或在右上角生成默认预设',
        bottomSpacing: 12.0,
      );
    }

    return BeeCategoryManagementList(
      reorderLabel: l10n.categoryDetailSortTitle,
      manageLabel: l10n.categoryManageChildren,
      items: items,
      onEdit: (id) {
        final category = byId[int.tryParse(id)];
        if (category != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomCategoryEditPage(
                category: category,
                kind: category.kind,
              ),
            ),
          );
        }
      },
      onManageChildren: (id) {
        final category = byId[int.tryParse(id)];
        if (category != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomCategoryEditPage(
                parentCategory: category,
                kind: category.kind,
              ),
            ),
          );
        }
      },
      onReorder: (oldIndex, newIndex) async {
        final repo = ref.read(repositoryProvider);
        if (oldIndex < 0 ||
            oldIndex >= filtered.length ||
            newIndex < 0 ||
            newIndex >= filtered.length) {
          return;
        }
        final list = List.of(filtered);
        final moved = list.removeAt(oldIndex);
        list.insert(newIndex, moved);
        final updates = <({int id, int sortOrder})>[];
        for (var i = 0; i < list.length; i++) {
          updates.add((id: list[i].category.id, sortOrder: i));
        }
        await repo.updateCategorySortOrders(updates);
        ref.invalidate(categoriesWithCountProvider);
        final activeLedgerId = ref.read(currentLedgerIdProvider);
        if (activeLedgerId > 0) {
          unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
        }
      },
    );
  }
}
