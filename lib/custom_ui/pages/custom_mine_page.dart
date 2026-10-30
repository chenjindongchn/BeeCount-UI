import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/github_star_provider.dart';
import '../../providers.dart';
import '../../utils/website_urls.dart';
import '../../pages/main/mine/bindings/mine_cloud.dart';
import '../../pages/main/mine/bindings/mine_actions.dart';
import '../../pages/settings/help_center_page.dart';
import '../../pages/settings/data_management_page.dart';
import '../../pages/settings/appearance_settings_page.dart';
import '../../pages/settings/smart_billing_page.dart';
import '../../pages/settings/automation_page.dart';
import '../../pages/settings/about_page.dart';
import '../../pages/report/annual_report_page.dart';
import '../../pages/donation/donation_page.dart';
import '../../pages/shared/widgets/feature_dot.dart';
import '../../services/export/share_poster_service.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_card.dart';
import '../widgets/origin_setting_card.dart';

/// vivo OriginOS 风格“我的”与设置页面 (CustomMinePage)
///
/// 遵循 `OriginUI/docs/13-card-corner-and-hairline-divider.md` 与 `24`:
/// 1. 大标题栏（84dp / 22sp SemiBold）；
/// 2. 分组设置卡片（12dp 圆角，20dp 边距，0.5dp 发丝线）；
/// 3. 日间纯白卡片，夜间 #202020 纯深色卡片；
/// 4. 纯 Riverpod 驱动，不修改原有设置逻辑。
class CustomMinePage extends ConsumerWidget {
  const CustomMinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final stars = ref.watch(githubStarCountProvider).valueOrNull ?? githubStarFallbackCount;

    void open(Widget page) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        );

    return OriginScaffold(
      appBar: OriginLargeTopAppBar(
        title: l.mineTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l.commonSettings,
            onPressed: () => open(const AppearanceSettingsPage()),
          ),
        ],
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
                onTap: () => open(const SmartBillingPage()),
              ),
              OriginSettingItem(
                title: l.dataManagement,
                subtitle: l.dataManagementDesc,
                leading: Icon(
                  Icons.folder_shared_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => open(const DataManagementPage()),
              ),
              OriginSettingItem(
                title: l.automation,
                subtitle: l.automationDesc,
                leading: Icon(
                  Icons.bolt_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => open(const AutomationPage()),
              ),
              OriginSettingItem(
                title: l.appearanceSettings,
                subtitle: l.appearanceSettingsDesc,
                leading: FeatureDot(
                  anchor: 'personalize',
                  child: Icon(
                    Icons.palette_rounded,
                    color: primaryColor,
                    size: 22.0,
                  ),
                ),
                onTap: () => open(const AppearanceSettingsPage()),
              ),
            ],
          ),

          // 3. 帮助与关于
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
                onTap: () => open(const AboutPage()),
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
                    open(const HelpCenterPage());
                  } else {
                    await tryOpenMineUrl(
                      Uri.parse(WebsiteUrls.docs(Localizations.localeOf(context))),
                    );
                  }
                },
              ),
            ],
          ),

          // 4. 交流与支持
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
                  onTap: () => open(const DonationPage()),
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
                onTap: () => open(const AnnualReportPage()),
              ),
              OriginSettingItem(
                title: l.mineShareApp,
                subtitle: l.mineShareWithFriends,
                leading: Icon(
                  Icons.share_rounded,
                  color: primaryColor,
                  size: 22.0,
                ),
                onTap: () => SharePosterService.showPosterCarouselPreview(context),
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
                  await Clipboard.setData(ClipboardData(text: l.shareGuidanceCopyText));
                  if (context.mounted) {
                    showBeeToast(context, l.shareGuidanceCopied, tone: BeeTone.success);
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
        ],
      ),
    );
  }
}
