class UserProfile {
  final String id;
  final String displayName;
  final String? fullName;
  final String? nickname;
  final String? occupation;
  final String? countryOrRegion;
  final String? ageRange;
  final String? profileImagePath;
  final String? discoverySource;
  final String? discoverySourceOther;
  final String? personalGoal;
  final String preferredLanguage;
  final String preferredCurrency;
  final String? mainAccountId;
  final String? designatedSavingsAccountId;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.displayName,
    this.fullName,
    this.nickname,
    this.occupation,
    this.countryOrRegion = 'Ethiopia',
    this.ageRange,
    this.profileImagePath,
    this.discoverySource,
    this.discoverySourceOther,
    this.personalGoal,
    this.preferredLanguage = 'English',
    this.preferredCurrency = 'ETB',
    this.mainAccountId,
    this.designatedSavingsAccountId,
    this.onboardingCompleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'full_name': fullName,
      'nickname': nickname,
      'occupation': occupation,
      'country_or_region': countryOrRegion,
      'age_range': ageRange,
      'profile_image_path': profileImagePath,
      'discovery_source': discoverySource,
      'discovery_source_other': discoverySourceOther,
      'personal_goal': personalGoal,
      'preferred_language': preferredLanguage,
      'preferred_currency': preferredCurrency,
      'main_account_id': mainAccountId,
      'designated_savings_account_id': designatedSavingsAccountId,
      'onboarding_completed': onboardingCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String? ?? '',
      fullName: map['full_name'] as String?,
      nickname: map['nickname'] as String?,
      occupation: map['occupation'] as String?,
      countryOrRegion: map['country_or_region'] as String? ?? 'Ethiopia',
      ageRange: map['age_range'] as String?,
      profileImagePath: map['profile_image_path'] as String?,
      discoverySource: map['discovery_source'] as String?,
      discoverySourceOther: map['discovery_source_other'] as String?,
      personalGoal: map['personal_goal'] as String?,
      preferredLanguage: map['preferred_language'] as String? ?? 'English',
      preferredCurrency: map['preferred_currency'] as String? ?? 'ETB',
      mainAccountId: map['main_account_id'] as String?,
      designatedSavingsAccountId:
          map['designated_savings_account_id'] as String?,
      onboardingCompleted: (map['onboarding_completed'] as int? ?? 0) == 1,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? fullName,
    String? nickname,
    String? occupation,
    String? countryOrRegion,
    String? ageRange,
    String? profileImagePath,
    bool clearProfileImage = false,
    String? discoverySource,
    String? discoverySourceOther,
    String? personalGoal,
    String? preferredLanguage,
    String? preferredCurrency,
    String? mainAccountId,
    String? designatedSavingsAccountId,
    bool? onboardingCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      occupation: occupation ?? this.occupation,
      countryOrRegion: countryOrRegion ?? this.countryOrRegion,
      ageRange: ageRange ?? this.ageRange,
      profileImagePath: clearProfileImage
          ? null
          : (profileImagePath ?? this.profileImagePath),
      discoverySource: discoverySource ?? this.discoverySource,
      discoverySourceOther: discoverySourceOther ?? this.discoverySourceOther,
      personalGoal: personalGoal ?? this.personalGoal,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      mainAccountId: mainAccountId ?? this.mainAccountId,
      designatedSavingsAccountId:
          designatedSavingsAccountId ?? this.designatedSavingsAccountId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
