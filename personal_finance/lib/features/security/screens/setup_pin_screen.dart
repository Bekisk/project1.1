import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/security/providers/app_lock_provider.dart';
import 'package:personal_finance/features/security/widgets/pin_input_field.dart';

/// First-time app lock setup screen.
///
/// Flow:
/// 1. Enter a 6-digit PIN
/// 2. Confirm the PIN
/// 3. Store the hashed PIN in secure storage
/// 4. Offer biometric unlock (optional) → skip or enable
class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupPinScreen()),
    );
  }

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

enum _SetupStep { create, confirm, biometric }

class _SetupPinScreenState extends State<SetupPinScreen> {
  _SetupStep _step = _SetupStep.create;
  String _pin = '';
  String? _errorText;
  bool _isSaving = false;
  final _pinInputKey = GlobalKey<PinInputFieldState>();

  void _onCreateCompleted(String pin) {
    setState(() {
      _pin = pin;
      _errorText = null;
      _step = _SetupStep.confirm;
    });
    _pinInputKey.currentState?.controller.clear();
  }

  void _onConfirmCompleted(String confirmValue) {
    if (confirmValue != _pin) {
      setState(() {
        _errorText = 'PINs do not match. Please try again.';
      });
      _pinInputKey.currentState?.controller.clear();
    } else {
      _completeSetup();
    }
  }

  void _completeSetup() async {
    setState(() => _isSaving = true);

    final lockProvider = context.read<AppLockProvider>();

    try {
      await lockProvider.setupLock(_pin);

      if (mounted) {
        final canCheck = await lockProvider.checkBiometricAvailable();
        setState(() {
          _step = canCheck ? _SetupStep.biometric : _SetupStep.create;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Failed to save PIN. Please try again.';
        });
      }
    }
  }

  void _enableBiometric() async {
    setState(() => _isSaving = true);
    final lockProvider = context.read<AppLockProvider>();
    await lockProvider.setBiometricEnabled(true);
    setState(() => _isSaving = false);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _skipBiometric() {
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildContent(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_step) {
      case _SetupStep.create:
        return _buildCreateStep(isDark);
      case _SetupStep.confirm:
        return _buildConfirmStep(isDark);
      case _SetupStep.biometric:
        return _buildBiometricStep(isDark);
    }
  }

  Widget _buildCreateStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark ? AppTheme.walletHeroGradient : null,
            color: isDark ? null : const Color(0xFFD1EBE3),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 36,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Create App Lock',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set a 6-digit PIN to protect your finances.',
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
          child: PinInputField(
            key: _pinInputKey,
            length: 6,
            obscureByDefault: true,
            onCompleted: _onCreateCompleted,
            onChanged: (value) {
              if (value.length >= 6) {
                _onCreateCompleted(value.substring(0, 6));
              } else if (value.isEmpty) {
                setState(() => _errorText = null);
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Your PIN is stored securely and never leaves your device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.tertiaryGray : AppTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark ? AppTheme.walletHeroGradient : null,
            color: isDark ? null : const Color(0xFFD1EBE3),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.lock_outline_rounded,
            size: 36,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Confirm App Lock',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Re-enter your 6-digit PIN to confirm.',
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
          child: PinInputField(
            key: _pinInputKey,
            length: 6,
            obscureByDefault: true,
            errorText: _errorText,
            onCompleted: _onConfirmCompleted,
            onChanged: (value) {
              if (value.length >= 6) {
                _onConfirmCompleted(value.substring(0, 6));
              } else if (value.isEmpty && _errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _step = _SetupStep.create;
              _pin = '';
              _errorText = null;
            });
            _pinInputKey.currentState?.controller.clear();
          },
          child: const Text('Use a different PIN'),
        ),
      ],
    );
  }

  Widget _buildBiometricStep(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.fingerprint_rounded,
            size: 44,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enable Fingerprint Unlock?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use your fingerprint to unlock "My Finance" quickly. '
          'You can enable it later in Settings.',
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
        FilledButton.icon(
          onPressed: _isSaving ? null : _enableBiometric,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.fingerprint_rounded, color: Colors.white),
          label: Text(
            _isSaving ? 'Enabling...' : 'Enable Fingerprint',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isSaving ? null : _skipBiometric,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Skip for Now',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your PIN is always required as a fallback.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.tertiaryGray : AppTheme.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
