import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/settings/reminder_settings_page.dart';
import '../styles/origin_tokens.dart';
import '../widgets/origin_scaffold.dart';
import '../widgets/origin_setting_card.dart';
import 'custom_recurring_transaction_page.dart';

/// vivo OriginOS 风格自动化页面 (CustomAutomationPage)
class CustomAutomationPage extends ConsumerWidget {
  const CustomAutomationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final primaryColor = OriginTokens.primary(context);

    void open(Widget page) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    }

    return OriginScaffold(
      appBar: OriginSmallTopAppBar(
        title: l.automationPageTitle,
        leading: BackButton(
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          vertical: 12.0,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OriginTokens.cardMargin,
              4.0,
              OriginTokens.cardMargin,
              10.0,
            ),
            child: Text(
              l.automationPageSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: OriginTokens.textSecondary(context),
              ),
            ),
          ),
          OriginSettingGroup(
            items: [
              OriginSettingItem(
                title: l.mineRecurringTransactions,
                subtitle: l.mineRecurringTransactionsSubtitle,
                leading: Icon(
                  Icons.repeat_rounded,
                  size: 22,
                  color: primaryColor,
                ),
                onTap: () => open(const CustomRecurringTransactionPage()),
              ),
              OriginSettingItem(
                title: l.mineReminderSettings,
                subtitle: l.mineReminderSettingsSubtitle,
                leading: Icon(
                  Icons.notifications_none_rounded,
                  size: 22,
                  color: primaryColor,
                ),
                onTap: () => open(const ReminderSettingsPage()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
