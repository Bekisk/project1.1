import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:local_auth/local_auth.dart';

/// Service wrapping [LocalAuthentication] to detect biometric hardware
/// and perform native biometric authentication prompts.
///
/// On Android this uses the native BiometricPrompt via the local_auth plugin.
/// No biometric data (images, templates) is ever stored by this app.
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  static final BiometricService instance = BiometricService();

  /// Whether the device has biometric hardware available.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('BiometricService: Error checking biometrics: $e');
      return false;
    }
  }

  /// Whether the device supports any local authentication (biometric or device credential).
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('BiometricService: Error checking device support: $e');
      return false;
    }
  }

  /// Gets the list of enrolled biometric types on the device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService: Error getting available biometrics: $e');
      return [];
    }
  }

  /// Convenience: true when biometric hardware exists AND at least one
  /// biometric is enrolled.
  Future<bool> isBiometricAvailable() async {
    final canCheck = await canCheckBiometrics();
    if (!canCheck) return false;
    final enrolled = await getAvailableBiometrics();
    return enrolled.isNotEmpty;
  }

  /// Returns a human-readable label for the primary enrolled biometric type.
  Future<String> getBiometricLabel() async {
    final types = await getAvailableBiometrics();
    if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.face)) {
      return 'Face';
    }
    if (types.contains(BiometricType.weak)) {
      return 'Face';
    }
    return 'Biometric';
  }

  /// Attempts biometric authentication.
  ///
  /// [reason] is the message shown to the user in the system dialog.
  ///
  /// Returns a result map with:
  /// - `success`: bool
  /// - `error`: String? (user-facing, non-sensitive error message)
  /// - `errorCode`: String? (internal code for error handling)
  Future<Map<String, dynamic>> authenticate(String reason) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );

      return {
        'success': didAuthenticate,
        'error': didAuthenticate ? null : 'Authentication did not complete',
        'errorCode': didAuthenticate ? null : 'cancelled',
      };
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': _userFriendlyError(e),
        'errorCode': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Biometric authentication is not available',
        'errorCode': 'unknown_error',
      };
    }
  }

  /// Maps local_auth exception codes to user-friendly messages.
  /// Never exposes sensitive internals.
  String _userFriendlyError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometrics are not available on this device';
      case 'NotEnrolled':
        return 'No biometrics are enrolled. Use your PIN instead.';
      case 'LockedOut':
        return 'Too many attempts. Please use your PIN.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is disabled. Use your PIN.';
      default:
        return 'Biometric authentication failed. Use your PIN instead.';
    }
  }

  /// Stops/ invalidates any in-progress authentication.
  /// On Android this is a no-op — the system dialog handles cancellation.
  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // No-op: stopAuthentication may not be supported on all platforms
    }
  }
}
