import 'dart:async';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../pages/tag/detail/bindings/tag_detail.dart' show tagDetailColor;
import '../../pages/tag/editor/bindings/tag_editor.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/tag_seed_service.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_text_field.dart';

/// vivo OriginOS 风格标签编辑/新建页面 (CustomTagEditPage)
///
/// 核心特性：
/// 1. 输入框与独立标题遵循 OriginUI 规范，圆角、次级底色、聚焦主色描边，并彻底消除字数统计；
/// 2. 标签颜色排版重构为 5 列自适应网格，20 种预设色整齐排列为 4 行，彻底解决原版 Wrap 留白空缺问题；
/// 3. 保存操作移至页面底部，采用统一的 OriginOS 胶囊置底大按钮规范；
/// 4. 纯 Riverpod 驱动，复用底层标签管理与业务逻辑，与上游保持零冲突。
class CustomTagEditPage extends ConsumerStatefulWidget {
  const CustomTagEditPage({super.key, this.tag});

  final Tag? tag;

  @override
  ConsumerState<CustomTagEditPage> createState() => _CustomTagEditPageState();
}

class _CustomTagEditPageState extends ConsumerState<CustomTagEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.tag?.name ?? '');
  late String _color = widget.tag?.color ?? TagSeedService.getRandomColor();
  bool _saving = false;
  String? _nameErrorText;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final trimmed = _name.text.trim();
    final l = AppLocalizations.of(context);

    if (trimmed.isEmpty) {
      setState(() {
        _nameErrorText = l.tagNameRequired;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await saveTagDraft(
        ref.read(repositoryProvider),
        name: trimmed,
        color: _color,
        existing: widget.tag,
      );
      if (!mounted) return;
      ref.read(tagListRefreshProvider.notifier).state++;
      final ledger = ref.read(currentLedgerIdProvider);
      if (ledger > 0) unawaited(PostProcessor.sync(ref, ledgerId: ledger));
      if (mounted) {
        HapticFeedback.lightImpact();
        showBeeToast(
          context,
          widget.tag == null ? l.tagCreateSuccess : l.tagUpdateSuccess,
          tone: BeeTone.success,
        );
        Navigator.pop(context, saved);
      }
    } on DuplicateTagName {
      if (mounted) {
        setState(() {
          _nameErrorText = l.tagNameDuplicate;
        });
        showBeeToast(context, l.tagNameDuplicate, tone: BeeTone.error);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${l.commonError}: $e', tone: BeeTone.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final l = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final colors = TagSeedService.getColorPalette();

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: widget.tag == null ? l.tagAddTitle : l.tagEditTitle,
        leading: BackButton(
          onPressed: _saving ? null : () => Navigator.maybePop(context),
        ),
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
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l.commonSave,
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8.0, bottom: 28.0),
        children: [
          // 1. 标签实时预览卡片
          OriginCard(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
            child: Center(
              child: BeeTag(
                tag: BeeTagData(
                  'preview',
                  _name.text.trim().isEmpty
                      ? l.tagNameLabel
                      : _name.text.trim(),
                  tagDetailColor(
                    _color,
                    primaryColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // 2. 标签名称输入卡片 (独立标题 + OriginTextField + 无字数显示)
          OriginCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel(l.tagNameLabel),
                OriginTextField(
                  controller: _name,
                  hintText: l.tagNameHint,
                  clearable: true,
                  maxLength: 20,
                  showCounter: false,
                  enabled: !_saving,
                  errorText: _nameErrorText,
                  onChanged: (text) {
                    setState(() {
                      if (_nameErrorText != null && text.trim().isNotEmpty) {
                        _nameErrorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),

          // 3. 标签颜色选择卡片 (自适应 5 列网格，整齐容纳 20 种预设色)
          OriginCard(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFieldLabel(l.tagColorLabel),
                const SizedBox(height: 4.0),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: colors.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 14.0,
                    crossAxisSpacing: 14.0,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final hex = colors[index];
                    final colorValue = tagDetailColor(hex, Colors.grey);
                    final isSelected =
                        _color.toLowerCase() == hex.toLowerCase();

                    return Semantics(
                      label: '${l.tagColorLabel} $hex',
                      selected: isSelected,
                      button: true,
                      child: GestureDetector(
                        onTap: _saving
                            ? null
                            : () {
                                if (_color != hex) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _color = hex);
                                }
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: colorValue,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    width: 2.5,
                                  )
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: colorValue.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: colorValue.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
