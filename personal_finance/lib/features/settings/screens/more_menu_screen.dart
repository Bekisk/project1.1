import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/app/theme/theme_provider.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/accounts/screens/accounts_management_screen.dart';
import 'package:personal_finance/features/categories/screens/categories_management_screen.dart';
import 'package:personal_finance/features/settings/providers/app_settings_provider.dart';
import 'package:personal_finance/features/settings/screens/data_management_screen.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/features/notifications/screens/daily_summary_screen.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/profile/screens/profile_screen.dart';
import 'package:personal_finance/features/profile/widgets/profile_avatar.dart';
import 'package:personal_finance/features/recurring/screens/subscriptions_screen.dart';
import 'package:personal_finance/features/sms_parser/screens/bank_sms_integration_screen.dart';
import 'package:personal_finance/features/security/providers/app_lock_provider.dart';
import 'package:personal_finance/features/security/screens/change_pin_screen.dart';
import 'package:personal_finance/features/security/screens/setup_pin_screen.dart';
import 'package:personal_finance/features/security/services/app_lock_service.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<AppSettingsProvider>();
    final profileProvider = context.watch<UserProfileProvider>();
    final lockProvider = context.watch<AppLockProvider>();
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Preferences')),
      body: LiquidAtmosphereBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 0. PERSONAL PROFILE SECTION
            _buildSectionHeader(context, 'PERSONAL PROFILE'),
            FintechCard(
              padding: const EdgeInsets.all(14),
              child: InkWell(
                onTap: () => ProfileScreen.navigate(context),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    ProfileAvatar(
                      imagePath: profile?.profileImagePath,
                      displayName: profileProvider.displayName,
                      radius: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileProvider.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile?.occupation ??
                                'Manage your personal information',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(
                          alpha: isDark ? 0.2 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppTheme.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 1. FINANCES & ENTITIES
            _buildSectionHeader(context, 'FINANCES & STRUCTURE'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppTheme.primaryGreen,
                    title: 'Accounts & Wallets',
                    subtitle: 'Manage Cash, Banks (CBE, Awash), Mobile Money (Telebirr)',
                    onTap: () => AccountsManagementScreen.navigate(context),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    context,
                    icon: Icons.category_rounded,
                    iconColor: AppTheme.transferBlue,
                    title: 'Expense & Income Categories',
                    subtitle: 'Custom category icons, labels, and palettes',
                    onTap: () => CategoriesManagementScreen.navigate(context),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    context,
                    icon: Icons.autorenew_rounded,
                    iconColor: AppTheme.accentPurple,
                    title: 'Recurring & Subscriptions',
                    subtitle: 'Manage fixed commitments, auto-scheduled bills',
                    onTap: () => SubscriptionsScreen.navigate(context),
                  ),
                  _buildDivider(isDark),
                  _buildListTile(
                    context,
                    icon: Icons.mark_email_read_rounded,
                    iconColor: AppTheme.accentAmber,
                    title: 'Bank SMS Integration',
                    subtitle: 'Automatic tracker, review queue, CBE, Telebirr & Awash',
                    onTap: () => BankSmsIntegrationScreen.navigate(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. APPEARANCE & THEME
            _buildSectionHeader(context, 'APPEARANCE & THEME'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.brightness_6_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Theme Mode',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            themeProvider.themeMode == ThemeMode.dark
                                ? 'Dark Mode (Enforced Default)'
                                : 'Light Mode',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: themeProvider.themeMode == ThemeMode.light
                          ? ThemeMode.light
                          : ThemeMode.dark,
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(
                            'Dark (Default)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(
                            'Light',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (newMode) {
                        if (newMode != null) {
                          themeProvider.setThemeMode(newMode);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. REGIONAL & FORMATTING
            _buildSectionHeader(context, 'CURRENCY & REGIONAL FORMAT'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  // Currency Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentAmber.withValues(
                                    alpha: isDark ? 0.2 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.attach_money_rounded,
                                  color: AppTheme.accentAmber,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Display Currency',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${settingsProvider.currency.label} (${settingsProvider.currency.symbol})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.textSecondaryDark
                                            : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<AppCurrency>(
                            value: settingsProvider.currency,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            items: AppCurrency.values.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  '${c.code} (${c.symbol})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                settingsProvider.setCurrency(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDivider(isDark),

                  // Amharic Suffix Toggle
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.translate_rounded,
                          color: AppTheme.accentTeal,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Amharic Birr Suffix (ብር)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Displays amounts with "ብር" suffix (e.g. 500.00 ብር)',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settingsProvider.isAmharicSuffix,
                      onChanged: (val) =>
                          settingsProvider.setAmharicSuffix(val),
                    ),
                  ),
                  _buildDivider(isDark),

                  // Date Format Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentBlue.withValues(
                                    alpha: isDark ? 0.2 : 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.event_rounded,
                                  color: AppTheme.accentBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Date Format',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      settingsProvider.dateFormat.sample,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppTheme.textSecondaryDark
                                            : AppTheme.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<AppDateFormat>(
                            value: settingsProvider.dateFormat,
                            borderRadius: BorderRadius.circular(14),
                            dropdownColor: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            items: AppDateFormat.values.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(
                                  d.pattern,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                settingsProvider.setDateFormat(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. BEHAVIOR & SAFETY
            _buildSectionHeader(context, 'BEHAVIOR & SAFETY'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.accentCoral,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Confirm Destructive Actions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Prompts before deleting transactions, budgets, or goals',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settingsProvider.confirmDestructiveActions,
                      onChanged: (val) =>
                          settingsProvider.setConfirmDestructiveActions(val),
                    ),
                  ),
                  _buildDivider(isDark),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: AppTheme.accentPurple,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Budget Threshold Alerts',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Highlights budgets approaching 80% or exceeded',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settingsProvider.budgetAlertsEnabled,
                      onChanged: (val) =>
                          settingsProvider.setBudgetAlertsEnabled(val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. SECURITY
            _buildSectionHeader(context, 'SECURITY'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'App Lock',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        lockProvider.isLockConfigured
                            ? 'PIN and biometric lock are enabled'
                            : 'Secure your app with a PIN',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      value: lockProvider.isLockConfigured,
                      onChanged: (val) async {
                        if (val) {
                          SetupPinScreen.navigate(context);
                        } else {
                          await _promptDisableLock(context, lockProvider);
                        }
                      },
                    ),
                  ),
                  if (lockProvider.isLockConfigured) ...[
                    _buildDivider(isDark),
                    _buildListTile(
                      context,
                      icon: Icons.pin_rounded,
                      iconColor: AppTheme.accentPurple,
                      title: 'Change PIN',
                      subtitle: 'Update your 6-digit app lock PIN',
                      onTap: () => ChangePinScreen.navigate(context),
                    ),
                    _buildDivider(isDark),
                    _buildListTile(
                      context,
                      icon: Icons.fingerprint_rounded,
                      iconColor: AppTheme.accentTeal,
                      title: 'Biometric Unlock',
                      subtitle: lockProvider.biometricAvailable
                          ? (lockProvider.biometricEnabled
                                ? '${lockProvider.biometricLabel} is enabled'
                                : 'Enable ${lockProvider.biometricLabel}')
                          : 'No biometrics enrolled on this device',
                      onTap: lockProvider.biometricAvailable
                          ? () async {
                              await lockProvider.setBiometricEnabled(
                                !lockProvider.biometricEnabled,
                              );
                              lockProvider.refreshBiometricSettings();
                            }
                          : null,
                      trailing: lockProvider.biometricAvailable
                          ? Switch(
                              value: lockProvider.biometricEnabled,
                              onChanged: (val) async {
                                await lockProvider.setBiometricEnabled(val);
                              },
                              activeColor: AppTheme.primaryGreen,
                            )
                          : const SizedBox.shrink(),
                    ),
                    _buildDivider(isDark),
                    _buildListTile(
                      context,
                      icon: Icons.timer_rounded,
                      iconColor: AppTheme.accentAmber,
                      title: 'Lock Timeout',
                      subtitle:
                          'How long before the app re-locks after inactivity',
                      onTap: () => _showTimeoutSelector(context),
                    ),
                    _buildDivider(isDark),
                    _buildListTile(
                      context,
                      icon: Icons.lock_clock_rounded,
                      iconColor: AppTheme.accentCoral,
                      title: 'Lock Now',
                      subtitle: 'Immediately lock the app',
                      onTap: () => lockProvider.lockNow(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. DAILY FINANCIAL SUMMARY NOTIFICATION
            _buildSectionHeader(context, 'DAILY FINANCIAL SUMMARY'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.alarm_rounded,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Daily Financial Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Get a daily reminder with a summary of your recorded income and expenses.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: settingsProvider.dailySummaryEnabled,
                      onChanged: (val) async {
                        final success = await settingsProvider
                            .setDailySummaryEnabled(val);
                        if (!success && val && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Notification permission is required to enable daily summary.',
                              ),
                              backgroundColor: AppTheme.accentCoral,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  _buildDivider(isDark),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentTeal.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppTheme.accentTeal,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Notification Time',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        settingsProvider.dailySummaryTime.format(context),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () async {
                        final chosen = await showTimePicker(
                          context: context,
                          initialTime: settingsProvider.dailySummaryTime,
                          helpText: 'SELECT DAILY NOTIFICATION TIME',
                          builder: (ctx, child) {
                            return MediaQuery(
                              data: MediaQuery.of(ctx)
                                  .copyWith(alwaysUse24HourFormat: false),
                              child: child!,
                            );
                          },
                        );
                        if (chosen != null) {
                          await settingsProvider.setDailySummaryTime(chosen);
                        }
                      },
                    ),
                  ),
                  _buildDivider(isDark),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                !settingsProvider.notificationPermissionGranted
                                    ? Icons.warning_rounded
                                    : (settingsProvider.dailySummaryEnabled
                                          ? Icons.check_circle_rounded
                                          : Icons.info_outline_rounded),
                                size: 16,
                                color:
                                    !settingsProvider
                                        .notificationPermissionGranted
                                    ? AppTheme.accentCoral
                                    : (settingsProvider.dailySummaryEnabled
                                          ? AppTheme.accentTeal
                                          : Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  !settingsProvider
                                          .notificationPermissionGranted
                                      ? 'Notification permission required'
                                      : (settingsProvider.dailySummaryEnabled
                                            ? 'Daily summary enabled — ${settingsProvider.dailySummaryTime.format(context)}'
                                            : 'Daily summary disabled'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        !settingsProvider
                                            .notificationPermissionGranted
                                        ? AppTheme.accentCoral
                                        : (settingsProvider.dailySummaryEnabled
                                              ? (isDark
                                                    ? Colors.white70
                                                    : Colors.black87)
                                              : Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (settingsProvider.dailySummaryEnabled)
                              TextButton(
                                onPressed: () async {
                                  await settingsProvider
                                      .testDailyNotification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Test notification sent! Check your notification tray.',
                                        ),
                                        backgroundColor: AppTheme.primaryGreen,
                                      ),
                                    );
                                  }
                                },
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Test',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            TextButton(
                              onPressed: () =>
                                  DailySummaryScreen.navigate(context),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'View Today',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. DATA MANAGEMENT & BACKUP
            _buildSectionHeader(context, 'DATA & OFFLINE STORAGE'),
            FintechCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildListTile(
                context,
                icon: Icons.backup_rounded,
                iconColor: AppTheme.primaryGreen,
                title: 'Backup, Export & Restore',
                subtitle:
                    'JSON offline backup, CSV transactions export, data reset',
                onTap: () => DataManagementScreen.navigate(context),
              ),
            ),
            const SizedBox(height: 24),

            // 6. ABOUT
            _buildSectionHeader(context, 'ABOUT MY FINANCE'),
            FintechCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppTheme.primaryGreen,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Finance Personal Manager',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Version 1.0.0+1 • Offline-first SQLite Architecture',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          showLicensePage(
                            context: context,
                            applicationName: 'My Finance',
                            applicationVersion: '1.0.0+1',
                          );
                        },
                        child: const Text('Open Source Licenses'),
                      ),
                      TextButton(
                        onPressed: () {
                          settingsProvider.resetPreferencesToDefaults();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preferences reset to defaults'),
                            ),
                          );
                        },
                        child: const Text(
                          'Reset Preferences',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      indent: 52,
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showTimeoutSelector(BuildContext context) async {
    final lockProvider = context.read<AppLockProvider>();
    final currentTimeout = await lockProvider.getLockTimeout();

    if (!context.mounted) return;

    final selected = await showModalBottomSheet<AppLockTimeout>(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.borderPrimary : AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lock Timeout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...AppLockTimeout.values.map((timeout) {
                final isSelected = timeout == currentTimeout;
                return ListTile(
                  title: Text(timeout.label),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: AppTheme.primaryGreen)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(timeout),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentTimeout) {
      await lockProvider.setLockTimeout(selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Lock timeout set to ${selected.label.toLowerCase()}',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    }
  }

  Future<void> _promptDisableLock(
    BuildContext context,
    AppLockProvider lockProvider,
  ) async {
    final pinController = TextEditingController();
    String? errorText;

    final disabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppTheme.cardCharcoal : Colors.white,
              title: const Text(
                'Disable App Lock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter your current PIN to turn off app lock:'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Current PIN',
                      errorText: errorText,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.expenseRed,
                  ),
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final isValid = await lockProvider.verifyPin(pin);
                    if (isValid) {
                      await lockProvider.disableLock();
                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop(true);
                      }
                    } else {
                      setDialogState(() {
                        errorText = 'Incorrect PIN';
                      });
                    }
                  },
                  child: const Text('Turn Off'),
                ),
              ],
            );
          },
        );
      },
    );

    if (disabled == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('App lock disabled')));
    }
  }
}
