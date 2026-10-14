import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:personal_finance/features/notifications/models/daily_financial_summary.dart';
import 'package:personal_finance/features/notifications/services/notification_service.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

void main() {
  group('Daily Financial Summary & Notifications Tests', () {
    setUpAll(() {
      tz.initializeTimeZones();
    });

    final testDay = DateTime(2026, 10, 12, 14, 30); // 2:30 PM on Oct 12, 2026

    test('Financial calculation: Computes expenses, income, net cash flow, and counts correctly', () {
      final transactions = [
        // Eligible Expense 1
        FinancialTransaction(
          id: 'tx-1',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 85000, // 850.00 ETB
          description: 'Grocery Shopping',
          transactionDate: DateTime(2026, 10, 12, 10, 0),
          createdAt: DateTime(2026, 10, 12, 10, 0),
          updatedAt: DateTime(2026, 10, 12, 10, 0),
        ),
        // Eligible Expense 2
        FinancialTransaction(
          id: 'tx-2',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 15000, // 150.00 ETB
          description: 'Coffee',
          transactionDate: DateTime(2026, 10, 12, 16, 45),
          createdAt: DateTime(2026, 10, 12, 16, 45),
          updatedAt: DateTime(2026, 10, 12, 16, 45),
        ),
        // Eligible Income 1
        FinancialTransaction(
          id: 'tx-3',
          accountId: 'acc-1',
          type: TransactionType.income,
          amount: 250000, // 2,500.00 ETB
          description: 'Consulting Fee',
          transactionDate: DateTime(2026, 10, 12, 12, 0),
          createdAt: DateTime(2026, 10, 12, 12, 0),
          updatedAt: DateTime(2026, 10, 12, 12, 0),
        ),
        // Excluded: Internal Transfer
        FinancialTransaction(
          id: 'tx-4',
          accountId: 'acc-1',
          destinationAccountId: 'acc-2',
          type: TransactionType.transfer,
          amount: 50000, // 500.00 ETB
          description: 'Transfer to Savings',
          transactionDate: DateTime(2026, 10, 12, 13, 0),
          createdAt: DateTime(2026, 10, 12, 13, 0),
          updatedAt: DateTime(2026, 10, 12, 13, 0),
        ),
        // Excluded: Opening Balance
        FinancialTransaction(
          id: 'tx-5',
          accountId: 'acc-1',
          type: TransactionType.income,
          amount: 1000000, // 10,000 ETB
          description: 'Initial Opening Balance',
          transactionDate: DateTime(2026, 10, 12, 9, 0),
          createdAt: DateTime(2026, 10, 12, 9, 0),
          updatedAt: DateTime(2026, 10, 12, 9, 0),
        ),
        // Excluded: Different day (Yesterday)
        FinancialTransaction(
          id: 'tx-6',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 30000,
          description: 'Yesterday dinner',
          transactionDate: DateTime(2026, 10, 11, 20, 0),
          createdAt: DateTime(2026, 10, 11, 20, 0),
          updatedAt: DateTime(2026, 10, 11, 20, 0),
        ),
      ];

      final summary = DailyFinancialSummary.fromTransactions(
        targetDate: testDay,
        allTransactions: transactions,
      );

      expect(summary.totalExpenseCents, equals(100000)); // 1,000.00 ETB
      expect(summary.totalIncomeCents, equals(250000)); // 2,500.00 ETB
      expect(summary.netCashFlowCents, equals(150000)); // +1,500.00 ETB
      expect(summary.expenseTransactionCount, equals(2));
      expect(summary.expenseCount, equals(2));
      expect(summary.incomeTransactionCount, equals(1));
      expect(summary.incomeCount, equals(1));
      expect(summary.eligibleTransactions.length, equals(3));
      expect(summary.hasActivity, isTrue);

      final body = summary.toNotificationBody();
      expect(body, contains('Expenses'));
      expect(body, contains('Income'));
      expect(body, contains('Net +'));

      final expanded = summary.toExpandedBigText();
      expect(expanded, contains('Total Expenses'));
      expect(expanded, contains('Total Income'));
      expect(expanded, contains('Net Cashflow'));
    });

    test('Truthful empty state: returns honest message when no transactions recorded today', () {
      final summary = DailyFinancialSummary.fromTransactions(
        targetDate: testDay,
        allTransactions: const [],
      );

      expect(summary.totalExpenseCents, equals(0));
      expect(summary.totalIncomeCents, equals(0));
      expect(summary.netCashFlowCents, equals(0));
      expect(summary.expenseCount, equals(0));
      expect(summary.incomeCount, equals(0));
      expect(summary.hasActivity, isFalse);

      final body = summary.toNotificationBody();
      expect(body, contains('No income or expenses recorded today'));
    });

    test('Scheduling logic: calculateNextScheduledTime rolls over to tomorrow if time has passed today', () {
      final utcLoc = tz.getLocation('UTC');

      // Schedule for 8:00 PM (20:00)
      final scheduledTime = NotificationService.instance.calculateNextScheduledTime(20, 0, utcLoc);
      final now = tz.TZDateTime.now(utcLoc);

      expect(scheduledTime.isAfter(now), isTrue);
      expect(scheduledTime.hour, equals(20));
      expect(scheduledTime.minute, equals(0));
    });
  });
}
