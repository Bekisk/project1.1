import 'package:intl/intl.dart';

/// Financial calculations and currency utilities.
///
/// Important architectural decision:
/// Monetary amounts are stored as integers representing cents (1 ETB = 100 cents)
class CurrencyFormatter {
  static String _activeCurrencySymbol = 'ETB ';

  static String get activeCurrencySymbol => _activeCurrencySymbol;

  static void setCurrencySymbol(String symbol) {
    _activeCurrencySymbol = symbol.endsWith(' ') ? symbol : '$symbol ';
  }

  /// Converts cents (integer) to formatted currency string (e.g. "ETB 1,250.00")
  static String formatCents(int cents, {bool amharicSuffix = false, String? customSymbol}) {
    final double amount = cents / 100.0;
    if (amharicSuffix) {
      final NumberFormat numFormat = NumberFormat('#,##0.00');
      return '${numFormat.format(amount)} ብር';
    }
    final sym = customSymbol ?? _activeCurrencySymbol;
    final formatter = NumberFormat.currency(symbol: sym, decimalDigits: 2);
    return formatter.format(amount);
  }

  /// Compact format for dashboard badges or charts (e.g. "ETB 1.2K")
  static String formatCentsCompact(int cents, {String? customSymbol}) {
    final sym = customSymbol ?? _activeCurrencySymbol;
    final formatter = NumberFormat.compactCurrency(symbol: sym, decimalDigits: 1);
    return formatter.format(cents / 100.0);
  }

  /// Parses a user-input decimal string (e.g. "1250.50" or "1250") safely into cents
  static int? parseToCents(String input) {
    final cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final double? parsed = double.tryParse(cleaned);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    // Round to nearest cent to prevent floating-point inaccuracies
    return (parsed * 100).round();
  }

  /// Converts double to cents
  static int doubleToCents(double value) {
    return (value * 100).round();
  }

  /// Converts cents to double (for display or calculations)
  static double centsToDouble(int cents) {
    return cents / 100.0;
  }
}
