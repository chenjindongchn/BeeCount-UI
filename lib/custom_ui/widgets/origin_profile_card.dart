import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers.dart';
import '../../../providers/avatar_providers.dart';
import '../../../providers/sync_providers.dart' as sp;
import '../../../services/system/logger_service.dart';
import '../../../services/ui/avatar_service.dart';
import '../../../utils/format_utils.dart';
import '../../../pages/main/mine/widgets/mine_avatar.dart';
import '../../../pages/shared/selectors/ledger_picker_sheet.dart';
import '../styles/origin_tokens.dart';
import 'origin_card.dart';
import 'origin_divider.dart';
import 'origin_dialog.dart';
import 'origin_bottom_sheet.dart';
import 'origin_text_field.dart';

class _OriginEditDisplayNameDialog extends StatefulWidget {
  const _OriginEditDisplayNameDialog({required this.initial});

  final String initial;

  @override
  State<_OriginEditDisplayNameDialog> createState() =>
      _OriginEditDisplayNameDialogState();
}

class _OriginEditDisplayNameDialogState
    extends State<_OriginEditDisplayNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OriginDialog(
      alignment: Alignment.bottomCenter,
      title: l10n.mineDisplayNameEditTitle,
      textAlign: TextAlign.center,
      stackActions: true,
      confirmText: l10n.commonSave,
      onConfirm: () {
        final text = _controller.text.trim();
        if (text.isNotEmpty) {
          Navigator.pop(context, text);
        }
      },
      cancelText: l10n.commonCancel,
      onCancel: () => Navigator.pop(context),
      content: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: OriginTextField(
          focusNode: _focus,
          controller: _controller,
          hintText: l10n.mineDisplayNameHint,
          maxLength: 20,
          clearable: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
          },
        ),
      ),
    );
  }
}

/// vivo OriginOS 风格个人资料与记账概览卡片 (OriginProfileCard)
///
/// 遵循 OriginOS 卡片设计规范：
/// 1. 12dp 大圆角与 20dp 屏幕边距；
/// 2. 56dp 头像容器（带发丝光环描边与圆角）；
/// 3. 动态时段问候语与昵称编辑；
/// 4. 记账天数、记账笔数、当前账本状态胶囊栏；
/// 5. 100% 复用 Riverpod 既有数据逻辑，零业务冗余。
class OriginProfileCard extends ConsumerStatefulWidget {
  const OriginProfileCard({super.key});

  @override
  ConsumerState<OriginProfileCard> createState() => _OriginProfileCardState();
}

class _OriginProfileCardState extends ConsumerState<OriginProfileCard> {
  String? _avatarPath;
  bool _isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final path = await AvatarService.getAvatarPath();
    if (mounted) {
      setState(() {
        _avatarPath = path;
        _isLoadingAvatar = false;
      });
    }
  }

  ({String text, IconData icon, Color color}) _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 11) {
      return (
        text: l10n.mineGreetingMorning,
        icon: Icons.wb_twilight_rounded,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 11 && h < 13) {
      return (
        text: l10n.mineGreetingNoon,
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFF59E0B),
      );
    }
    if (h >= 13 && h < 18) {
      return (
        text: l10n.mineGreetingAfternoon,
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFF97316),
      );
    }
    if (h >= 18 && h < 23) {
      return (
        text: l10n.mineGreetingEvening,
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF8B5CF6),
      );
    }
    return (
      text: l10n.mineGreetingNight,
      icon: Icons.nightlight_round,
      color: const Color(0xFF818CF8),
    );
  }

  Future<void> _showEditDisplayName() async {
    final current = ref.read(displayNameProvider);
    final result = await showOriginCustomDialog<String>(
      context,
      child: _OriginEditDisplayNameDialog(initial: current),
    );

    if (result == null || !mounted) return;
    final name = result.trim();
    if (name.isEmpty || name == current) return;
    ref.read(displayNameProvider.notifier).state = name;
    showBeeToast(context, AppLocalizations.of(context).mineDisplayNameSaved);
  }

  Future<void> _showProfileOptions() async {
    final l10n = AppLocalizations.of(context);

    final result = await showOriginActionSheet<String>(
      context,
      title: l10n.mineProfileEditTitle,
      selected: '',
      options: [
        OriginChoiceOption<String>(
          value: 'nickname',
          title: l10n.mineDisplayNameEditTitle,
          icon: Icons.edit_note_rounded,
        ),
        OriginChoiceOption<String>(
          value: 'gallery',
          title: l10n.mineAvatarFromGallery,
          icon: Icons.photo_library_outlined,
        ),
        OriginChoiceOption<String>(
          value: 'camera',
          title: l10n.mineAvatarFromCamera,
          icon: Icons.camera_alt_outlined,
        ),
        if (_avatarPath != null)
          OriginChoiceOption<String>(
            value: 'delete',
            title: l10n.mineAvatarDelete,
            icon: Icons.delete_outline_rounded,
          ),
      ],
    );

    if (result == null || !mounted) return;

    if (result == 'nickname') {
      await _showEditDisplayName();
      return;
    }

    try {
      if (result == 'gallery') {
        final path = await AvatarService.pickAndSaveAvatar();
        if (mounted && path != null) {
          setState(() => _avatarPath = path);
          ref.invalidate(avatarPathProvider);
          await _syncAvatarToCloud(path);
        }
      } else if (result == 'camera') {
        final path = await AvatarService.takePhotoAndSaveAvatar();
        if (mounted && path != null) {
          setState(() => _avatarPath = path);
          ref.invalidate(avatarPathProvider);
          await _syncAvatarToCloud(path);
        }
      } else if (result == 'delete') {
        await AvatarService.deleteAvatar();
        if (mounted) {
          setState(() => _avatarPath = null);
          ref.invalidate(avatarPathProvider);
        }
      }
    } catch (e) {
      if (!mounted) return;
      showBeeToast(context, '${l10n.commonError}: $e');
    }
  }

  Future<void> _syncAvatarToCloud(String absolutePath) async {
    try {
      final providerInstance =
          await ref.read(sp.beecountCloudProviderInstance.future);
      if (providerInstance == null) return;
      final file = File(absolutePath);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final name = absolutePath.split('/').last;
      final result = await providerInstance.uploadMyAvatar(
        bytes: bytes,
        fileName: name,
        mimeType:
            name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      await AvatarService.setStoredRemoteVersion(result.avatarVersion);
    } catch (e, st) {
      logger.warning('avatar_sync', 'upload failed: $e', st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = OriginTokens.primary(context);

    final avatar = ref.watch(avatarPathProvider).valueOrNull ?? _avatarPath;
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final ledger = ref.watch(currentLedgerProvider).valueOrNull;
    final counts = ref.watch(countsForLedgerProvider(ledgerId)).valueOrNull;
    final name = ref.watch(displayNameProvider);

    final greetingInfo = _greeting(l10n);
    final displayName = name.isEmpty ? OriginAppInfo.appName : name;

    return OriginCard(
      margin: const EdgeInsets.symmetric(
        horizontal: OriginTokens.cardMargin,
        vertical: 4.0,
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部：头像 + 昵称/问候语 + 编辑按钮
          Row(
            children: [
              // 头像容器
              GestureDetector(
                onTap: _showProfileOptions,
                child: Stack(
                  children: [
                    Container(
                      width: 56.0,
                      height: 56.0,
                      decoration: BoxDecoration(
                        color: OriginTokens.cardSecondary(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0x33FFFFFF)
                              : const Color(0x1F000000),
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _isLoadingAvatar
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : avatar == null
                              ? const MineDefaultAvatar()
                              : Image.file(
                                  File(avatar),
                                  key: ValueKey(avatar),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const MineDefaultAvatar(),
                                ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OriginTokens.cardBackground(context),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 10.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14.0),
              // 昵称与问候语
              Expanded(
                child: GestureDetector(
                  onTap: _showEditDisplayName,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 17.0,
                                fontWeight: FontWeight.w600,
                                color: OriginTokens.textPrimary(context),
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Icon(
                            Icons.edit_outlined,
                            size: 14.0,
                            color: OriginTokens.textTertiary(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Icon(
                            greetingInfo.icon,
                            size: 13.0,
                            color: greetingInfo.color,
                          ),
                          const SizedBox(width: 4.0),
                          Flexible(
                            child: Text(
                              name.isEmpty
                                  ? l10n.mineSlogan
                                  : greetingInfo.text,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: OriginTokens.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14.0),
          OriginDivider(
            startIndent: 0,
            endIndent: 0,
            color: OriginTokens.divider(context),
          ),
          const SizedBox(height: 12.0),

          // 底部统计与账本胶囊栏
          Row(
            children: [
              // 记账天数胶囊
              _buildStatPill(
                context,
                icon: Icons.calendar_today_rounded,
                label: '${counts?.dayCount ?? 0} ${l10n.sharePosterUnitDay}',
                onTap: () =>
                    ref.read(bottomTabIndexProvider.notifier).state = 0,
              ),
              const SizedBox(width: 8.0),
              // 交易笔数胶囊
              _buildStatPill(
                context,
                icon: Icons.receipt_long_rounded,
                label: '${counts?.txCount ?? 0} ${l10n.sharePosterUnitCount}',
                onTap: () =>
                    ref.read(bottomTabIndexProvider.notifier).state = 0,
              ),
              const Spacer(),
              // 当前账本胶囊
              GestureDetector(
                onTap: () => showLedgerPicker(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: OriginTokens.cardSecondary(context),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x22FFFFFF)
                          : const Color(0x10000000),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 13.0,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 4.0),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          ledger == null
                              ? l10n.ledgersNew
                              : translateLedgerName(context, ledger.name),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: OriginTokens.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 14.0,
                        color: OriginTokens.textTertiary(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: OriginTokens.cardSecondary(context),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12.0,
              color: OriginTokens.textSecondary(context),
            ),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
