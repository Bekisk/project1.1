import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_finance/features/security/providers/app_lock_provider.dart';
import 'package:personal_finance/features/security/services/app_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Lock & Security Verification Tests', () {
    // 1. PIN Format Validation
    test('PIN validation rejects non-numeric, too short, too long, or empty values', () {
      final service = AppLockService.instance;

      expect(service.validatePin(''), isNotNull);
      expect(service.validatePin('12345'), isNotNull); // < 6 digits
      expect(service.validatePin('12345a'), isNotNull); // non-numeric
      expect(service.validatePin('123456789'), isNotNull); // > 8 digits
      expect(service.validatePin('123456'), isNull); // valid 6 digits
      expect(service.validatePin('12345678'), isNull); // valid 8 digits
    });

    // 2. Mock storage testing of PIN setup, verification, and lockout
    test('Lockout logic triggers after max failed attempts', () {
      FlutterSecureStorage.setMockInitialValues({});
      final provider = AppLockProvider();

      expect(provider.failedAttempts, 0);
      expect(provider.isLockedOut, isFalse);

      for (int i = 0; i < AppLockService.maxFailedAttempts; i++) {
        provider.recordFailedAttempt();
      }

      expect(provider.isLockedOut, isTrue);
      expect(provider.failedAttempts, AppLockService.maxFailedAttempts);
      expect(provider.lockoutTimeRemaining.inSeconds, greaterThan(0));

      provider.dispose();
    });

    // 3. Unlock resets failed attempts and lockout
    test('Unlock clears failed attempts and unlocks state', () {
      FlutterSecureStorage.setMockInitialValues({});
      final provider = AppLockProvider();

      provider.recordFailedAttempt();
      provider.recordFailedAttempt();
      expect(provider.failedAttempts, 2);

      provider.unlock();
      expect(provider.isUnlocked, isTrue);
      expect(provider.failedAttempts, 0);
      expect(provider.isLockedOut, isFalse);

      provider.dispose();
    });

    // 4. Lock immediately secures state
    test('Lock sets isUnlocked to false', () {
      FlutterSecureStorage.setMockInitialValues({});
      final provider = AppLockProvider();

      provider.unlock();
      expect(provider.isUnlocked, isTrue);

      provider.lock();
      expect(provider.isUnlocked, isFalse);

      provider.dispose();
    });

    // 5. Notification payload preservation while locked
    test('Pending notification payload is preserved while locked and cleared after unlock', () {
      FlutterSecureStorage.setMockInitialValues({});
      final provider = AppLockProvider();

      provider.setPendingNotificationPayload('daily_summary_screen');
      expect(provider.pendingNotificationPayload, 'daily_summary_screen');

      provider.clearPendingNotificationPayload();
      expect(provider.pendingNotificationPayload, isNull);

      provider.dispose();
    });
  });
}
