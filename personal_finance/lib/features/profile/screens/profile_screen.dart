import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/screens/accounts_management_screen.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/profile/screens/edit_profile_screen.dart';
import 'package:personal_finance/features/profile/widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Account? _mainAccount;
  Account? _savingsAccount;
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadLinkedAccounts();
  }

  Future<void> _loadLinkedAccounts() async {
    final profileProvider = context.read<UserProfileProvider>();
    final profile = profileProvider.profile;
    if (profile == null) {
      setState(() => _isLoadingAccounts = false);
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;
      Account? mainAcc;
      Account? savingsAcc;

      if (profile.mainAccountId != null) {
        final res = await db.query('accounts', where: 'id = ?', whereArgs: [profile.mainAccountId]);
        if (res.isNotEmpty) mainAcc = Account.fromMap(res.first);
      }
      if (profile.designatedSavingsAccountId != null) {
        final res = await db.query('accounts', where: 'id = ?', whereArgs: [profile.designatedSavingsAccountId]);
        if (res.isNotEmpty) savingsAcc = Account.fromMap(res.first);
      }

      if (mounted) {
        setState(() {
          _mainAccount = mainAcc;
          _savingsAccount = savingsAcc;
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAccounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () async {
              await EditProfileScreen.navigate(context);
              _loadLinkedAccounts();
            },
          ),
        ],
      ),
      body: LiquidAtmosphereBackground(
        child: profile == null
            ? const Center(child: Text('No profile found. Please complete profile setup.'))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // 1. Hero Avatar & Identity Card
                  FintechCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        ProfileAvatar(
                          imagePath: profile.profileImagePath,
                          displayName: profile.displayName,
                          radius: 46,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.4),
                        ),
                        if (profile.fullName != null && profile.fullName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            profile.fullName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                        if (profile.occupation != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              profile.occupation!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.primaryAccent : AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await EditProfileScreen.navigate(context);
                            _loadLinkedAccounts();
                          },
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text('Edit Profile Details'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Personal Information Section
                  _buildSectionHeader('PERSONAL DETAILS', isDark),
                  FintechCard(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                    child: Column(
                      children: [
                        _buildInfoRow('Nickname', profile.nickname ?? 'Not specified', isDark),
                        _buildDivider(isDark),
                        _buildInfoRow('Age Range', profile.ageRange ?? 'Prefer not to say', isDark),
                        _buildDivider(isDark),
                        _buildInfoRow('Country / Region', profile.countryOrRegion ?? 'Ethiopia', isDark),
                        _buildDivider(isDark),
                        _buildInfoRow('Discovery Source', profile.discoverySource ?? 'Not provided', isDark),
                        if (profile.discoverySourceOther != null) ...[
                          _buildDivider(isDark),
                          _buildInfoRow('Other Source Note', profile.discoverySourceOther!, isDark),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Financial Preferences & Roles
                  _buildSectionHeader('FINANCIAL ROLES & PREFERENCES', isDark),
                  FintechCard(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Main Account',
                          _isLoadingAccounts
                              ? 'Loading...'
                              : (_mainAccount?.name ?? 'Not selected (Default wallet used)'),
                          isDark,
                          trailingAction: TextButton(
                            onPressed: () => AccountsManagementScreen.navigate(context),
                            child: const Text('Manage', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        _buildDivider(isDark),
                        _buildInfoRow(
                          'Designated Savings',
                          _isLoadingAccounts
                              ? 'Loading...'
                              : (_savingsAccount?.name ?? 'None designated'),
                          isDark,
                          trailingAction: TextButton(
                            onPressed: () => AccountsManagementScreen.navigate(context),
                            child: const Text('Manage', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        _buildDivider(isDark),
                        _buildInfoRow('Display Currency', profile.preferredCurrency, isDark),
                        _buildDivider(isDark),
                        _buildInfoRow('Language', profile.preferredLanguage, isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Financial Motivation / Goal
                  if (profile.personalGoal != null && profile.personalGoal!.isNotEmpty) ...[
                    _buildSectionHeader('PRIMARY FINANCIAL GOAL', isDark),
                    FintechCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.flag_rounded, color: AppTheme.primaryGreen, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              profile.personalGoal!,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: isDark ? AppTheme.primaryText : AppTheme.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 5. Privacy Notice
                  FintechCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock_rounded, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Your personal profile is saved locally in your device's encrypted app storage. No profile data or photos are uploaded to any cloud server.",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {Widget? trailingAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                ?trailingAction,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
    );
  }
}
