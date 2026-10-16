import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:personal_finance/app/theme/app_theme.dart';

/// A premium PIN input widget showing 6 digit boxes with dot indicators.
///
/// Features:
/// - Numeric-only input (uses a hidden TextField for keyboard coordination)
/// - Masked by default (dots), with show/hide toggle
/// - Auto-focuses and submits when 6 digits are entered
/// - Accessible backspace button on the right
/// - Matches the app's dark theme aesthetic
class PinInputField extends StatefulWidget {
  /// Called when the user has entered a PIN of the expected length.
  final void Function(String pin)? onCompleted;

  /// Called on every PIN change (including deletions).
  final void Function(String pin)? onChanged;

  /// The PIN length (default 6).
  final int length;

  /// Whether the input is obscured (dots). Default true.
  final bool obscureByDefault;

  /// Error text to display below the field, if any.
  final String? errorText;

  /// Whether the field is enabled.
  final bool enabled;

  const PinInputField({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.obscureByDefault = true,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<PinInputField> createState() => PinInputFieldState();
}

class PinInputFieldState extends State<PinInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _obscured = true;

  /// Exposes the internal controller for external programmatic access.
  TextEditingController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureByDefault;
    _controller.addListener(_onChanged);
    // Auto-focus so the keyboard opens immediately on the lock/setup screens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final value = _controller.text;
    widget.onChanged?.call(value);

    if (value.length >= widget.length) {
      final pin = value.substring(0, widget.length);
      widget.onCompleted?.call(pin);
    }
  }

  void _toggleObscure() {
    setState(() => _obscured = !_obscured);
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden TextField for keyboard management + actual input capture
        Opacity(
          opacity: 0.0,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: false,
              signed: false,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            obscureText: _obscured,
            enableSuggestions: false,
            autocorrect: false,
            onTapAlwaysCalled: false,
            onEditingComplete: () {
              if (_controller.text.length >= widget.length) {
                widget.onCompleted?.call(
                  _controller.text.substring(0, widget.length),
                );
              }
            },
          ),
        ),

        // Visible PIN boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.length, (i) {
            final filled = _controller.text.length > i;
            final digit = filled ? _controller.text[i] : '';
            return Container(
              width: 44,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: filled
                      ? (isDark ? AppTheme.primaryGreen : AppTheme.primaryGreen)
                      : (isDark
                            ? AppTheme.borderPrimary
                            : AppTheme.borderLight),
                  width: filled ? 2.0 : 1.0,
                ),
                borderRadius: BorderRadius.circular(10),
                color: isDark
                    ? AppTheme.inputCharcoal.withValues(alpha: 0.7)
                    : AppTheme.surfaceSubtleLight.withValues(alpha: 0.7),
              ),
              child: filled
                  ? (_obscured
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryGreen,
                            ),
                          )
                        : Text(
                            digit,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ))
                  : null,
            );
          }),
        ),

        const SizedBox(height: 12),

        // Show/hide toggle and clear button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show/Hide toggle
            TextButton.icon(
              onPressed: _toggleObscure,
              icon: Icon(
                _obscured
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 16,
                color: isDark
                    ? AppTheme.secondaryGray
                    : AppTheme.textSecondaryLight,
              ),
              label: Text(
                _obscured ? 'Show' : 'Hide',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.secondaryGray
                      : AppTheme.textSecondaryLight,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            // Spacer
            if (_controller.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _clear,
                icon: Icon(
                  Icons.backspace_rounded,
                  size: 16,
                  color: isDark
                      ? AppTheme.secondaryGray
                      : AppTheme.textSecondaryLight,
                ),
                label: const SizedBox.shrink(),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ],
        ),

        // Error message
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: TextStyle(
              color: AppTheme.expenseRed,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
