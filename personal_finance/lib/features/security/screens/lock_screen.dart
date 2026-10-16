import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/notifications/screens/daily_summary_screen.dart';
import 'package:personal_finance/features/security/providers/app_lock_provider.dart';
import 'package:personal_finance/features/security/widgets/pin_input_field.dart';
import 'package:personal_finance/features/sms_parser/screens/sms_review_queue_screen.dart';

/// Lock screen shown when the app is in the locked state.
///
/// Allows the user to:
/// - Enter their 6-digit PIN to unlock
/// - Use biometric authentication (if enabled)
/// - Shows a lockout timer when too many attempts have been made
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LockScreen()));
  }

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _pinInputKey = GlobalKey<PinInputFieldState>();
  String? _errorText;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lockProvider = context.read<AppLockProvider>();
      if (lockProvider.biometricEnabled && lockProvider.biometricAvailable) {
        _authenticateWithBiometrics();
      }
    });
  }

  void _onPinCompleted(String pin) async {
    final lockProvider = context.read<AppLockProvider>();

    if (lockProvider.isLockedOut) {
      return;
    }

    setState(() => _isVerifying = true);

    final success = await lockProvider.verifyPin(pin);

    if (mounted) {
      if (success) {
        lockProvider.unlock();
        _deliverPendingPayload();
      } else {
        setState(() {
          _errorText = _getErrorMessage(lockProvider);
          _isVerifying = false;
        });
        _pinInputKey.currentState?.controller.clear();
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final lockProvider = context.read<AppLockProvider>();
    final result = await lockProvider.authenticateWithBiometrics();

    if (!mounted) return;

    switch (result) {
      case BiometricAuthResult.success:
        _deliverPendingPayload();
      case BiometricAuthResult.lockedOut:
      case BiometricAuthResult.permanentlyLockedOut:
        setState(() => _errorText = 'Biometric unavailable. Please use PIN.');
      case BiometricAuthResult.notAvailable:
      case BiometricAuthResult.notEnrolled:
        break;
    }
  }

  void _deliverPendingPayload() async {
    final lockProvider = context.read<AppLockProvider>();
    final payload = lockProvider.pendingNotificationPayload;
    if (payload == null) return;

    lockProvider.clearPendingNotificationPayload();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (payload == 'daily_summary_screen') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DailySummaryScreen()));
      } else if (payload == 'review_queue') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SmsReviewQueueScreen()));
      }
    });
  }

  String _getErrorMessage(AppLockProvider lockProvider) {
    if (lockProvider.isLockedOut) {
      final remaining = lockProvider.lockoutTimeRemaining.inSeconds;
      return 'Too many attempts. Try again in ${remaining}s.';
    }
    return 'Incorrect PIN. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final lockProvider = context.watch<AppLockProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark ? AppTheme.walletHeroGradient : null,
                    color: isDark ? null : const Color(0xFFD1EBE3),
                  ),
                  alignment: Alignment.center,
                  child: lockProvider.isLockedOut
                      ? Icon(
                          Icons.timer_rounded,
                          size: 36,
                          color: AppTheme.expenseRed,
                        )
                      : Icon(
                          lockProvider.biometricAvailable
                              ? Icons.lock_outline_rounded
                              : Icons.account_balance_wallet_rounded,
                          size: 36,
                          color: AppTheme.primaryGreen,
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lockProvider.lockoutTimeRemaining.inSeconds > 0
                      ? 'Try again in ${lockProvider.lockoutTimeRemaining.inSeconds}s'
                      : 'Enter your 6-digit PIN to unlock "My Finance"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? AppTheme.secondaryGray
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 32),
                FintechCard(
                  padding: const EdgeInsets.all(22),
                  child: lockProvider.isLockedOut
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: Text(
                            'Locked for ${lockProvider.lockoutTimeRemaining.inSeconds}s',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.expenseRed,
                            ),
                          ),
                        )
                      : PinInputField(
                          key: _pinInputKey,
                          length: 6,
                          obscureByDefault: true,
                          errorText: _errorText,
                          onCompleted: _onPinCompleted,
                          onChanged: (value) {
                            if (value.length >= 6) {
                              _onPinCompleted(value.substring(0, 6));
                            } else if (value.isEmpty) {
                              setState(() => _errorText = null);
                            }
                          },
                        ),
                ),
                if (lockProvider.biometricEnabled &&
                    lockProvider.biometricAvailable &&
                    !lockProvider.isLockedOut) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isVerifying
                        ? null
                        : _authenticateWithBiometrics,
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.cardCharcoal
                          : Colors.white,
                      foregroundColor: isDark
                          ? Colors.white
                          : AppTheme.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.borderPrimary
                              : AppTheme.borderLight,
                        ),
                      ),
                    ),
                    icon: Icon(
                      Icons.fingerprint_rounded,
                      size: 22,
                      color: isDark ? Colors.white : AppTheme.primaryGreen,
                    ),
                    label: Text(
                      'Use ${lockProvider.biometricLabel}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Your finances are protected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.tertiaryGray
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
