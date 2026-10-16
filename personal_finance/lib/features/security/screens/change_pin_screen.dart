import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/security/providers/app_lock_provider.dart';
import 'package:personal_finance/features/security/widgets/pin_input_field.dart';

/// Screen to change the existing app lock PIN.
///
/// Flow:
/// 1. Enter current PIN (verification)
/// 2. Enter new PIN
/// 3. Confirm new PIN
/// 4. Persist the new PIN hash
class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ChangePinScreen()));
  }

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

enum _ChangeStep { current, newPin, confirm }

class _ChangePinScreenState extends State<ChangePinScreen> {
  _ChangeStep _step = _ChangeStep.current;
  String _currentPin = '';
  String _newPin = '';
  String? _errorText;
  bool _isVerifying = false;
  final _pinInputKey = GlobalKey<PinInputFieldState>();

  void _onStepCompleted(String pin) {
    switch (_step) {
      case _ChangeStep.current:
        _verifyCurrentPin(pin);
      case _ChangeStep.newPin:
        setState(() {
          _newPin = pin;
          _step = _ChangeStep.confirm;
          _errorText = null;
        });
        _pinInputKey.currentState?.controller.clear();
      case _ChangeStep.confirm:
        if (pin != _newPin) {
          setState(() {
            _errorText = 'PINs do not match. Please try again.';
          });
          _pinInputKey.currentState?.controller.clear();
        } else {
          _saveNewPin();
        }
    }
  }

  Future<void> _verifyCurrentPin(String pin) async {
    setState(() => _isVerifying = true);

    final lockProvider = context.read<AppLockProvider>();
    final isValid = await lockProvider.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _currentPin = pin;
        _step = _ChangeStep.newPin;
        _isVerifying = false;
        _errorText = null;
      });
      _pinInputKey.currentState?.controller.clear();
    } else {
      setState(() {
        _isVerifying = false;
        _errorText = 'Incorrect current PIN';
      });
      _pinInputKey.currentState?.controller.clear();
    }
  }

  Future<void> _saveNewPin() async {
    setState(() => _isVerifying = true);

    final lockProvider = context.read<AppLockProvider>();
    final success = await lockProvider.changePin(_currentPin, _newPin);

    if (!mounted) return;

    if (success) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN changed successfully')));
    } else {
      setState(() {
        _isVerifying = false;
        _errorText = 'Failed to change PIN';
      });
    }
  }

  String _getStepTitle() {
    switch (_step) {
      case _ChangeStep.current:
        return 'Verify Current PIN';
      case _ChangeStep.newPin:
        return 'Enter New PIN';
      case _ChangeStep.confirm:
        return 'Confirm New PIN';
    }
  }

  String _getStepSubtitle() {
    switch (_step) {
      case _ChangeStep.current:
        return 'Enter your current PIN to continue';
      case _ChangeStep.newPin:
        return 'Enter your new 6-digit PIN';
      case _ChangeStep.confirm:
        return 'Re-enter your new PIN to confirm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Lock icon
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
                    Icons.pin_rounded,
                    size: 36,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _getStepTitle(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStepSubtitle(),
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
                  child: _isVerifying
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : PinInputField(
                          key: _pinInputKey,
                          length: 6,
                          obscureByDefault: true,
                          errorText: _errorText,
                          onCompleted: _onStepCompleted,
                          onChanged: (value) {
                            if (value.length >= 6) {
                              _onStepCompleted(value.substring(0, 6));
                            } else if (value.isEmpty) {
                              setState(() => _errorText = null);
                            }
                          },
                        ),
                ),
                if (_step != _ChangeStep.current) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _step = _ChangeStep.current;
                        _currentPin = '';
                        _newPin = '';
                        _errorText = null;
                      });
                      _pinInputKey.currentState?.controller.clear();
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
