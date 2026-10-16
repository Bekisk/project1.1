import 'package:flutter/material.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';

/// An animated number counter widget that smoothly animates balance transitions
class AnimatedBalanceText extends StatelessWidget {
  final int cents;
  final TextStyle? style;
  final bool showAmharicSuffix;
  final Duration duration;

  const AnimatedBalanceText({
    super.key,
    required this.cents,
    this.style,
    this.showAmharicSuffix = false,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: cents.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final formatted = CurrencyFormatter.formatCents(
          value.round(),
          amharicSuffix: showAmharicSuffix,
        );
        return Text(formatted, style: style);
      },
    );
  }
}
