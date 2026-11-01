import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/tag/detail/bindings/tag_detail.dart' show tagDetailColor;
import '../../pages/tag/manage/bindings/tag_library_data.dart';
import '../../pages/tag/manage/bindings/tag_library_files.dart';
import '../../pages/tag/tag_edit_page.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/export/config_export_service.dart';
import '../../services/system/logger_service.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_menu.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_divider.dart';
import 'custom_tag_detail_page.dart';

/// vivo OriginOS 风格自定义标签管理页面 (CustomTagManagePage)
///
/// 核心特性：
/// 1. 右上角采用统一的 2 个点入口 (OriginMoreButton)，点击呼出高质感展开式气泡菜单；
/// 2. 气泡菜单集成：新建标签、分享标签、生成默认标签、导入标签、清理未使用的标签；
/// 3. 点击标签项跳转至统一设计的 CustomTagDetailPage；
/// 4. 纯 Riverpod 驱动，复用底层标签管理与业务逻辑，零上游冲突。
class CustomTagManagePage extends ConsumerStatefulWidget {
  const CustomTagManagePage({
    super.key,
    this.files = const TagLibraryFiles(),
  });

  final TagLibraryFiles files;

  @override
  ConsumerState<CustomTagManagePage> createState() => _CustomTagManagePageState();
}

class _CustomTagManagePageState extends ConsumerState<CustomTagManagePage> {
  final _scroll = ScrollController();
  bool _busy = false;
  bool _working = false;

  TagLibraryData get _data => TagLibraryData(ref.read(repositoryProvider));

  void _refresh() => ref.read(tagListRefreshProvider.notifier).state++;

  void _sync() {
    final ledger = ref.read(currentLedgerIdProvider);
    if (ledger > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledger));
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _working = true;
    });
    try {
      await action();
    } catch (e) {
      logger.error('TagManage', '标签操作失败: $e');
      if (mounted) showBeeToast(context, failure, tone: BeeTone.error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<void> _open(Tag? tag) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => tag == null
            ? const TagEditPage()
            : CustomTagDetailPage(
                tagId: tag.id,
                tagName: tag.name,
                allLedgers: true,
              ),
      ),
    );
  }

  Future<void> _delete(Tag tag) async {
    final l = AppLocalizations.of(context);
    final yes = await showBeeConfirm(
      context,
      title: l.tagDeleteConfirmTitle,
      message: l.tagDeleteConfirmMessage(tag.name),
      confirmLabel: l.commonDelete,
      cancelLabel: l.commonCancel,
      danger: true,
    );
    if (!yes || !mounted) return;
    await _run(() async {
      await ref.read(repositoryProvider).deleteTag(tag.id);
      if (mounted) {
        _refresh();
        showBeeToast(context, l.tagDeleteSuccess, tone: BeeTone.success);
      }
    }, l.commonError);
  }

  Future<void> _generate() async {
    final l = AppLocalizations.of(context);
    final yes = await showBeeConfirm(
      context,
      title: l.tagManageGenerateDefault,
      message: l.tagManageGenerateDefaultConfirm,
      confirmLabel: l.commonConfirm,
      cancelLabel: l.commonCancel,
    );
    if (!yes || !mounted) return;
    await _run(() async {
      await _data.generate(l);
      if (mounted) {
        _sync();
        _refresh();
        showBeeToast(context, l.tagManageGenerateDefaultSuccess,
            tone: BeeTone.success);
      }
    }, l.commonError);
  }

  Future<void> _share() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      final yaml = await _data.export(ref.read(currentLedgerIdProvider));
      if (!mounted) return;
      final path = await widget.files.share(yaml, l.tagShareSubject);
      if (mounted && path != null) {
        showBeeToast(context, l.tagShareSuccess(path), tone: BeeTone.success);
      }
    }, l.tagShareFailed);
  }

  Future<void> _import() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      String? path;
      try {
        path = await widget.files.pick();
      } on TagLibraryMissingPath {
        if (mounted) {
          showBeeToast(context, l.configImportNoFilePath, tone: BeeTone.error);
        }
        return;
      }
      if (path == null || !mounted) return;
      if (!path.toLowerCase().endsWith('.yml') &&
          !path.toLowerCase().endsWith('.yaml')) {
        showBeeToast(context, l.tagImportInvalidFile, tone: BeeTone.error);
        return;
      }
      final yaml = await widget.files.read(path);
      if (!mounted) return;
      if (!ConfigExportService.detectContent(yaml).hasTags) {
        showBeeToast(context, l.tagImportNoTags, tone: BeeTone.error);
        return;
      }
      setState(() => _working = false);
      final overwrite = await showOriginCustomDialog<bool>(
        context,
        child: OriginDialog(
          title: l.tagImportModeTitle,
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
                  title: l.tagImportModeMerge,
                  subtitle: l.tagImportModeMergeDesc,
                  leading: const BeeLineIcon('GitMerge'),
                  onTap: () => Navigator.pop(context, false),
                ),
                const OriginDivider(startIndent: 44.0, endIndent: 12.0),
                BeeMenuRow(
                  title: l.tagImportModeOverwrite,
                  subtitle: l.tagImportModeOverwriteDesc,
                  leading: const BeeLineIcon('RefreshCw'),
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
          cancelText: l.commonCancel,
          onCancel: () => Navigator.pop(context),
        ),
      );
      if (overwrite == null || !mounted) return;
      setState(() => _working = true);
      await _data.importYaml(
        yaml,
        ledgerId: ref.read(currentLedgerIdProvider),
        overwrite: overwrite,
      );
      if (mounted) {
        _refresh();
        showBeeToast(context, l.tagImportSuccess, tone: BeeTone.success);
      }
    }, l.tagImportFailed);
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    await _run(() async {
      final candidates = await _data.unused();
      if (!mounted) return;
      if (candidates.isEmpty) {
        showBeeToast(context, l.tagClearUnusedEmpty);
        return;
      }
      setState(() => _working = false);
      final yes = await showBeeConfirm(
        context,
        title: l.tagClearUnusedTitle,
        message: l.tagClearUnusedMessage(candidates.length),
        confirmLabel: l.commonDelete,
        cancelLabel: l.commonCancel,
        danger: true,
      );
      if (!yes || !mounted) return;
      setState(() => _working = true);
      final removed = await _data.clearUnused(candidates.map((tag) => tag.id));
      if (mounted) {
        _sync();
        _refresh();
        showBeeToast(context, l.tagClearUnusedSuccess(removed),
            tone: BeeTone.success);
      }
    }, l.tagClearUnusedFailed);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tags = ref.watch(tagsWithStatsProvider);

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.tagManageTitle,
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: l.tagAddTitle,
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _busy ? null : () => _open(null),
          ),
          OriginMoreButton(
            items: [
              OriginMenuItem(
                title: l.tagAddTitle,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onTap: () => _open(null),
              ),
              OriginMenuItem(
                title: l.tagShare,
                icon: const Icon(Icons.share_outlined, size: 20),
                onTap: _share,
              ),
              OriginMenuItem(
                title: l.tagManageGenerateDefault,
                icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                onTap: _generate,
              ),
              OriginMenuItem(
                title: l.tagImport,
                icon: const Icon(Icons.file_download_outlined, size: 20),
                onTap: _import,
              ),
              OriginMenuItem(
                title: l.tagClearUnused,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                isDestructive: true,
                onTap: _clear,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 2,
            child: _working ? const LinearProgressIndicator(minHeight: 2) : null,
          ),
          Expanded(
            child: tags.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: BeeStatus(
                  label: l.commonError,
                  tone: BeeTone.error,
                  action: BeeButton(
                    label: l.v4RecordingRetry,
                    onPressed: () => ref.invalidate(tagsWithStatsProvider),
                  ),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(OriginTokens.cardMargin),
                    children: [
                      BeeEmptyState(
                        title: l.tagManageEmpty,
                        message: l.tagManageEmptyHint,
                        action: BeeButton(
                          label: l.tagManageGenerateDefault,
                          onPressed: _busy ? null : _generate,
                        ),
                      ),
                    ],
                  );
                }
                Tag? item(String id) =>
                    rows.where((r) => '${r.tag.id}' == id).firstOrNull?.tag;

                return BeeTagLibrary(
                  key: const PageStorageKey('custom-tag-management-grid'),
                  controller: _scroll,
                  items: [
                    for (final row in rows)
                      BeeTagLibraryItem(
                        tag: BeeTagData(
                          '${row.tag.id}',
                          row.tag.name,
                          tagDetailColor(
                            row.tag.color,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        count: l.tagTransactionCount(row.transactionCount),
                      ),
                  ],
                  deleteLabel: l.commonDelete,
                  enabled: !_busy,
                  onOpen: (id) {
                    final tag = item(id);
                    if (tag != null) _open(tag);
                  },
                  onDelete: (id) {
                    final tag = item(id);
                    if (tag != null) _delete(tag);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
