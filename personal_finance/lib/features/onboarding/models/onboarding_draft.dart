import 'package:personal_finance/features/accounts/models/account.dart';

class OnboardingDraft {
  // Step 1: Personal Info
  String displayName;
  String? fullName;
  String? nickname;
  String? occupation;
  String countryOrRegion;
  String? ageRange;
  String preferredLanguage;
  String preferredCurrency;
  String? personalGoal;

  // Step 2: Discovery Source
  String? discoverySource;
  String? discoverySourceOther;

  // Step 3: Profile Photo
  String? profileImagePath;

  // Step 4: Accounts
  List<Account> createdAccounts;
  String? selectedMainAccountId;
  String? selectedSavingsAccountId;

  OnboardingDraft({
    this.displayName = '',
    this.fullName,
    this.nickname,
    this.occupation,
    this.countryOrRegion = 'Ethiopia',
    this.ageRange,
    this.preferredLanguage = 'English',
    this.preferredCurrency = 'ETB',
    this.personalGoal,
    this.discoverySource,
    this.discoverySourceOther,
    this.profileImagePath,
    List<Account>? createdAccounts,
    this.selectedMainAccountId,
    this.selectedSavingsAccountId,
  }) : createdAccounts = createdAccounts ?? [];
}
