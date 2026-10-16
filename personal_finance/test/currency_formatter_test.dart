import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/formatting/date_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formatCents formats correctly with ETB prefix', () {
      expect(CurrencyFormatter.formatCents(125000), 'ETB 1,250.00');
      expect(CurrencyFormatter.formatCents(0), 'ETB 0.00');
      expect(CurrencyFormatter.formatCents(50), 'ETB 0.50');
      expect(CurrencyFormatter.formatCents(100000000), 'ETB 1,000,000.00');
    });

    test('formatCents formats with Amharic suffix correctly', () {
      expect(
        CurrencyFormatter.formatCents(125000, amharicSuffix: true),
        '1,250.00 ብር',
      );
    });

    test('parseToCents parses string decimals into integer cents', () {
      expect(CurrencyFormatter.parseToCents('1250.00'), 125000);
      expect(CurrencyFormatter.parseToCents('1250'), 125000);
      expect(CurrencyFormatter.parseToCents('0.5'), 50);
      expect(CurrencyFormatter.parseToCents('1,250.75'), 125075);
      expect(CurrencyFormatter.parseToCents(''), isNull);
      expect(CurrencyFormatter.parseToCents('invalid'), isNull);
    });

    test('doubleToCents prevents floating point inaccuracies', () {
      // 0.1 + 0.2 in floating point is 0.30000000000000004
      final cents1 = CurrencyFormatter.doubleToCents(0.1);
      final cents2 = CurrencyFormatter.doubleToCents(0.2);
      expect(cents1 + cents2, 30);
    });
  });

  group('DateFormatter Tests', () {
    test('formatDate formats DateTime into readable string', () {
      final date = DateTime(2026, 10, 11);
      expect(DateFormatter.formatDate(date), 'Oct 11, 2026');
    });
  });
}
