import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/profile/models/user_profile.dart';
import 'package:personal_finance/features/profile/services/profile_photo_service.dart';

class UserProfileProvider extends ChangeNotifier {
  final ProfilePhotoService _photoService;
  UserProfile? _profile;
  bool _isLoading = true;
  bool _hasExistingFinancialData = false;

  UserProfileProvider({ProfilePhotoService? photoService})
    : _photoService = photoService ?? ProfilePhotoService();

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isOnboardingCompleted => _profile?.onboardingCompleted ?? false;
  bool get hasProfile => _profile != null;
  bool get hasExistingFinancialData => _hasExistingFinancialData;
  String get displayName => _profile?.displayName.isNotEmpty == true
      ? _profile!.displayName
      : 'Friend';
  String? get profileImagePath => _profile?.profileImagePath;
  String? get mainAccountId => _profile?.mainAccountId;
  String? get designatedSavingsAccountId =>
      _profile?.designatedSavingsAccountId;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Check if user profile exists
      final profileRows = await db.query('user_profiles', limit: 1);
      if (profileRows.isNotEmpty) {
        _profile = UserProfile.fromMap(profileRows.first);
      } else {
        _profile = null;
      }

      // 2. Check if there are existing transactions, budgets, or savings goals
      final txCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM transactions'),
          ) ??
          0;
      final budgetCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM budgets'),
          ) ??
          0;
      final goalsCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM savings_goals'),
          ) ??
          0;

      _hasExistingFinancialData =
          (txCount > 0 || budgetCount > 0 || goalsCount > 0);
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves or updates the user profile persistently in SQLite
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final updatedProfile = profile.copyWith(updatedAt: now);

      await db.insert(
        'user_profiles',
        updatedProfile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _profile = updatedProfile;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }

  /// Sets main account ID
  Future<void> setMainAccountId(String? accountId) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(mainAccountId: accountId);
    await saveProfile(updated);
  }

  /// Sets designated savings account ID
  Future<void> setDesignatedSavingsAccountId(String? accountId) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(designatedSavingsAccountId: accountId);
    await saveProfile(updated);
  }

  /// Updates profile image
  Future<void> updateProfileImage(String newPath) async {
    if (_profile == null) return;
    if (_profile!.profileImagePath != null &&
        _profile!.profileImagePath != newPath) {
      await _photoService.deleteManagedPhoto(_profile!.profileImagePath);
    }
    final updated = _profile!.copyWith(profileImagePath: newPath);
    await saveProfile(updated);
  }

  /// Clears profile image
  Future<void> removeProfileImage() async {
    if (_profile == null) return;
    if (_profile!.profileImagePath != null) {
      await _photoService.deleteManagedPhoto(_profile!.profileImagePath);
    }
    final updated = _profile!.copyWith(clearProfileImage: true);
    await saveProfile(updated);
  }

  /// Resets onboarding status for testing without wiping financial records
  Future<void> resetOnboardingStatus() async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(onboardingCompleted: false);
    await saveProfile(updated);
  }
}
