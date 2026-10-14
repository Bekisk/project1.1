import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/onboarding/models/onboarding_draft.dart';
import 'package:personal_finance/features/profile/models/user_profile.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/profile/services/profile_photo_service.dart';
import 'package:personal_finance/features/profile/widgets/profile_avatar.dart';
import 'package:personal_finance/features/settings/providers/app_settings_provider.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 7;

  late final OnboardingDraft _draft;
  final ProfilePhotoService _photoService = ProfilePhotoService();

  // Controllers for Step 1: Personal Info
  final _personalFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _goalController = TextEditingController();

  // Controller for Step 2: Discovery Source other
  final _otherDiscoveryController = TextEditingController();

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
    _draft = OnboardingDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _nicknameController.dispose();
    _goalController.dispose();
    _otherDiscoveryController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showAddAccountDialog({Account? accountToEdit}) {
    final nameCtrl = TextEditingController(text: accountToEdit?.name ?? '');
    final openingCtrl = TextEditingController(
      text: accountToEdit != null ? (accountToEdit.openingBalance / 100.0).toStringAsFixed(2) : '0.00',
    );
    String selectedType = accountToEdit?.accountType ?? 'bank';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(accountToEdit == null ? 'Add Financial Account' : 'Edit Account'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Account Name *',
                        hintText: 'e.g. Commercial Bank of Ethiopia, Telebirr',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter account name' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bank', child: Text('Bank Account (CBE, Awash, etc.)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'savings', child: Text('Savings Account', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money (Telebirr, CBE Birr)', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'cash', child: Text('Cash or Wallet', overflow: TextOverflow.ellipsis)),
                        DropdownMenuItem(value: 'other', child: Text('Other Account', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: openingCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Opening Balance (ETB)',
                        hintText: '0.00',
                        helperText: 'Current available balance. This is NOT counted as income.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final rawAmount = double.tryParse(openingCtrl.text.trim()) ?? 0.0;
                  final cents = (rawAmount * 100).round();
                  final now = DateTime.now();

                  setState(() {
                    if (accountToEdit == null) {
                      final newAcc = Account(
                        id: const Uuid().v4(),
                        name: nameCtrl.text.trim(),
                        accountType: selectedType,
                        openingBalance: cents,
                        createdAt: now,
                        updatedAt: now,
                      );
                      _draft.createdAccounts.add(newAcc);
                      if (_draft.createdAccounts.length == 1) {
                        _draft.selectedMainAccountId = newAcc.id;
                      }
                      if (selectedType == 'savings' && _draft.selectedSavingsAccountId == null) {
                        _draft.selectedSavingsAccountId = newAcc.id;
                      }
                    } else {
                      final idx = _draft.createdAccounts.indexWhere((a) => a.id == accountToEdit.id);
                      if (idx != -1) {
                        _draft.createdAccounts[idx] = accountToEdit.copyWith(
                          name: nameCtrl.text.trim(),
                          accountType: selectedType,
                          openingBalance: cents,
                          updatedAt: now,
                        );
                      }
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final path = await _photoService.pickAndSaveProfilePhoto();
    if (path != null && mounted) {
      setState(() {
        _draft.profileImagePath = path;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;

    if (_draft.displayName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name is required. Please review Step 2.')),
      );
      _pageController.jumpToPage(1);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // 1. If user created accounts in onboarding, insert them into DB
      if (_draft.createdAccounts.isNotEmpty) {
        // If there was an existing default cash wallet with 0 balance and 0 txs, archive or keep it
        for (final acc in _draft.createdAccounts) {
          await db.insert('accounts', acc.toMap());
        }
      } else {
        // If user didn't create any account, fetch existing active accounts or seed one
        final activeAccs = await db.query('accounts', where: 'is_archived = 0');
        if (activeAccs.isNotEmpty) {
          _draft.selectedMainAccountId ??= activeAccs.first['id'] as String;
        } else {
          final defaultAcc = Account(
            id: const Uuid().v4(),
            name: 'Main Wallet',
            accountType: 'cash',
            openingBalance: 0,
            createdAt: now,
            updatedAt: now,
          );
          await db.insert('accounts', defaultAcc.toMap());
          _draft.selectedMainAccountId = defaultAcc.id;
        }
      }

      if (!mounted) return;
      final profileProvider = context.read<UserProfileProvider>();
      final settings = context.read<AppSettingsProvider>();
      final dashboard = context.read<DashboardProvider>();
      final transactions = context.read<TransactionsProvider>();

      // 2. Build UserProfile
      final profileId = const Uuid().v4();
      final profile = UserProfile(
        id: profileId,
        displayName: _draft.displayName.trim(),
        fullName: _draft.fullName?.trim().isNotEmpty == true ? _draft.fullName!.trim() : null,
        nickname: _draft.nickname?.trim().isNotEmpty == true ? _draft.nickname!.trim() : null,
        occupation: _draft.occupation,
        countryOrRegion: _draft.countryOrRegion,
        ageRange: _draft.ageRange,
        profileImagePath: _draft.profileImagePath,
        discoverySource: _draft.discoverySource,
        discoverySourceOther: _draft.discoverySourceOther?.trim().isNotEmpty == true
            ? _draft.discoverySourceOther!.trim()
            : null,
        personalGoal: _draft.personalGoal?.trim().isNotEmpty == true ? _draft.personalGoal!.trim() : null,
        preferredLanguage: _draft.preferredLanguage,
        preferredCurrency: _draft.preferredCurrency,
        mainAccountId: _draft.selectedMainAccountId,
        designatedSavingsAccountId: _draft.selectedSavingsAccountId,
        onboardingCompleted: true,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Save profile to DB and update UserProfileProvider
      await profileProvider.saveProfile(profile);

      // 4. Update currency in AppSettingsProvider if user selected a different currency
      final matchedCurrency = AppCurrency.values.firstWhere(
        (c) => c.code == _draft.preferredCurrency,
        orElse: () => AppCurrency.etb,
      );
      await settings.setCurrency(matchedCurrency);

      // 5. Reload dashboard and transactions providers
      if (mounted) {
        dashboard.loadDashboardData();
        transactions.loadTransactions();
      }

      // 6. Navigate to dashboard
      widget.onOnboardingComplete();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete onboarding: $e'),
            backgroundColor: AppTheme.expenseRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Progress bar
              _buildProgressHeader(isDark),

              // PageView for onboarding steps
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // explicit buttons
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    _buildWelcomeStep(isDark),
                    _buildPersonalInfoStep(isDark),
                    _buildDiscoveryStep(isDark),
                    _buildAccountSetupStep(isDark),
                    _buildAccountSelectionStep(isDark),
                    _buildProfilePhotoAndPreferencesStep(isDark),
                    _buildReviewAndFinishStep(isDark),
                  ],
                ),
              ),

              // Bottom Navigation Controls
              _buildBottomControls(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // --- TOP PROGRESS HEADER ---
  Widget _buildProgressHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.primaryAccent : AppTheme.primaryGreen,
                ),
              ),
              Text(
                _stepTitleSummary(_currentStep),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppTheme.primaryAccent : AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stepTitleSummary(int step) {
    switch (step) {
      case 0:
        return 'Welcome';
      case 1:
        return 'Personal Info';
      case 2:
        return 'Discovery';
      case 3:
        return 'Accounts';
      case 4:
        return 'Roles';
      case 5:
        return 'Preferences & Photo';
      case 6:
        return 'Review & Finish';
      default:
        return '';
    }
  }

  // --- BOTTOM BUTTON CONTROLS ---
  Widget _buildBottomControls(bool isDark) {
    final canGoBack = _currentStep > 0;
    final isLastStep = _currentStep == _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.cardCharcoal : Colors.white).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (canGoBack) ...[
            OutlinedButton(
              onPressed: _isSaving ? null : _prevPage,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_currentStep == 1) {
                        if (!_personalFormKey.currentState!.validate()) return;
                        _draft.displayName = _nameController.text.trim();
                        _draft.fullName = _fullNameController.text.trim();
                        _draft.nickname = _nicknameController.text.trim();
                        _draft.personalGoal = _goalController.text.trim();
                      } else if (_currentStep == 2) {
                        if (_draft.discoverySource == 'Other') {
                          _draft.discoverySourceOther = _otherDiscoveryController.text.trim();
                        }
                      }
                      if (isLastStep) {
                        _completeOnboarding();
                      } else {
                        _nextPage();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      isLastStep ? 'Finish Setup' : 'Continue',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 1: WELCOME
  // ==========================================
  Widget _buildWelcomeStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isDark ? AppTheme.walletHeroGradient : null,
              color: isDark ? null : const Color(0xFFD1EBE3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryAccent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryGreen, size: 44),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Welcome to your financial journey',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            "Let's personalize your experience and set up your finances so you can understand your money, manage your spending, and reach your savings goals.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 36),
          FintechCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _buildFeatureBullet(
                  Icons.shield_rounded,
                  '100% Offline & Private',
                  'Your data stays securely on your device SQLite database. No external tracking.',
                  isDark,
                ),
                const SizedBox(height: 14),
                _buildFeatureBullet(
                  Icons.savings_rounded,
                  'Disciplined Goals & Budgets',
                  'Plan your spending, track milestones, and protect your savings.',
                  isDark,
                ),
                const SizedBox(height: 14),
                _buildFeatureBullet(
                  Icons.account_tree_rounded,
                  'Multi-Wallet Accounting',
                  'Seamlessly manage cash, CBE, Telebirr, and savings accounts in ETB.',
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String title, String subtitle, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: PERSONAL INFORMATION
  // ==========================================
  Widget _buildPersonalInfoStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Form(
        key: _personalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
            ),
            const SizedBox(height: 6),
            Text(
              'Tell us how you would like to be addressed. Required fields are clearly marked.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),

            // Display Name (Required)
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Display Name *',
                hintText: 'e.g. Bereket or Alexander',
                helperText: 'Shown on your dashboard greeting and cards',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Display name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Full Name (Optional)
            TextFormField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name (Optional)',
                hintText: 'e.g. Bereket Tadesse',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            // Nickname (Optional)
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: 'Preferred Nickname (Optional)',
                hintText: 'e.g. Beki',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),

            // Occupation (Optional)
            DropdownButtonFormField<String>(
              value: _draft.occupation,
              decoration: InputDecoration(
                labelText: 'Occupation (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _occupations.map((occ) {
                return DropdownMenuItem(value: occ, child: Text(occ));
              }).toList(),
              onChanged: (val) => setState(() => _draft.occupation = val),
            ),
            const SizedBox(height: 16),

            // Age Range (Optional)
            DropdownButtonFormField<String>(
              value: _draft.ageRange,
              decoration: InputDecoration(
                labelText: 'Age Range (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: _ageRanges.map((age) {
                return DropdownMenuItem(value: age, child: Text(age));
              }).toList(),
              onChanged: (val) => setState(() => _draft.ageRange = val),
            ),
            const SizedBox(height: 16),

            // Country/Region (Defaults to Ethiopia)
            DropdownButtonFormField<String>(
              value: _draft.countryOrRegion,
              decoration: InputDecoration(
                labelText: 'Country / Region',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: const [
                DropdownMenuItem(value: 'Ethiopia', child: Text('Ethiopia')),
                DropdownMenuItem(value: 'Kenya', child: Text('Kenya')),
                DropdownMenuItem(value: 'United States', child: Text('United States')),
                DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _draft.countryOrRegion = val);
              },
            ),
            const SizedBox(height: 16),

            // Personal Financial Goal or Purpose (Optional)
            TextFormField(
              controller: _goalController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Primary Financial Goal (Optional)',
                hintText: 'e.g. Save for a house, track daily living expenses',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: DISCOVERY SOURCE
  // ==========================================
  Widget _buildDiscoveryStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where did you hear about us?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Help us understand how people discover the app. This is completely optional.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _discoveryOptions.map((opt) {
              final isSelected = _draft.discoverySource == opt;
              return ChoiceChip(
                label: Text(opt),
                selected: isSelected,
                selectedColor: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.35 : 0.2),
                labelStyle: TextStyle(
                  color: isSelected
                      ? (isDark ? AppTheme.primaryAccent : AppTheme.primaryGreen)
                      : (isDark ? AppTheme.primaryText : AppTheme.textDark),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? (isDark ? AppTheme.primaryGreen : AppTheme.primaryGreen)
                        : (isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0)),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    _draft.discoverySource = selected ? opt : null;
                  });
                },
              );
            }).toList(),
          ),

          if (_draft.discoverySource == 'Other') ...[
            const SizedBox(height: 20),
            TextField(
              controller: _otherDiscoveryController,
              decoration: InputDecoration(
                labelText: 'Please specify (Optional)',
                hintText: 'e.g. Word of mouth, Tech event',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 4: FINANCIAL ACCOUNT SETUP
  // ==========================================
  Widget _buildAccountSetupStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Let's organize your money",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the accounts you use to receive income, pay expenses, and save money. Enter the amount currently available in each account as its opening balance.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          // Add Account Button
          OutlinedButton.icon(
            onPressed: () => _showAddAccountDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Account / Wallet'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 16),

          if (_draft.createdAccounts.isEmpty) ...[
            FintechCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.account_balance_outlined, size: 40, color: isDark ? Colors.white38 : Colors.grey),
                  const SizedBox(height: 10),
                  const Text(
                    'No accounts added yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can add your CBE Bank, Telebirr, or Cash wallet now, or a default wallet will be prepared for you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ..._draft.createdAccounts.map((acc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FintechCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_iconForAccountType(acc.accountType), color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                              acc.accountType.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.formatCents(acc.openingBalance),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Opening Balance',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentCoral),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _draft.createdAccounts.removeWhere((a) => a.id == acc.id);
                            if (_draft.selectedMainAccountId == acc.id) {
                              _draft.selectedMainAccountId =
                                  _draft.createdAccounts.isNotEmpty ? _draft.createdAccounts.first.id : null;
                            }
                            if (_draft.selectedSavingsAccountId == acc.id) {
                              _draft.selectedSavingsAccountId = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 5: SELECT MAIN & SAVINGS ACCOUNTS
  // ==========================================
  Widget _buildAccountSelectionStep(bool isDark) {
    final accounts = _draft.createdAccounts;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Which account do you use most often?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your main account to be used as default for new transactions.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          if (accounts.isEmpty) ...[
            FintechCard(
              padding: const EdgeInsets.all(16),
              child: const Text('Add at least one account in Step 4 to select your main and savings accounts.'),
            ),
          ] else ...[
            // Main account selection
            ...accounts.map((acc) {
              final isMain = _draft.selectedMainAccountId == acc.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _draft.selectedMainAccountId = acc.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMain
                            ? (isDark ? AppTheme.primaryGreen : AppTheme.primaryGreen)
                            : (isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0)),
                        width: isMain ? 2 : 1,
                      ),
                      color: isMain
                          ? (isDark ? AppTheme.primaryGreen.withValues(alpha: 0.15) : const Color(0xFFE8F5E9))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMain ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: isMain ? AppTheme.primaryGreen : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                acc.accountType.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCents(acc.openingBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            const Text(
              'Do you have a separate savings account?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),
            Text(
              'Designate an account for your savings deposits (Optional).',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String?>(
              value: _draft.selectedSavingsAccountId,
              decoration: InputDecoration(
                labelText: 'Designated Savings Account',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None / Decide later'),
                ),
                ...accounts.map((acc) {
                  return DropdownMenuItem<String?>(
                    value: acc.id,
                    child: Text('${acc.name} (${CurrencyFormatter.formatCents(acc.openingBalance)})'),
                  );
                }),
              ],
              onChanged: (val) => setState(() => _draft.selectedSavingsAccountId = val),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 6: PROFILE PHOTO & PREFERENCES
  // ==========================================
  Widget _buildProfilePhotoAndPreferencesStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Photo & Preferences',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Personalize your visual profile. Adding a photo is completely optional.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 24),

          // Photo Selector
          Center(
            child: Column(
              children: [
                ProfileAvatar(
                  imagePath: _draft.profileImagePath,
                  displayName: _draft.displayName.isNotEmpty ? _draft.displayName : 'User',
                  radius: 46,
                  showEditBadge: true,
                  onTap: _pickPhoto,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(_draft.profileImagePath == null ? 'Choose Photo' : 'Change Photo'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (_draft.profileImagePath != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _draft.profileImagePath = null),
                        child: const Text('Remove', style: TextStyle(color: AppTheme.accentCoral)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Currency Preference
          DropdownButtonFormField<String>(
            value: _draft.preferredCurrency,
            decoration: InputDecoration(
              labelText: 'Display Currency',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [
              DropdownMenuItem(value: 'ETB', child: Text('Ethiopian Birr (ETB - ብር)')),
              DropdownMenuItem(value: 'USD', child: Text('US Dollar (USD - \$)')),
              DropdownMenuItem(value: 'EUR', child: Text('Euro (EUR - €)')),
              DropdownMenuItem(value: 'GBP', child: Text('British Pound (GBP - £)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _draft.preferredCurrency = val);
            },
          ),
          const SizedBox(height: 16),

          // Language Preference
          DropdownButtonFormField<String>(
            value: _draft.preferredLanguage,
            decoration: InputDecoration(
              labelText: 'Preferred Language',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: const [
              DropdownMenuItem(value: 'English', child: Text('English')),
              DropdownMenuItem(value: 'Amharic', child: Text('Amharic (አማርኛ)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _draft.preferredLanguage = val);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 7: REVIEW AND FINISH
  // ==========================================
  Widget _buildReviewAndFinishStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to start your journey!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Please review your details before finishing setup. You can always edit these in Settings.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          // User Card
          FintechCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ProfileAvatar(
                  imagePath: _draft.profileImagePath,
                  displayName: _draft.displayName.isNotEmpty ? _draft.displayName : 'User',
                  radius: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _draft.displayName.isNotEmpty ? _draft.displayName : 'No name provided',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (_draft.occupation != null)
                        Text(
                          _draft.occupation!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                          ),
                        ),
                      Text(
                        '${_draft.countryOrRegion} • ${_draft.preferredCurrency}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _pageController.jumpToPage(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Account summary
          FintechCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Configured Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    TextButton(
                      onPressed: () => _pageController.jumpToPage(3),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text('Edit Accounts'),
                    ),
                  ],
                ),
                const Divider(),
                if (_draft.createdAccounts.isEmpty)
                  const Text('Default Cash Wallet will be created for you.')
                else
                  ..._draft.createdAccounts.map((acc) {
                    final isMain = acc.id == _draft.selectedMainAccountId;
                    final isSavings = acc.id == _draft.selectedSavingsAccountId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMain) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('MAIN',
                                        style: TextStyle(
                                            fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                  ),
                                ],
                                if (isSavings) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.transferBlue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('SAVINGS',
                                        style: TextStyle(
                                            fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.transferBlue)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatCents(acc.openingBalance),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Privacy note
          FintechCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.privacy_tip_outlined, size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Your profile and financial information are stored on this device using the app's configured local storage. This does not create an online account or synchronize your information to the cloud.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? AppTheme.secondaryText : AppTheme.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _iconForAccountType(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'mobile_money':
        return Icons.phone_android_rounded;
      default:
        return Icons.payments_rounded;
    }
  }
}
