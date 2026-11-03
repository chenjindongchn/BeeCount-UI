import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart' hide SyncStatus;
import '../../l10n/app_localizations.dart';
import '../../providers/github_star_provider.dart';
import '../../providers.dart';
import '../../utils/website_urls.dart';
import '../../utils/currencies.dart';
import '../../styles/header_skins.dart';
import '../../pages/main/mine/bindings/mine_cloud.dart';
import '../../pages/main/mine/bindings/mine_actions.dart';
import '../../pages/settings/help_center_page.dart';
import '../../pages/settings/data_management_page.dart';
import '../../pages/settings/smart_billing_page.dart';
import '../../pages/settings/automation_page.dart';
import '../../pages/settings/about_page.dart';
import '../../pages/settings/appearance/bindings/appearance_dialogs.dart';
import '../../pages/settings/app_lock_settings_page.dart';
import '../../pages/settings/font_settings_page.dart';
import '../../pages/settings/header_skin_page.dart';
import '../../pages/settings/language_settings_page.dart';
import '../../pages/settings/personalize_page.dart';
import '../../pages/settings/widget_management_page.dart';
import '../../cloud/sync_service.dart';
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../../pages/currency/exchange_rate_page.dart';
import 'custom_category_manage_page.dart';
import 'custom_tag_manage_page.dart';
import '../../pages/cloud/cloud_service_page.dart';
import '../../pages/cloud/cloud_sync_page.dart';
import '../../pages/cloud/beecount_cloud_sync_page.dart';
import '../../pages/report/annual_report_page.dart';
import '../../pages/donation/donation_page.dart';
import '../../services/export/share_poster_service.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_setting_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_bottom_sheet.dart';
import '../providers/amount_format_provider.dart';
import '../providers/plus_button_enhancement_provider.dart';
import '../providers/double_back_exit_provider.dart';
import '../providers/account_color_display_provider.dart';
import '../providers/frequent_notes_enabled_provider.dart';

/// vivo OriginOS 风格“设置”页面 (CustomSettingsPage)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md` 与 `24`:
/// 1. 大标题栏（84dp / 22sp SemiBold），规范 AppBar 导航行为（仅 push 时显示返回）；
/// 2. 分组设置卡片（12dp 圆角，20dp 边距，0.5dp 发丝线）；
/// 3. 核心功能直达：提拔「分类管理」入口，彻底消除寻找路径过深的问题；
/// 4. 云服务卡片全面 OriginOS 风格化，消除原版组件混搭割裂；
/// 5. 100% 复用 Riverpod 驱动，保持零冲突变基能力。
class CustomSettingsPage extends ConsumerStatefulWidget {
  const CustomSettingsPage({super.key});

  @override
  ConsumerState<CustomSettingsPage> createState() => _CustomSettingsPageState();
}

/// 兼容历史别名
typedef CustomMinePage = CustomSettingsPage;

class _CustomSettingsPageState extends ConsumerState<CustomSettingsPage> {
  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  IconData _mapChoiceIcon(String icon) {
    switch (icon) {
      case 'Settings2':
        return Icons.brightness_auto_rounded;
      case 'Sun':
        return Icons.light_mode_rounded;
      case 'Moon':
        return Icons.dark_mode_rounded;
      case 'List':
        return Icons.format_list_bulleted_rounded;
      case 'Minimize':
        return Icons.compress_rounded;
      case 'Tag':
        return Icons.label_outline_rounded;
      case 'PencilLine':
        return Icons.edit_note_rounded;
      case 'TrendingUp':
        return Icons.trending_up_rounded;
      case 'TrendingDown':
        return Icons.trending_down_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Future<void> _choose<T>(
    String title,
    T selected,
    List<({T value, String title, String? subtitle, String icon})> options,
    ValueChanged<T> save,
  ) async {
    final value = await showOriginActionSheet<T>(
      context,
      title: title,
      selected: selected,
      options: options.map((opt) {
        return OriginChoiceOption<T>(
          value: opt.value,
          title: opt.title,
          subtitle: opt.subtitle,
          icon: _mapChoiceIcon(opt.icon),
        );
      }).toList(),
    );
    if (mounted && value != null) {
      save(value);
    }
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(
      context,
      selected: ref.read(baseCurrencyProvider).toUpperCase(),
      primaryColor: ref.read(primaryColorProvider),
    );
    if (selected != null && mounted) {
      await applyBaseCurrencySelection(context, ref, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);
    final stars =
        ref.watch(githubStarCountProvider).valueOrNull ?? githubStarFallbackCount;

    final canPop = Navigator.of(context).canPop();

    // 外观与主题
    final mode = ref.watch(themeModeProvider);
    final modeNames = [
      l.appearanceThemeModeSystem,
      l.appearanceThemeModeLight,
      l.appearanceThemeModeDark,
    ];
    final skinId = ref.watch(headerSkinProvider);
    final skinName = skinId == kHeaderSkinNone
        ? l.headerSkinNone
        : headerSkinById(skinId)?.nameOf(l) ?? l.headerSkinNone;
    final skinAnimation = ref.watch(skinAnimationEnabledProvider);

    // 记账显示与偏好
    final isCurrencyLocked = ref.watch(currencyLockedProvider);
    final plusButtonEnhanced = ref.watch(plusButtonEnhancedProvider);
    final doubleBackExit = ref.watch(doubleBackExitProvider);
    final accountColorDisplayEnabled = ref.watch(accountColorDisplayProvider);
    final frequentNotesEnabled = ref.watch(frequentNotesEnabledProvider);
    final compactAmount = ref.watch(compactAmountProvider);
    final showCurrencySymbol = ref.watch(currencySymbolVisibleProvider);
    final thousandSeparator = ref.watch(thousandSeparatorProvider);
    final showTime = ref.watch(showTransactionTimeProvider);
    final noteMode = ref.watch(noteDisplayModeProvider);
    final colorScheme = ref.watch(incomeExpenseColorSchemeProvider);

    // 货币与语言
    final language = ref.watch(languageProvider);
    final languageName = language == null
        ? l.languageSystemDefault
        : switch (language.languageCode) {
            'zh' => l.languageChinese,
            'en' => l.languageEnglish,
            'ko' => '한국어',
            _ => language.languageCode,
          };
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final baseCurrencyName =
        displayCurrency(baseCurrency.toUpperCase(), context);

    // 云同步状态
    final cfg = ref.watch(activeCloudConfigProvider);
    final version = ref.watch(beecountCloudServerVersionProvider).valueOrNull;
    final auth = ref.watch(mineCloudUserProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final live = ref.watch(syncStatusProvider(ledgerId));
    final status =
        live.valueOrNull ?? ref.watch(lastSyncStatusProvider(ledgerId));
    final local = cfg.valueOrNull?.type == CloudBackendType.local;
    final canUseCloud = !local &&
        (cfg.valueOrNull?.type == CloudBackendType.icloud ||
            auth.valueOrNull != null);
    final projection =
        mineSyncPresentation(local ? SyncDiff.notConfigured : status?.diff, l);
    final syncError = cfg.error ?? auth.error ?? live.error;
    final syncLabel = syncError != null
        ? l.mineSyncError
        : (canUseCloud && live.isLoading)
            ? l.mineCloudServiceLoading
            : projection.label;

    final cloudName = cfg.when(
      loading: () => l.mineCloudServiceLoading,
      error: (e, _) => '${l.commonError}: $e',
      data: (value) => switch (value.type) {
        CloudBackendType.local => l.mineCloudServiceOffline,
        CloudBackendType.webdav => l.mineCloudServiceWebDAV,
        CloudBackendType.icloud => 'iCloud',
        CloudBackendType.supabase => l.mineCloudServiceCustom,
        CloudBackendType.s3 => 'S3',
        CloudBackendType.beecountCloud => version?.isNotEmpty == true
            ? 'BeeCount Cloud v$version'
            : 'BeeCount Cloud',
      },
    );

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l.commonSettings,
        leading: canPop ? const BackButton() : null,
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 6.0,
          bottom: 120.0 + bottomInset,
        ),
        children: [
          // 1. 云同步与协同服务
          OriginSectionTitle(
            title: l.v4MineCloudGroup,
            margin: const EdgeInsets.fromLTRB(
              OriginTokens.cardMargin,
              8.0,
              OriginTokens.cardMargin,
              6.0,
            ),
          ),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.mineCloudService,
                subtitle: cloudName,
                leading: Icon(
                  Icons.cloud_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                valueText: syncLabel,
                onTap: () => _open(const CloudServicePage()),
              ),
              if (!local)
                OriginSettingItem(
                  title: l.cloudSyncPageTitle,
                  subtitle: syncLabel,
                  leading: Icon(
                    Icons.sync_rounded,
                    color: primaryColor,
                    size: 22.0,
                  ),
                  onTap: () => _open(
                    cfg.valueOrNull?.type == CloudBackendType.beecountCloud
                        ? const BeeCountCloudSyncPage()
                        : const CloudSyncPage(),
                  ),
                ),
            ],
          ),

          // 2. 核心记账功能与管理（直达分类管理）
          OriginSectionTitle(title: l.v4MineFeaturesGroup),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.mineCategoryManagement,
                subtitle: l.mineCategoryManagementSubtitle,
                leading: Icon(
                  Icons.category_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const CustomCategoryManagePage()),
              ),
              OriginSettingItem(
                title: l.tagManageTitle,
                subtitle: l.tagManageSubtitle,
                leading: Icon(
                  Icons.label_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const CustomTagManagePage()),
              ),
              OriginSettingItem(
                title: '账户偏好设置',
                subtitle: '设置默认支出与收入账户',
                leading: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => showOriginAccountPreferencesSheet(context, ref),
              ),
              OriginSettingItem(
                title: l.smartBilling,
                subtitle: l.smartBillingDesc,
                leading: Icon(
                  Icons.auto_awesome_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const SmartBillingPage()),
              ),
              OriginSettingItem(
                title: l.dataManagement,
                subtitle: l.dataManagementDesc,
                leading: Icon(
                  Icons.folder_shared_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const DataManagementPage()),
              ),
              OriginSettingItem(
                title: l.automation,
                subtitle: l.automationDesc,
                leading: Icon(
                  Icons.bolt_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const AutomationPage()),
              ),
            ],
          ),

          // 3. 外观与个性化
          OriginSectionTitle(title: l.appearanceSettingsPageTitle),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.appearanceThemeMode,
                valueText: modeNames[mode.index],
                leading: Icon(
                  Icons.brightness_medium_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _choose(
                  l.appearanceThemeMode,
                  mode,
                  [
                    for (final value in ThemeMode.values)
                      (
                        value: value,
                        title: modeNames[value.index],
                        subtitle: null,
                        icon: ['Settings2', 'Sun', 'Moon'][value.index]
                      )
                  ],
                  (v) => ref.read(themeModeProvider.notifier).state = v,
                ),
              ),
              OriginSettingItem(
                title: l.personalizeTitle,
                subtitle: l.personalizeSubtitle,
                leading: Icon(
                  Icons.palette_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const PersonalizePage()),
              ),
              OriginSettingItem(
                title: l.headerSkinTitle,
                valueText: skinName,
                leading: Icon(
                  Icons.image_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const HeaderSkinPage()),
              ),
              OriginSettingItem(
                title: l.appearanceSkinAnimation,
                subtitle: l.appearanceSkinAnimationDesc,
                leading: Icon(
                  Icons.animation_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: skinAnimation,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(skinAnimationEnabledProvider.notifier)
                      .state = v,
                ),
                onTap: () => ref
                    .read(skinAnimationEnabledProvider.notifier)
                    .state = !skinAnimation,
              ),
              OriginSettingItem(
                title: l.mineDisplayScale,
                subtitle: l.mineDisplayScaleSubtitle,
                leading: Icon(
                  Icons.format_size_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const FontSettingsPage()),
              ),
            ],
          ),

          // 4. 记账显示偏好
          OriginSectionTitle(title: l.appearanceSettingsPageSubtitle),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.appearanceAmountFormat,
                valueText: compactAmount
                    ? l.appearanceAmountFormatCompact
                    : l.appearanceAmountFormatFull,
                leading: Icon(
                  Icons.wallet_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _choose(
                  l.appearanceAmountFormat,
                  ref.read(compactAmountProvider),
                  [
                    (
                      value: false,
                      title: l.appearanceAmountFormatFull,
                      subtitle: l.appearanceAmountFormatFullDesc,
                      icon: 'List'
                    ),
                    (
                      value: true,
                      title: l.appearanceAmountFormatCompact,
                      subtitle: l.appearanceAmountFormatCompactDesc,
                      icon: 'Minimize'
                    )
                  ],
                  (v) => ref.read(compactAmountProvider.notifier).state = v,
                ),
              ),
              OriginSettingItem(
                title: '加号增强',
                subtitle: plusButtonEnhanced
                    ? '开启：长按语音，双击拍照'
                    : '关闭：长按展开快捷菜单',
                leading: Icon(
                  Icons.add_circle_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: plusButtonEnhanced,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(plusButtonEnhancedProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(plusButtonEnhancedProvider.notifier)
                    .toggle(),
              ),
              OriginSettingItem(
                title: '双击返回退出',
                subtitle: doubleBackExit
                    ? '开启：主界面需连续按两次返回键退出'
                    : '关闭：主界面按一次返回键直接退出',
                leading: Icon(
                  Icons.exit_to_app_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: doubleBackExit,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(doubleBackExitProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(doubleBackExitProvider.notifier)
                    .toggle(),
              ),
              OriginSettingItem(
                title: '明细页面资产颜色显示',
                subtitle: accountColorDisplayEnabled
                    ? '开启：按资产属性变换颜色（微信绿/支付宝蓝/信用卡紫等）'
                    : '关闭：保持默认灰色',
                leading: Icon(
                  Icons.palette_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: accountColorDisplayEnabled,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(accountColorDisplayProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(accountColorDisplayProvider.notifier)
                    .toggle(),
              ),
              OriginSettingItem(
                title: '常用备注推荐',
                subtitle: frequentNotesEnabled
                    ? '开启：记账时展示高频历史备注'
                    : '关闭：不展示高频历史备注',
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: frequentNotesEnabled,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(frequentNotesEnabledProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(frequentNotesEnabledProvider.notifier)
                    .toggle(),
              ),
              if (!isCurrencyLocked)
                OriginSettingItem(
                  title: '货币符号',
                  subtitle: showCurrencySymbol
                      ? '开启：显示货币符号（如 ¥8888.00）'
                      : '关闭：不显示货币符号（如 8888.00）',
                  leading: Icon(
                    Icons.currency_yen_rounded,
                    color: primaryColor,
                    size: 22.0,
                  ),
                  showArrow: false,
                  trailing: OriginSwitch(
                    value: showCurrencySymbol,
                    activeColor: primaryColor,
                    onChanged: (v) => ref
                        .read(currencySymbolVisibleProvider.notifier)
                        .setEnabled(v),
                  ),
                  onTap: () => ref
                      .read(currencySymbolVisibleProvider.notifier)
                      .toggle(),
                ),
              OriginSettingItem(
                title: '金额千分位',
                subtitle: thousandSeparator
                    ? '开启：显示为 8,888.00'
                    : '关闭：显示为 8888.00',
                leading: Icon(
                  Icons.pin_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: thousandSeparator,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(thousandSeparatorProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(thousandSeparatorProvider.notifier)
                    .toggle(),
              ),
              OriginSettingItem(
                title: l.appearanceShowTransactionTime,
                subtitle: l.appearanceShowTransactionTimeDesc,
                leading: Icon(
                  Icons.access_time_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: showTime,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(showTransactionTimeProvider.notifier)
                      .state = v,
                ),
                onTap: () => ref
                    .read(showTransactionTimeProvider.notifier)
                    .state = !showTime,
              ),
              OriginSettingItem(
                title: l.appearanceNoteDisplay,
                valueText: noteMode == 'note'
                    ? l.appearanceNoteDisplayNote
                    : l.appearanceNoteDisplayCategory,
                leading: Icon(
                  Icons.notes_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _choose(
                  l.appearanceNoteDisplay,
                  ref.read(noteDisplayModeProvider),
                  [
                    (
                      value: 'category',
                      title: l.appearanceNoteDisplayCategory,
                      subtitle: l.appearanceNoteDisplayCategoryDesc,
                      icon: 'Tag'
                    ),
                    (
                      value: 'note',
                      title: l.appearanceNoteDisplayNote,
                      subtitle: l.appearanceNoteDisplayNoteDesc,
                      icon: 'PencilLine'
                    )
                  ],
                  (v) =>
                      ref.read(noteDisplayModeProvider.notifier).state = v,
                ),
              ),
              OriginSettingItem(
                title: l.appearanceNoteHistory,
                subtitle: noteHistorySummary(ref, l),
                leading: Icon(
                  Icons.history_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => showNoteHistoryPreferences(context),
              ),
              OriginSettingItem(
                title: l.appearanceColorScheme,
                valueText: colorScheme
                    ? l.appearanceColorSchemeOn
                    : l.appearanceColorSchemeOff,
                leading: Icon(
                  Icons.swap_vert_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _choose(
                  l.appearanceColorScheme,
                  ref.read(incomeExpenseColorSchemeProvider),
                  [
                    (
                      value: true,
                      title: l.appearanceColorSchemeOn,
                      subtitle: l.appearanceColorSchemeOnDesc,
                      icon: 'TrendingUp'
                    ),
                    (
                      value: false,
                      title: l.appearanceColorSchemeOff,
                      subtitle: l.appearanceColorSchemeOffDesc,
                      icon: 'TrendingDown'
                    )
                  ],
                  (v) => ref
                      .read(incomeExpenseColorSchemeProvider.notifier)
                      .state = v,
                ),
              ),
            ],
          ),

          // 5. 货币与汇率
          OriginSectionTitle(title: l.exchangeRatePageTitle),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.baseCurrencyLabel,
                valueText: baseCurrencyName,
                leading: Icon(
                  Icons.monetization_on_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: _pickCurrency,
              ),
              OriginSettingItem(
                title: '锁定币种',
                subtitle: isCurrencyLocked
                    ? '已锁定单币种，全软件隐藏币种标识与符号'
                    : '关闭多币种功能，隐藏币种切换与货币符号',
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                trailing: OriginSwitch(
                  value: isCurrencyLocked,
                  activeColor: primaryColor,
                  onChanged: (v) => ref
                      .read(currencyLockedProvider.notifier)
                      .setEnabled(v),
                ),
                onTap: () => ref
                    .read(currencyLockedProvider.notifier)
                    .toggle(),
              ),
              if (!isCurrencyLocked)
                OriginSettingItem(
                  title: l.exchangeRatePageTitle,
                  subtitle: l.exchangeRateEntrySubtitle,
                  leading: Icon(
                    Icons.currency_exchange_rounded,
                    color: primaryColor,
                    size: 22.0,
                  ),
                  onTap: () => _open(const ExchangeRatePage()),
                ),
            ],
          ),

          // 6. 系统与安全
          OriginSectionTitle(title: l.commonSettings),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.mineLanguageSettings,
                valueText: languageName,
                leading: Icon(
                  Icons.language_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const LanguageSettingsPage()),
              ),
              OriginSettingItem(
                title: l.widgetManagement,
                subtitle: l.widgetManagementDesc,
                leading: Icon(
                  Icons.widgets_outlined,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const WidgetManagementPage()),
              ),
              OriginSettingItem(
                title: l.appLockTitle,
                subtitle: l.appLockDesc,
                leading: Icon(
                  Icons.lock_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const AppLockSettingsPage()),
              ),
            ],
          ),

          // 7. 帮助与关于
          OriginSectionTitle(title: l.v4MineHelpGroup),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.about,
                subtitle: l.aboutDesc,
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const AboutPage()),
              ),
              OriginSettingItem(
                title: l.mineHelp,
                subtitle: l.mineHelpSubtitle,
                leading: Icon(
                  Icons.help_outline_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () async {
                  if (kHelpCenterInApp) {
                    _open(const HelpCenterPage());
                  } else {
                    await tryOpenMineUrl(
                      Uri.parse(
                        WebsiteUrls.docs(Localizations.localeOf(context)),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          // 8. 交流与支持
          OriginSectionTitle(title: l.v4MineSupportGroup),
          OriginSettingGroup(
            items: [
              if (Platform.isIOS)
                OriginSettingItem(
                  title: l.donationTitle,
                  subtitle: l.donationEntrySubtitle,
                  leading: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF5252),
                    size: 22.0,
                  ),
                  onTap: () => _open(const DonationPage()),
                ),
              OriginSettingItem(
                title: l.mineSupportAuthor,
                subtitle: l.mineSupportAuthorSubtitle(stars.toString()),
                leading: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFB300),
                  size: 22.0,
                ),
                onTap: () => showMineGitHubStarGuide(context),
              ),
              OriginSettingItem(
                title: l.annualReportTitle,
                subtitle: l.annualReportEntrySubtitle,
                leading: Icon(
                  Icons.auto_graph_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => _open(const AnnualReportPage()),
              ),
              OriginSettingItem(
                title: l.mineShareApp,
                subtitle: l.mineShareWithFriends,
                leading: Icon(
                  Icons.share_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () =>
                    SharePosterService.showPosterCarouselPreview(context),
              ),
              OriginSettingItem(
                title: l.mineCopyPromoText,
                subtitle: l.mineCopyPromoSubtitle,
                leading: Icon(
                  Icons.copy_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                showArrow: false,
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(text: l.shareGuidanceCopyText),
                  );
                  if (context.mounted) {
                    showBeeToast(
                      context,
                      l.shareGuidanceCopied,
                      tone: BeeTone.success,
                    );
                  }
                },
              ),
              if (Platform.isIOS)
                OriginSettingItem(
                  title: l.mineRateApp,
                  subtitle: l.mineRateAppSubtitle,
                  leading: const Icon(
                    Icons.rate_review_rounded,
                    color: Color(0xFFFF9800),
                    size: 22.0,
                  ),
                  onTap: () => rateMineApp(context),
                ),
            ],
          ),
          const SizedBox(height: 28.0),
          Center(
            child: Text(
              '${OriginAppInfo.appName} · 本地优先安全记账',
              style: OriginTokens.captionStyle(context).copyWith(
                color: OriginTokens.textTertiary(context),
                fontSize: 11.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 12.0),
        ],
      ),
    );
  }
}
