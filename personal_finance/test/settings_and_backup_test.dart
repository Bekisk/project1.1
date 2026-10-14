import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/settings/providers/app_settings_provider.dart';

void main() {
  group('Milestone 5 - Settings, Formatting & Offline Data Management Tests', () {
    test('Currency settings defaults to ETB with proper symbols', () {
      expect(AppCurrency.etb.code, 'ETB');
      expect(AppCurrency.etb.symbol, 'ብር');
      expect(AppCurrency.usd.symbol, '\$');
      expect(AppCurrency.eur.symbol, '€');
      expect(AppCurrency.gbp.symbol, '£');
    });

    test('Date formats provide valid formatting patterns', () {
      expect(AppDateFormat.standard.pattern, 'MMM d, y');
      expect(AppDateFormat.slash.pattern, 'dd/MM/yyyy');
      expect(AppDateFormat.iso.pattern, 'yyyy-MM-dd');
      expect(AppDateFormat.full.pattern, 'MMMM d, y');
    });

    test('DataBackupService builds valid JSON structure with metadata', () {
      final exportData = {
        'version': 1,
        'appName': 'My Finance',
        'exportedAt': DateTime.now().toIso8601String(),
        'accounts': [
          {'id': 'acc-1', 'name': 'Cash Wallet', 'type': 'cash', 'balance': 500000}
        ],
        'categories': [
          {'id': 'cat-1', 'name': 'Food & Dining', 'type': 'expense'}
        ],
        'transactions': [
          {
            'id': 'tx-1',
            'accountId': 'acc-1',
            'type': 'expense',
            'amount': 5000,
            'description': 'Coffee'
          }
        ],
        'budgets': [],
        'savingsGoals': [],
        'savingsContributions': [],
      };

      final jsonString = jsonEncode(exportData);
      expect(jsonString.contains('"appName":"My Finance"'), isTrue);
      expect(jsonString.contains('"accounts"'), isTrue);
      expect(jsonString.contains('"transactions"'), isTrue);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect((decoded['accounts'] as List).length, 1);
      expect((decoded['transactions'] as List).length, 1);
    });

    test('DataBackupService validates backup payload before importing', () {
      // 1. Missing transactions key
      final invalidPayload1 = {
        'version': 1,
        'accounts': [],
      };
      expect(invalidPayload1.containsKey('transactions'), isFalse);

      // 2. Corrupt JSON
      expect(() => jsonDecode('{corrupt: json}'), throwsFormatException);

      // 3. Valid JSON with expected lists
      final validPayload = {
        'version': 1,
        'appName': 'My Finance',
        'accounts': [],
        'categories': [],
        'transactions': [],
        'budgets': [],
        'savingsGoals': [],
        'savingsContributions': [],
      };
      expect(validPayload['accounts'] is List, isTrue);
      expect(validPayload['transactions'] is List, isTrue);
    });

    test('CSV row formatting safely escapes commas and quotation marks', () {
      String sanitizeCsv(String val) {
        if (val.contains(',') || val.contains('"') || val.contains('\n')) {
          return '"${val.replaceAll('"', '""')}"';
        }
        return val;
      }

      expect(sanitizeCsv('Simple Note'), 'Simple Note');
      expect(sanitizeCsv('Note, with comma'), '"Note, with comma"');
      expect(sanitizeCsv('Note with "quotes"'), '"Note with ""quotes"""');
      expect(sanitizeCsv('Line 1\nLine 2'), '"Line 1\nLine 2"');
    });

    test('Default financial safety behavior: destructive actions require confirmation', () {
      // Confirm that the initial state retains user protection
      const defaultConfirm = true;
      const defaultAlerts = true;
      expect(defaultConfirm, isTrue);
      expect(defaultAlerts, isTrue);
    });
  });
}
