import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/github_star_provider.dart';
import '../../providers/feature_highlight_providers.dart';
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
import '../../pages/shared/selectors/currency_picker_sheet.dart';
import '../../pages/currency/exchange_rate_page.dart';
import '../../pages/report/annual_report_page.dart';
import '../../pages/donation/donation_page.dart';
import '../../pages/shared/widgets/feature_dot.dart';
import '../../services/export/share_poster_service.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_setting_card.dart';
import '../widgets/origin_dialog.dart';
import '../widgets/origin_bottom_sheet.dart';

/// vivo OriginOS 风格“我的”与设置页面 (CustomMinePage)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md` 与 `24`:
/// 1. 大标题栏（84dp / 22sp SemiBold）；
/// 2. 分组设置卡片（12dp 圆角，20dp 边距，0.5dp 发丝线）；
/// 3. 日间纯白卡片，夜间 #202020 纯深色卡片；
/// 4. 纯 Riverpod 驱动，将原通用/外观设置页面内容完整平铺迁移至本页面，保持 100% 逻辑复用。
class CustomMinePage extends ConsumerStatefulWidget {
  const CustomMinePage({super.key});

  @override
  ConsumerState<CustomMinePage> createState() => _CustomMinePageState();
}

class _CustomMinePageState extends ConsumerState<CustomMinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) markAnchorVisited(ref, 'personalize');
    });
  }

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
    final primaryColor = ref.watch(primaryColorProvider);
    final stars =
        ref.watch(githubStarCountProvider).valueOrNull ?? githubStarFallbackCount;

    final canPop = Navigator.of(context).canPop();
    final tabIdx = ref.watch(bottomTabIndexProvider);

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
    final compactAmount = ref.watch(compactAmountProvider);
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

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l.mineTitle,
        leading: (canPop || tabIdx == 3)
            ? BackButton(
                onPressed: () {
                  if (ref.read(bottomTabIndexProvider) == 3) {
                    ref.read(bottomTabIndexProvider.notifier).state = 0;
                  }
                  if (canPop) {
                    Navigator.of(context).pop();
                  }
                },
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8.0, bottom: 120.0),
        children: [
          // 1. 云同步与服务
          OriginSectionTitle(title: l.v4MineCloudGroup),
          const OriginCard(
            margin: EdgeInsets.symmetric(
              horizontal: OriginTokens.cardMargin,
              vertical: 4.0,
            ),
            child: MineCloudBinding(),
          ),

          // 2. 核心功能分组
          OriginSectionTitle(title: l.v4MineFeaturesGroup),
          OriginSettingGroup(
            items: [
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
                  Icons.folder_shared_rounded,
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
            ],
          ),

          // 3. 外观与个性化（原设置页面内容迁移）
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
                leading: FeatureDot(
                  anchor: 'personalize',
                  child: Icon(
                    Icons.palette_rounded,
                    color: primaryColor,
                    size: 22.0,
                  ),
                ),
                onTap: () => _open(const PersonalizePage()),
              ),
              OriginSettingItem(
                title: l.headerSkinTitle,
                valueText: skinName,
                leading: FeatureDot(
                  anchor: 'header_skin',
                  child: Icon(
                    Icons.image_outlined,
                    color: primaryColor,
                    size: 22.0,
                  ),
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

          // 4. 记账显示偏好（原设置页面内容迁移）
          OriginSectionTitle(title: l.appearanceSettingsPageSubtitle),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.appearanceAmountFormat,
                valueText: compactAmount
                    ? l.appearanceAmountFormatCompact
                    : l.appearanceAmountFormatFull,
                leading: Icon(
                  Icons.account_balance_wallet_outlined,
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

          // 5. 货币与汇率（原设置页面内容迁移）
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

          // 6. 系统与安全（原设置页面内容迁移）
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
