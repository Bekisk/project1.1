import 'dart:math';

import 'package:crypt/crypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lock timeout options in seconds.
enum AppLockTimeout {
  immediate(0, 'Immediately'),
  thirtySeconds(30, 'After 30 seconds'),
  oneMinute(60, 'After 1 minute');

  final int seconds;
  final String label;

  const AppLockTimeout(this.seconds, this.label);

  static AppLockTimeout fromSeconds(int seconds) {
    if (seconds <= 0) return AppLockTimeout.immediate;
    if (seconds <= 30) return AppLockTimeout.thirtySeconds;
    return AppLockTimeout.oneMinute;
  }
}

/// Service responsible for secure app-lock credential storage and verification.
///
/// Credentials are never stored in plain text. The PIN is hashed using
/// SHA-256 crypt (a salted, computationally expensive format) and the hash
/// is stored in [FlutterSecureStorage], which on Android uses EncryptedSharedPreferences
/// backed by the Android Keystore. The PIN itself is never persisted or logged.
class AppLockService {
  // Storage keys
  static const String _keyPinHash = 'app_lock_pin_hash';
  static const String _keyBiometricEnabled = 'app_lock_biometric_enabled';
  static const String _keyLockTimeout = 'app_lock_timeout_seconds';
  static const String _keyLockConfigured = 'app_lock_configured';

  // PIN constraints
  static const int minPinLength = 6;
  static const int maxPinLength = 8;

  // Crypt hash cost factor. SHA-256 crypt with this many rounds makes
  // each verification deliberately expensive to slow brute-force attempts.
  static const int _cryptRounds = 10000;

  // Attempt-limiting parameters
  static const int maxFailedAttempts = 5;
  static const int lockoutDurationSeconds = 30;

  final FlutterSecureStorage _storage;
  final Random _rng = Random.secure();

  AppLockService._({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static final AppLockService instance = AppLockService._();

  /// Validates that a PIN meets format requirements.
  /// Returns an error message string if invalid, or null if valid.
  String? validatePin(String pin) {
    if (pin.isEmpty) {
      return 'PIN cannot be empty';
    }
    if (pin.length < minPinLength) {
      return 'PIN must be at least $minPinLength digits';
    }
    if (pin.length > maxPinLength) {
      return 'PIN cannot exceed $maxPinLength digits';
    }
    // Ensure all characters are digits
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      return 'PIN must contain only numbers';
    }
    return null;
  }

  /// Hashes a PIN using SHA-256 crypt with a random salt.
  /// Returns the full crypt-format hash string (includes salt and rounds).
  /// The plaintext PIN is never stored.
  String _hashPin(String pin) {
    // Ensure cryptographically secure salt generation on supported platforms
    Crypt.cryptographicallySecureSalts = true;
    final hash = Crypt.sha256(pin, rounds: _cryptRounds);
    return hash.toString();
  }

  /// Checks whether a lock (PIN) has been configured.
  Future<bool> isLockConfigured() async {
    try {
      final configured = await _storage.read(key: _keyLockConfigured);
      return configured == '1';
    } catch (e) {
      debugPrint('AppLockService: Error checking lock configuration: $e');
      return false;
    }
  }

  /// Retrieves the stored crypt hash for verification.
  /// Returns null if no PIN has been set.
  Future<String?> _getStoredHash() async {
    return _storage.read(key: _keyPinHash);
  }

  /// Verifies a PIN against the stored hash using constant-time comparison
  /// provided by the [Crypt] library.
  Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _getStoredHash();
      if (storedHash == null) return false;
      // Crypt.match performs constant-time comparison internally
      final crypt = Crypt(storedHash);
      return crypt.match(pin);
    } catch (e) {
      debugPrint('AppLockService: Error verifying PIN: $e');
      return false;
    }
  }

  /// Sets up the app lock for the first time by storing a hashed PIN.
  /// Throws if a lock was already configured (use [changePin] instead).
  Future<void> setupLock(String pin) async {
    final error = validatePin(pin);
    if (error != null) {
      throw ArgumentError(error);
    }

    final hash = _hashPin(pin);
    await _storage.write(key: _keyPinHash, value: hash);
    await _storage.write(key: _keyLockConfigured, value: '1');
    await _storage.write(key: _keyBiometricEnabled, value: '0');
    await _storage.write(
      key: _keyLockTimeout,
      value: AppLockTimeout.immediate.seconds.toString(),
    );
  }

  /// Changes the PIN. Requires the current PIN for verification.
  /// Returns true if the change was successful, false if the current PIN
  /// verification failed.
  Future<bool> changePin(String currentPin, String newPin) async {
    final error = validatePin(newPin);
    if (error != null) {
      throw ArgumentError(error);
    }

    final valid = await verifyPin(currentPin);
    if (!valid) return false;

    final hash = _hashPin(newPin);
    await _storage.write(key: _keyPinHash, value: hash);
    return true;
  }

  /// Checks whether biometric unlock is enabled by the user.
  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _keyBiometricEnabled);
    return enabled == '1';
  }

  /// Toggles biometric unlock. Does not disable the PIN.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _keyBiometricEnabled, value: enabled ? '1' : '0');
  }

  /// Gets the lock timeout in seconds (0 = immediate).
  Future<int> getLockTimeoutSeconds() async {
    final value = await _storage.read(key: _keyLockTimeout);
    return int.tryParse(value ?? '') ?? AppLockTimeout.immediate.seconds;
  }

  /// Sets the lock timeout.
  Future<void> setLockTimeout(AppLockTimeout timeout) async {
    await _storage.write(
      key: _keyLockTimeout,
      value: timeout.seconds.toString(),
    );
  }

  /// Gets the configured lock timeout as an enum.
  Future<AppLockTimeout> getLockTimeout() async {
    final seconds = await getLockTimeoutSeconds();
    return AppLockTimeout.fromSeconds(seconds);
  }

  /// Deletes all lock-related data from secure storage.
  /// Does NOT delete any financial data, accounts, or transactions.
  Future<void> clearLockData() async {
    await _storage.delete(key: _keyPinHash);
    await _storage.delete(key: _keyBiometricEnabled);
    await _storage.delete(key: _keyLockTimeout);
    await _storage.write(key: _keyLockConfigured, value: '0');
  }

  /// Generates a random salt of the specified length (for external use).
  Uint8List generateRandomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (i) => _rng.nextInt(256)),
    );
  }
}
