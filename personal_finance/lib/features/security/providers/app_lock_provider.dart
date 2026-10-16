import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:personal_finance/features/security/services/app_lock_service.dart';
import 'package:personal_finance/features/security/services/biometric_service.dart';

/// Result types for biometric authentication attempts.
enum BiometricAuthResult {
  success,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
}

/// Channel for toggling Android FLAG_SECURE (screenshot protection).
const _secureChannel = MethodChannel('com.beki.personal_finance/secure');

/// Central source of truth for app-lock authentication state.
///
/// Responsibilities:
/// - Tracks whether a PIN has been configured and whether the app is unlocked.
/// - Detects device biometric availability and the user's biometric preference.
/// - Hooks into [WidgetsBindingObserver] to re-lock the app when it is
///   backgrounded for longer than the configured timeout.
/// - Toggles Android FLAG_SECURE to prevent screenshots when locked.
/// - Holds a pending notification payload for delivery after unlock.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AppLockService _lockService;
  final BiometricService _biometricService;

  AppLockProvider({
    AppLockService? lockService,
    BiometricService? biometricService,
  }) : _lockService = lockService ?? AppLockService.instance,
       _biometricService = biometricService ?? BiometricService.instance;

  bool _isInitialized = false;
  bool _isLockConfigured = false;
  bool _isUnlocked = false;

  // Biometric
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricLabel = 'Biometric';

  // Lifecycle / relocking
  DateTime? _pausedAt;
  DateTime? _lockoutStartTime;
  int _failedAttempts = 0;
  Timer? _lockoutTimer;
  bool _isLockedOut = false;

  // Pending navigation from notification/deep-link taps that arrived while locked
  String? _pendingNotificationPayload;

  // ── Public getters ──────────────────────────────────────────────

  bool get isInitialized => _isInitialized;
  bool get isLockConfigured => _isLockConfigured;
  bool get isUnlocked => _isUnlocked;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String get biometricLabel => _biometricLabel;
  int get failedAttempts => _failedAttempts;
  bool get isLockedOut => _isLockedOut;

  /// Remaining lockout duration. Zero when not in lockout.
  Duration get lockoutTimeRemaining {
    if (!_isLockedOut || _lockoutStartTime == null) {
      return Duration.zero;
    }
    final remaining =
        Duration(seconds: AppLockService.lockoutDurationSeconds) -
        DateTime.now().difference(_lockoutStartTime!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether a pending notification payload exists that should be delivered
  /// after the next successful unlock.
  String? get pendingNotificationPayload => _pendingNotificationPayload;

  /// Clears the pending notification payload (called after navigating).
  void clearPendingNotificationPayload() {
    _pendingNotificationPayload = null;
    notifyListeners();
  }

  /// Sets a pending notification payload (called when a notification is
  /// tapped while the app is locked).
  void setPendingNotificationPayload(String? payload) {
    _pendingNotificationPayload = payload;
    notifyListeners();
  }

  // ── Initialization ──────────────────────────────────────────────

  /// Must be called once after creation. Registers lifecycle observer and
  /// reads persisted lock settings.
  Future<void> init() async {
    if (_isInitialized) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addObserver(this);
    });

    _isLockConfigured = await _lockService.isLockConfigured();

    if (_isLockConfigured) {
      _biometricEnabled = await _lockService.isBiometricEnabled();
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      _biometricLabel = _biometricAvailable
          ? await _biometricService.getBiometricLabel()
          : 'Biometric';
    }

    // Start with the screen secured (locked) until explicitly unlocked.
    await _setSecureScreen(true);

    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockoutTimer?.cancel();
    super.dispose();
  }

  // ── Lock state management ───────────────────────────────────────

  /// Stores the PIN via the service and calls [onSetupComplete].
  /// Called by the setup screen after PIN confirmation.
  Future<void> setupLock(String pin) async {
    await _lockService.setupLock(pin);
    await onSetupComplete();
  }

  /// Completes first-time PIN setup. Called by the setup screen after the
  /// PIN has been stored in secure storage.
  Future<void> onSetupComplete() async {
    _isLockConfigured = true;
    _isUnlocked = true;
    _biometricAvailable = await _biometricService.isBiometricAvailable();
    _biometricLabel = _biometricAvailable
        ? await _biometricService.getBiometricLabel()
        : 'Biometric';
    await _setSecureScreen(false);
    notifyListeners();
  }

  /// Enables/disables biometric unlock. Does NOT disable PIN.
  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _lockService.setBiometricEnabled(enabled);
    notifyListeners();
  }

  /// Refreshes biometric availability and preference from storage/services.
  /// Call this when returning to the Settings screen.
  Future<void> refreshBiometricSettings() async {
    _biometricEnabled = await _lockService.isBiometricEnabled();
    _biometricAvailable = await _biometricService.isBiometricAvailable();
    _biometricLabel = _biometricAvailable
        ? await _biometricService.getBiometricLabel()
        : 'Biometric';
    notifyListeners();
  }

  /// Unlocks the app. Called after successful PIN or biometric verification.
  void unlock() {
    _isUnlocked = true;
    _failedAttempts = 0;
    _isLockedOut = false;
    _lockoutStartTime = null;
    _lockoutTimer?.cancel();
    _pausedAt = null;
    _setSecureScreen(false);
    notifyListeners();
  }

  /// Locks the app immediately (e.g., from a "Lock now" action in Settings).
  void lock() {
    _isUnlocked = false;
    _failedAttempts = 0;
    _isLockedOut = false;
    _lockoutStartTime = null;
    _lockoutTimer?.cancel();
    _pausedAt = null;
    _setSecureScreen(true);
    notifyListeners();
  }

  /// Records a failed PIN attempt and enforces lockout if the threshold
  /// is exceeded.
  void recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= AppLockService.maxFailedAttempts) {
      _isLockedOut = true;
      _lockoutStartTime = DateTime.now();
      _lockoutTimer = Timer(
        const Duration(seconds: AppLockService.lockoutDurationSeconds),
        () {
          _isLockedOut = false;
          _lockoutStartTime = null;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  bool _isBiometricPromptActive = false;

  // ── Biometric authentication ────────────────────────────────────

  /// Attempts biometric authentication. On success, unlocks the app.
  /// Returns a [BiometricAuthResult] describing the outcome.
  Future<BiometricAuthResult> authenticateWithBiometrics() async {
    if (!_biometricAvailable || !_biometricEnabled) {
      return BiometricAuthResult.notAvailable;
    }

    _isBiometricPromptActive = true;
    try {
      final result = await _biometricService.authenticate(
        'Unlock "My Finance" with your biometrics',
      );

      if (result['success'] == true) {
        unlock();
        return BiometricAuthResult.success;
      }

      final errorCode = result['errorCode'] as String?;
      return switch (errorCode) {
        'notAvailable' => BiometricAuthResult.notAvailable,
        'notEnrolled' => BiometricAuthResult.notEnrolled,
        'lockedOut' => BiometricAuthResult.lockedOut,
        'permanentlyLockedOut' => BiometricAuthResult.permanentlyLockedOut,
        _ => BiometricAuthResult.notAvailable,
      };
    } finally {
      _isBiometricPromptActive = false;
    }
  }

  // ── App lifecycle relocking ─────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // If native biometric prompt is active, Android may pause the activity temporarily.
      // Do not treat this as backgrounding the app away from the user.
      if (_isBiometricPromptActive) return;
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_isBiometricPromptActive) return;
      // App returned to foreground — check if the timeout has elapsed.
      if (!_isUnlocked) return;
      if (_isLockedOut) return;

      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        _checkTimeoutLock(elapsed);
      }
    }
  }

  /// Re-locks the app if the backgrounded duration exceeds the timeout.
  Future<void> _checkTimeoutLock(Duration elapsed) async {
    final timeoutSeconds = await _lockService.getLockTimeoutSeconds();
    if (timeoutSeconds == 0 || elapsed.inSeconds >= timeoutSeconds) {
      _isUnlocked = false;
      _pausedAt = null;
      await _setSecureScreen(true);
      notifyListeners();
    }
  }

  // ── Android FLAG_SECURE (screenshot protection) ─────────────────

  /// Enables or disables FLAG_SECURE on the Android window to prevent
  /// screenshots and screen recording. No-op on non-Android platforms.
  Future<void> _setSecureScreen(bool secure) async {
    try {
      await _secureChannel.invokeMethod('setSecureScreen', {'secure': secure});
    } on PlatformException catch (e) {
      // Non-critical: secure screen may not be available in test/emulator
      debugPrint('AppLockProvider: Could not toggle secure screen: $e');
    } on MissingPluginException {
      // Plugin not registered (e.g., in tests) — silently ignore.
    }
  }

  /// Convenience getter for the lock timeout.
  Future<AppLockTimeout> getLockTimeout() => _lockService.getLockTimeout();

  /// Convenience setter for the lock timeout.
  Future<void> setLockTimeout(AppLockTimeout timeout) =>
      _lockService.setLockTimeout(timeout);

  /// Convenience: verify PIN through the service layer.
  Future<bool> verifyPin(String pin) => _lockService.verifyPin(pin);

  /// Convenience: validate PIN format.
  String? validatePin(String pin) => _lockService.validatePin(pin);

  /// Convenience: check biometric availability (device hardware + enrollment).
  Future<bool> checkBiometricAvailable() =>
      _biometricService.isBiometricAvailable();

  /// Changes the PIN after verifying the current PIN.
  /// Returns true if successful, false if the current PIN was invalid.
  Future<bool> changePin(String currentPin, String newPin) async {
    final success = await _lockService.changePin(currentPin, newPin);
    return success;
  }

  /// Disables app lock entirely — deletes all lock data from secure storage.
  Future<void> disableLock() async {
    await _lockService.clearLockData();
    _isLockConfigured = false;
    _isUnlocked = true;
    _biometricEnabled = false;
    _isLockedOut = false;
    _lockoutStartTime = null;
    _lockoutTimer?.cancel();
    await _setSecureScreen(false);
    notifyListeners();
  }

  /// Manually locks the app (e.g., from a "Lock now" button in Settings).
  void lockNow() {
    if (_isLockConfigured) {
      lock();
    }
  }
}
