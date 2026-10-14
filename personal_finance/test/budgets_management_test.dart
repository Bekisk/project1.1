import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/budgets/services/budget_calculation_service.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

void main() {
  group('Milestone 3 — Complete Budgeting & Spending Progress Tests', () {
    final foodCategory = Category(
      id: 'cat-food',
      name: 'Food & Dining',
      transactionType: 'expense',
      iconKey: 'restaurant',
      colorKey: '0xFFFF7043',
    );

    // Test A — Category budget
    test('Test A: Category budget limits spending accurately and excludes income/transfers', () {
      final now = DateTime(2026, 10, 15);
      final monthStart = DateTime(2026, 10, 1);
      final monthEnd = DateTime(2026, 10, 31, 23, 59, 59, 999);

      final foodBudget = Budget(
        id: 'budget-food',
        name: 'Food Budget',
        budgetType: BudgetType.category,
        categoryId: 'cat-food',
        amount: 200000, // 2,000 ETB
        periodStart: monthStart,
        periodEnd: monthEnd,
        createdAt: monthStart,
        updatedAt: monthStart,
      );

      final transactions = [
        FinancialTransaction(
          id: 'tx-1',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 50000, // 500 ETB
          categoryId: 'cat-food',
          description: 'Lunch',
          transactionDate: DateTime(2026, 10, 5),
          createdAt: now,
          updatedAt: now,
        ),
        FinancialTransaction(
          id: 'tx-2',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 30000, // 300 ETB
          categoryId: 'cat-food',
          description: 'Dinner',
          transactionDate: DateTime(2026, 10, 8),
          createdAt: now,
          updatedAt: now,
        ),
        FinancialTransaction(
          id: 'tx-3',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 20000, // 200 ETB
          categoryId: 'cat-transport',
          description: 'Taxi Ride',
          transactionDate: DateTime(2026, 10, 9),
          createdAt: now,
          updatedAt: now,
        ),
        FinancialTransaction(
          id: 'tx-4',
          accountId: 'acc-1',
          type: TransactionType.income,
          amount: 100000, // 1,000 ETB
          categoryId: 'cat-salary',
          description: 'Bonus',
          transactionDate: DateTime(2026, 10, 10),
          createdAt: now,
          updatedAt: now,
        ),
        FinancialTransaction(
          id: 'tx-5',
          accountId: 'acc-1',
          destinationAccountId: 'acc-2',
          type: TransactionType.transfer,
          amount: 40000, // 400 ETB
          description: 'Transfer to savings',
          transactionDate: DateTime(2026, 10, 11),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = BudgetCalculationService.calculateBudgetProgress(
        budget: foodBudget,
        transactions: transactions,
        category: foodCategory,
      );

      expect(result.budget.amount, 200000); // 2,000 ETB
      expect(result.spentCents, 80000); // 800 ETB (500 + 300)
      expect(result.remainingCents, 120000); // 1,200 ETB
      expect(result.availableCents, 120000);
      expect(result.percentageConsumed, 40.0); // 40%
      expect(result.visualProgress, 0.4);
      expect(result.healthStatus, BudgetHealthStatus.onTrack);
      expect(result.contributingTransactions.length, 2);
    });

    // Test B — Overall budget
    test('Test B: Overall budget aggregates eligible multi-category expenses', () {
      final monthStart = DateTime(2026, 10, 1);
      final monthEnd = DateTime(2026, 10, 31, 23, 59, 59, 999);

      final overallBudget = Budget(
        id: 'budget-overall',
        name: 'Total Monthly Budget',
        budgetType: BudgetType.overall,
        amount: 500000, // 5,000 ETB
        periodStart: monthStart,
        periodEnd: monthEnd,
        createdAt: monthStart,
        updatedAt: monthStart,
      );

      final transactions = [
        FinancialTransaction(
          id: 'tx-1',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 100000, // 1,000 ETB
          categoryId: 'cat-food',
          description: 'Groceries',
          transactionDate: DateTime(2026, 10, 5),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'tx-2',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 50000, // 500 ETB
          categoryId: 'cat-transport',
          description: 'Fuel',
          transactionDate: DateTime(2026, 10, 8),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        FinancialTransaction(
          id: 'tx-3',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 75000, // 750 ETB
          categoryId: 'cat-shopping',
          description: 'Clothes',
          transactionDate: DateTime(2026, 10, 12),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = BudgetCalculationService.calculateBudgetProgress(
        budget: overallBudget,
        transactions: transactions,
      );

      expect(result.budget.amount, 500000); // 5,000 ETB
      expect(result.spentCents, 225000); // 2,250 ETB
      expect(result.remainingCents, 275000); // 2,750 ETB
      expect(result.availableCents, 275000);
      expect(result.percentageConsumed, 45.0); // 45%
      expect(result.visualProgress, 0.45);
      expect(result.healthStatus, BudgetHealthStatus.onTrack);
    });

    // Test C — Over-budget behavior
    test('Test C: Over-budget behavior preserves actual spending, computes exceeded amount, clamps visual bar, and sets Exceeded status', () {
      final monthStart = DateTime(2026, 10, 1);
      final monthEnd = DateTime(2026, 10, 31, 23, 59, 59, 999);

      final budget = Budget(
        id: 'budget-exceeded',
        name: 'Dining Budget',
        budgetType: BudgetType.category,
        categoryId: 'cat-food',
        amount: 100000, // 1,000 ETB
        periodStart: monthStart,
        periodEnd: monthEnd,
        createdAt: monthStart,
        updatedAt: monthStart,
      );

      final transactions = [
        FinancialTransaction(
          id: 'tx-1',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 120000, // 1,200 ETB
          categoryId: 'cat-food',
          description: 'Fancy Dinner',
          transactionDate: DateTime(2026, 10, 12),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = BudgetCalculationService.calculateBudgetProgress(
        budget: budget,
        transactions: transactions,
      );

      expect(result.spentCents, 120000); // 1,200 ETB
      expect(result.exceededCents, 20000); // 200 ETB
      expect(result.remainingCents, -20000); // -200 ETB
      expect(result.availableCents, 0); // Non-negative available amount is 0
      expect(result.percentageConsumed, 120.0); // 120%
      expect(result.visualProgress, 1.0); // Visual progress clamped to 1.0
      expect(result.healthStatus, BudgetHealthStatus.exceeded);
    });

    // Test D — Date boundaries & timezone inclusive rules
    test('Test D: Date boundary test (inclusive start and end, excludes out-of-range dates)', () {
      final start = DateTime(2026, 10, 1, 0, 0, 0);
      final end = DateTime(2026, 10, 31, 23, 59, 59);

      final budget = Budget(
        id: 'budget-dates',
        name: 'Date Test Budget',
        budgetType: BudgetType.overall,
        amount: 500000,
        periodStart: start,
        periodEnd: end,
        createdAt: start,
        updatedAt: start,
      );

      final transactions = [
        // Immediately before start
        FinancialTransaction(
          id: 'tx-before',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 10000,
          description: 'Sept 30 expense',
          transactionDate: DateTime(2026, 9, 30, 23, 59, 59),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // On start date
        FinancialTransaction(
          id: 'tx-start',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 20000,
          description: 'Oct 1 start expense',
          transactionDate: DateTime(2026, 10, 1, 0, 0, 0),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // On end date
        FinancialTransaction(
          id: 'tx-end',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 30000,
          description: 'Oct 31 end expense',
          transactionDate: DateTime(2026, 10, 31, 23, 59, 59),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        // Immediately after end
        FinancialTransaction(
          id: 'tx-after',
          accountId: 'acc-1',
          type: TransactionType.expense,
          amount: 40000,
          description: 'Nov 1 expense',
          transactionDate: DateTime(2026, 11, 1, 0, 0, 0),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final result = BudgetCalculationService.calculateBudgetProgress(
        budget: budget,
        transactions: transactions,
      );

      expect(result.spentCents, 50000); // Only tx-start (20,000) + tx-end (30,000)
      expect(result.contributingTransactions.length, 2);
    });

    // Test E — Transaction updates (Amount change, category change, deletion)
    test('Test E: Adding, modifying, and deleting transactions recalculates budget correctly', () {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31, 23, 59, 59);

      final foodBudget = Budget(
        id: 'budget-food',
        name: 'Food',
        budgetType: BudgetType.category,
        categoryId: 'cat-food',
        amount: 100000,
        periodStart: start,
        periodEnd: end,
        createdAt: start,
        updatedAt: start,
      );

      final txList = <FinancialTransaction>[];

      // Initial: 0 spent
      var res = BudgetCalculationService.calculateBudgetProgress(budget: foodBudget, transactions: txList);
      expect(res.spentCents, 0);

      // Add expense
      final tx1 = FinancialTransaction(
        id: 'tx-1',
        accountId: 'acc-1',
        type: TransactionType.expense,
        amount: 40000, // 400 ETB
        categoryId: 'cat-food',
        description: 'Groceries',
        transactionDate: DateTime(2026, 10, 5),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      txList.add(tx1);

      res = BudgetCalculationService.calculateBudgetProgress(budget: foodBudget, transactions: txList);
      expect(res.spentCents, 40000);

      // Update amount of tx1 from 400 ETB to 600 ETB
      final tx1Updated = FinancialTransaction(
        id: 'tx-1',
        accountId: 'acc-1',
        type: TransactionType.expense,
        amount: 60000, // 600 ETB
        categoryId: 'cat-food',
        description: 'Groceries (updated)',
        transactionDate: DateTime(2026, 10, 5),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      txList[0] = tx1Updated;

      res = BudgetCalculationService.calculateBudgetProgress(budget: foodBudget, transactions: txList);
      expect(res.spentCents, 60000);

      // Change category of tx1 to transport: food budget spending drops to 0!
      final tx1Transport = FinancialTransaction(
        id: 'tx-1',
        accountId: 'acc-1',
        type: TransactionType.expense,
        amount: 60000,
        categoryId: 'cat-transport',
        description: 'Flight ticket',
        transactionDate: DateTime(2026, 10, 5),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      txList[0] = tx1Transport;

      res = BudgetCalculationService.calculateBudgetProgress(budget: foodBudget, transactions: txList);
      expect(res.spentCents, 0);

      // Delete tx1
      txList.clear();
      res = BudgetCalculationService.calculateBudgetProgress(budget: foodBudget, transactions: txList);
      expect(res.spentCents, 0);
    });

    // Test G — Alert thresholds
    test('Test G: Warning thresholds trigger Approaching Limit and Exceeded correctly', () {
      final start = DateTime(2026, 10, 1);
      final end = DateTime(2026, 10, 31, 23, 59, 59);

      final budget = Budget(
        id: 'budget-alert',
        name: 'Alert Test',
        budgetType: BudgetType.overall,
        amount: 100000, // 1,000 ETB
        warningThreshold: 0.8, // 80%
        periodStart: start,
        periodEnd: end,
        createdAt: start,
        updatedAt: start,
      );

      // 1. Below threshold: 700 ETB (70%) => On Track
      var res = BudgetCalculationService.calculateBudgetProgress(
        budget: budget,
        transactions: [
          FinancialTransaction(
            id: '1',
            accountId: 'acc-1',
            type: TransactionType.expense,
            amount: 70000,
            description: 'Spending 1',
            transactionDate: DateTime(2026, 10, 5),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      expect(res.healthStatus, BudgetHealthStatus.onTrack);

      // 2. At threshold: 800 ETB (80%) => Approaching Limit
      res = BudgetCalculationService.calculateBudgetProgress(
        budget: budget,
        transactions: [
          FinancialTransaction(
            id: '2',
            accountId: 'acc-1',
            type: TransactionType.expense,
            amount: 80000,
            description: 'Spending 2',
            transactionDate: DateTime(2026, 10, 5),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      expect(res.healthStatus, BudgetHealthStatus.approachingLimit);

      // 3. Exceeded: 1,050 ETB (105%) => Exceeded
      res = BudgetCalculationService.calculateBudgetProgress(
        budget: budget,
        transactions: [
          FinancialTransaction(
            id: '3',
            accountId: 'acc-1',
            type: TransactionType.expense,
            amount: 105000,
            description: 'Spending 3',
            transactionDate: DateTime(2026, 10, 5),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      expect(res.healthStatus, BudgetHealthStatus.exceeded);
    });
  });
}
