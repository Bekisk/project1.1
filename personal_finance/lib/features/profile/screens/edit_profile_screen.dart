import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/profile/models/user_profile.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/profile/services/profile_photo_service.dart';
import 'package:personal_finance/features/profile/widgets/profile_avatar.dart';
import 'package:personal_finance/features/settings/providers/app_settings_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static Future<void> navigate(BuildContext context) {
    return Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfilePhotoService _photoService = ProfilePhotoService();

  late TextEditingController _displayNameController;
  late TextEditingController _fullNameController;
  late TextEditingController _nicknameController;
  late TextEditingController _goalController;
  late TextEditingController _otherDiscoveryController;

  String? _occupation;
  String? _ageRange;
  String _countryOrRegion = 'Ethiopia';
  String? _discoverySource;
  String? _profileImagePath;
  bool _photoRemoved = false;
  String? _mainAccountId;
  String? _designatedSavingsAccountId;
  String _preferredCurrency = 'ETB';
  String _preferredLanguage = 'English';

  List<Account> _accounts = [];
  bool _isSaving = false;

  final List<String> _occupations = [
    'Student',
    'Employed',
    'Self-employed',
    'Business owner',
    'Freelancer',
    'Other',
    'Prefer not to say',
  ];

  final List<String> _ageRanges = [
    'Under 18',
    '18 - 24',
    '25 - 34',
    '35 - 44',
    '45 - 54',
    '55+',
    'Prefer not to say',
  ];

  final List<String> _discoveryOptions = [
    'Friend or family',
    'TikTok',
    'YouTube',
    'Facebook',
    'Instagram',
    'Telegram',
    'Google search',
    'Website or blog',
    'University or school',
    'Another community',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProfileProvider>().profile;

    _displayNameController = TextEditingController(
      text: profile?.displayName ?? '',
    );
    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _nicknameController = TextEditingController(text: profile?.nickname ?? '');
    _goalController = TextEditingController(text: profile?.personalGoal ?? '');
    _otherDiscoveryController = TextEditingController(
      text: profile?.discoverySourceOther ?? '',
    );

    _occupation = profile?.occupation;
    _ageRange = profile?.ageRange;
    _countryOrRegion = profile?.countryOrRegion ?? 'Ethiopia';
    _discoverySource = profile?.discoverySource;
    _profileImagePath = profile?.profileImagePath;
    _mainAccountId = profile?.mainAccountId;
    _designatedSavingsAccountId = profile?.designatedSavingsAccountId;
    _preferredCurrency = profile?.preferredCurrency ?? 'ETB';
    _preferredLanguage = profile?.preferredLanguage ?? 'English';

    _loadAccounts();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _fullNameController.dispose();
    _nicknameController.dispose();
    _goalController.dispose();
    _otherDiscoveryController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      final accounts = accMaps.map((e) => Account.fromMap(e)).toList();
      if (mounted) {
        setState(() {
          _accounts = accounts;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _pickPhoto() async {
    final path = await _photoService.pickAndSaveProfilePhoto();
    if (path != null && mounted) {
      setState(() {
        _profileImagePath = path;
        _photoRemoved = false;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _profileImagePath = null;
      _photoRemoved = true;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final profileProvider = context.read<UserProfileProvider>();
    final currentProfile = profileProvider.profile;
    final now = DateTime.now();

    try {
      final updatedProfile =
          (currentProfile ??
                  UserProfile(
                    id: 'default',
                    displayName: _displayNameController.text.trim(),
                    createdAt: now,
                    updatedAt: now,
                  ))
              .copyWith(
                displayName: _displayNameController.text.trim(),
                fullName: _fullNameController.text.trim().isNotEmpty
                    ? _fullNameController.text.trim()
                    : null,
                nickname: _nicknameController.text.trim().isNotEmpty
                    ? _nicknameController.text.trim()
                    : null,
                occupation: _occupation,
                ageRange: _ageRange,
                countryOrRegion: _countryOrRegion,
                discoverySource: _discoverySource,
                discoverySourceOther:
                    _discoverySource == 'Other' &&
                        _otherDiscoveryController.text.trim().isNotEmpty
                    ? _otherDiscoveryController.text.trim()
                    : null,
                personalGoal: _goalController.text.trim().isNotEmpty
                    ? _goalController.text.trim()
                    : null,
                profileImagePath: _profileImagePath,
                clearProfileImage: _photoRemoved,
                mainAccountId: _mainAccountId,
                designatedSavingsAccountId: _designatedSavingsAccountId,
                preferredCurrency: _preferredCurrency,
                preferredLanguage: _preferredLanguage,
                updatedAt: now,
              );

      final appSettings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();

      await profileProvider.saveProfile(updatedProfile);

      // Update app currency settings if modified
      final matched = AppCurrency.values.firstWhere(
        (c) => c.code == _preferredCurrency,
        orElse: () => AppCurrency.etb,
      );
      await appSettings.setCurrency(matched);

      // Refresh dashboard
      if (mounted) {
        dashboard.loadDashboardData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
          ),
        ],
      ),
      body: LiquidAtmosphereBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Photo Section
              Center(
                child: Column(
                  children: [
                    ProfileAvatar(
                      imagePath: _profileImagePath,
                      displayName: _displayNameController.text.isNotEmpty
                          ? _displayNameController.text
                          : 'User',
                      radius: 46,
                      showEditBadge: true,
                      onTap: _pickPhoto,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 16),
                          label: Text(
                            _profileImagePath == null
                                ? 'Add Photo'
                                : 'Change Photo',
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_profileImagePath != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _removePhoto,
                            child: const Text(
                              'Remove',
                              style: TextStyle(color: AppTheme.accentCoral),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Basic Identity
              _buildSectionHeader('IDENTITY', isDark),
              FintechCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Display name is required';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: 'Preferred Nickname (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Demographics & Roles
              _buildSectionHeader('PERSONAL & PROFESSIONAL', isDark),
              FintechCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _occupation,
                      decoration: InputDecoration(
                        labelText: 'Occupation (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _occupations.map((occ) {
                        return DropdownMenuItem(value: occ, child: Text(occ));
                      }).toList(),
                      onChanged: (val) => setState(() => _occupation = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _ageRange,
                      decoration: InputDecoration(
                        labelText: 'Age Range (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _ageRanges.map((age) {
                        return DropdownMenuItem(value: age, child: Text(age));
                      }).toList(),
                      onChanged: (val) => setState(() => _ageRange = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _countryOrRegion,
                      decoration: InputDecoration(
                        labelText: 'Country / Region',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Ethiopia',
                          child: Text('Ethiopia'),
                        ),
                        DropdownMenuItem(value: 'Kenya', child: Text('Kenya')),
                        DropdownMenuItem(
                          value: 'United States',
                          child: Text('United States'),
                        ),
                        DropdownMenuItem(
                          value: 'United Kingdom',
                          child: Text('United Kingdom'),
                        ),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _countryOrRegion = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Financial Roles & Preferences
              _buildSectionHeader('ACCOUNT ROLES & CURRENCY', isDark),
              FintechCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _mainAccountId,
                      decoration: InputDecoration(
                        labelText: 'Default / Main Account',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Default primary account'),
                        ),
                        ..._accounts.map((acc) {
                          return DropdownMenuItem<String?>(
                            value: acc.id,
                            child: Text('${acc.name} (${acc.accountType})'),
                          );
                        }),
                      ],
                      onChanged: (val) => setState(() => _mainAccountId = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      value: _designatedSavingsAccountId,
                      decoration: InputDecoration(
                        labelText: 'Designated Savings Account',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None designated'),
                        ),
                        ..._accounts.map((acc) {
                          return DropdownMenuItem<String?>(
                            value: acc.id,
                            child: Text('${acc.name} (${acc.accountType})'),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setState(() => _designatedSavingsAccountId = val),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _preferredCurrency,
                      decoration: InputDecoration(
                        labelText: 'Preferred Currency',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ETB', child: Text('ETB (ብር)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _preferredCurrency = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Discovery Source
              _buildSectionHeader('ACQUISITION SOURCE', isDark),
              FintechCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String?>(
                      value: _discoverySource,
                      decoration: InputDecoration(
                        labelText: 'Where did you hear about us? (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Prefer not to say / Unspecified'),
                        ),
                        ..._discoveryOptions.map((opt) {
                          return DropdownMenuItem<String?>(
                            value: opt,
                            child: Text(opt),
                          );
                        }),
                      ],
                      onChanged: (val) =>
                          setState(() => _discoverySource = val),
                    ),
                    if (_discoverySource == 'Other') ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _otherDiscoveryController,
                        decoration: InputDecoration(
                          labelText: 'Other discovery details',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Financial Goal
              _buildSectionHeader('PRIMARY FINANCIAL GOAL', isDark),
              FintechCard(
                padding: const EdgeInsets.all(16),
                child: TextFormField(
                  controller: _goalController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Personal Financial Goal (Optional)',
                    hintText: 'e.g. Save for a house, emergency fund',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
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
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
