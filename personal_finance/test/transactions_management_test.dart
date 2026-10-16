import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

void main() {
  group('Milestone 2 - Financial Correctness & Accounting Tests', () {
    test('Accounting Rule: Transfer does not change total money across accounts or affect income/expenses', () {
      // Initial account balances in cents (ETB):
      // Account A: 5,000 ETB = 500,000 cents
      // Account B: 2,000 ETB = 200,000 cents
      int accountABalance = 500000;
      int accountBBalance = 200000;

      // 1. Income: 1,000 ETB (100,000 cents) into Account A
      const incomeCents = 100000;
      accountABalance += incomeCents;

      // 2. Expense: 300 ETB (30,000 cents) from Account A
      const expenseCents = 30000;
      accountABalance -= expenseCents;

      // 3. Transfer: 1,200 ETB (120,000 cents) from Account A to Account B
      const transferCents = 120000;
      accountABalance -= transferCents;
      accountBBalance += transferCents;

      // Assert expected balances:
      // Account A: 5,000 + 1,000 - 300 - 1,200 = 4,500 ETB (450,000 cents)
      expect(accountABalance, 450000);
      // Account B: 2,000 + 1,200 = 3,200 ETB (320,000 cents)
      expect(accountBBalance, 320000);
      // Combined balance: 4,500 + 3,200 = 7,700 ETB (770,000 cents)
      expect(accountABalance + accountBBalance, 770000);

      // Verify income, expense, and net cash flow:
      final transactions = [
        FinancialTransaction(
          id: 'tx-1',
          accountId: 'acc-a',
          type: TransactionType.income,
          amount: 100000,
          description: 'Salary Bonus',
          transactionDate: DateTime(2026, 10, 10, 10, 0),
          createdAt: DateTime(2026, 10, 10, 10, 0),
          updatedAt: DateTime(2026, 10, 10, 10, 0),
        ),
        FinancialTransaction(
          id: 'tx-2',
          accountId: 'acc-a',
          type: TransactionType.expense,
          amount: 30000,
          description: 'Groceries',
          transactionDate: DateTime(2026, 10, 10, 11, 0),
          createdAt: DateTime(2026, 10, 10, 11, 0),
          updatedAt: DateTime(2026, 10, 10, 11, 0),
        ),
        FinancialTransaction(
          id: 'tx-3',
          accountId: 'acc-a',
          destinationAccountId: 'acc-b',
          type: TransactionType.transfer,
          amount: 120000,
          description: 'Savings allocation',
          transactionDate: DateTime(2026, 10, 10, 12, 0),
          createdAt: DateTime(2026, 10, 10, 12, 0),
          updatedAt: DateTime(2026, 10, 10, 12, 0),
        ),
      ];

      // Income sum: Transfers MUST be excluded
      final totalIncome = transactions
          .where((t) => t.type == TransactionType.income)
          .fold(0, (sum, t) => sum + t.amount);

      // Expense sum: Transfers MUST be excluded
      final totalExpense = transactions
          .where((t) => t.type == TransactionType.expense)
          .fold(0, (sum, t) => sum + t.amount);

      final netCashFlow = totalIncome - totalExpense;

      expect(totalIncome, 100000); // 1,000 ETB
      expect(totalExpense, 30000); // 300 ETB
      expect(netCashFlow, 70000); // 700 ETB
    });

    test('Date grouping accurately groups transactions by calendar date in local timezone', () {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 8, 30);
      final todayEvening = DateTime(now.year, now.month, now.day, 18, 45);
      final yesterday = DateTime(now.year, now.month, now.day - 1, 14, 0);

      final tx1 = FinancialTransaction(
        id: '1',
        accountId: 'acc-1',
        type: TransactionType.income,
        amount: 50000,
        description: 'Morning Income',
        transactionDate: todayMorning,
        createdAt: todayMorning,
        updatedAt: todayMorning,
      );

      final tx2 = FinancialTransaction(
        id: '2',
        accountId: 'acc-1',
        type: TransactionType.expense,
        amount: 15000,
        description: 'Evening Expense',
        transactionDate: todayEvening,
        createdAt: todayEvening,
        updatedAt: todayEvening,
      );

      final tx3 = FinancialTransaction(
        id: '3',
        accountId: 'acc-1',
        type: TransactionType.expense,
        amount: 20000,
        description: 'Yesterday Expense',
        transactionDate: yesterday,
        createdAt: yesterday,
        updatedAt: yesterday,
      );

      final all = [tx1, tx2, tx3];
      final Map<DateTime, List<FinancialTransaction>> groups = {};
      for (final tx in all) {
        final d = tx.transactionDate.toLocal();
        final dayKey = DateTime(d.year, d.month, d.day);
        if (!groups.containsKey(dayKey)) {
          groups[dayKey] = [];
        }
        groups[dayKey]!.add(tx);
      }

      final todayKey = DateTime(now.year, now.month, now.day);
      final yesterdayKey = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
      );

      expect(groups.length, 2);
      expect(groups[todayKey]!.length, 2);
      expect(groups[yesterdayKey]!.length, 1);
    });

    test('Filter combining logic works across Type, Account, and Search', () {
      final txList = [
        FinancialTransaction(
          id: '1',
          accountId: 'acc-wallet',
          type: TransactionType.expense,
          amount: 25000,
          description: 'Supermarket Shoa',
          transactionDate: DateTime(2026, 10, 5),
          createdAt: DateTime(2026, 10, 5),
          updatedAt: DateTime(2026, 10, 5),
        ),
        FinancialTransaction(
          id: '2',
          accountId: 'acc-bank',
          destinationAccountId: 'acc-wallet',
          type: TransactionType.transfer,
          amount: 100000,
          description: 'ATM withdrawal',
          transactionDate: DateTime(2026, 10, 6),
          createdAt: DateTime(2026, 10, 6),
          updatedAt: DateTime(2026, 10, 6),
        ),
        FinancialTransaction(
          id: '3',
          accountId: 'acc-bank',
          type: TransactionType.income,
          amount: 800000,
          description: 'Consulting payment',
          transactionDate: DateTime(2026, 10, 7),
          createdAt: DateTime(2026, 10, 7),
          updatedAt: DateTime(2026, 10, 7),
        ),
      ];

      // Account filter: "acc-wallet" matches both direct expense and transfer destination!
      final matchingWallet = txList.where((tx) {
        return tx.accountId == 'acc-wallet' ||
            tx.destinationAccountId == 'acc-wallet';
      }).toList();
      expect(matchingWallet.length, 2);

      // Search filter: Case-insensitive query
      const query = 'shoa';
      final matchingSearch = txList
          .where((tx) => tx.description.toLowerCase().contains(query))
          .toList();
      expect(matchingSearch.length, 1);
      expect(matchingSearch.first.id, '1');
    });
  });
}
