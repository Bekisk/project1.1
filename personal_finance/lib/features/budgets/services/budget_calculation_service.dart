import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

enum BudgetHealthStatus {
  onTrack,
  approachingLimit,
  exceeded,
}

class BudgetCalculationResult {
  final Budget budget;
  final Category? category;
  final int spentCents;
  final int remainingCents; // signed: can be negative if exceeded
  final int availableCents; // non-negative: 0 if exceeded
  final int exceededCents; // non-negative: amount over budget
  final double percentageConsumed; // e.g. 45.0% or 120.0%
  final double visualProgress; // clamped between 0.0 and 1.0 for progress bars
  final BudgetHealthStatus healthStatus;
  final List<FinancialTransaction> contributingTransactions;

  BudgetCalculationResult({
    required this.budget,
    this.category,
    required this.spentCents,
    required this.remainingCents,
    required this.availableCents,
    required this.exceededCents,
    required this.percentageConsumed,
    required this.visualProgress,
    required this.healthStatus,
    required this.contributingTransactions,
  });
}

class OverallBudgetSummary {
  final int totalAllocatedCents;
  final int totalSpentCents;
  final int remainingCents;
  final int availableCents;
  final int exceededCents;
  final double percentageConsumed;
  final double visualProgress;
  final int atRiskCount;
  final int exceededCount;
  final int onTrackCount;
  final List<BudgetCalculationResult> categoryBudgetResults;
  final List<BudgetCalculationResult> overallBudgetResults;

  OverallBudgetSummary({
    required this.totalAllocatedCents,
    required this.totalSpentCents,
    required this.remainingCents,
    required this.availableCents,
    required this.exceededCents,
    required this.percentageConsumed,
    required this.visualProgress,
    required this.atRiskCount,
    required this.exceededCount,
    required this.onTrackCount,
    required this.categoryBudgetResults,
    required this.overallBudgetResults,
  });

  factory OverallBudgetSummary.empty() {
    return OverallBudgetSummary(
      totalAllocatedCents: 0,
      totalSpentCents: 0,
      remainingCents: 0,
      availableCents: 0,
      exceededCents: 0,
      percentageConsumed: 0.0,
      visualProgress: 0.0,
      atRiskCount: 0,
      exceededCount: 0,
      onTrackCount: 0,
      categoryBudgetResults: [],
      overallBudgetResults: [],
    );
  }
}

class BudgetCalculationService {
  /// Pure function calculating spending progress and status for a single budget against transactions
  static BudgetCalculationResult calculateBudgetProgress({
    required Budget budget,
    required List<FinancialTransaction> transactions,
    Category? category,
  }) {
    // 1. Filter eligible transactions
    // RULES:
    // - Only type == TransactionType.expense
    // - Transaction date must be >= periodStart and <= periodEnd (inclusive, comparing timestamps in local time)
    // - If category budget: transaction.categoryId must match budget.categoryId
    // - If account scope configured: transaction.accountId must match budget.accountId
    final start = budget.periodStart.toLocal();
    final end = budget.periodEnd.toLocal();

    final eligibleTransactions = transactions.where((tx) {
      if (tx.type != TransactionType.expense) return false;

      final txDate = tx.transactionDate.toLocal();
      if (txDate.isBefore(start) || txDate.isAfter(end)) return false;

      // Category check
      if (budget.budgetType == BudgetType.category) {
        if (budget.categoryId == null || tx.categoryId != budget.categoryId) {
          return false;
        }
      }

      // Account scope check
      if (budget.accountId != null && tx.accountId != budget.accountId) {
        return false;
      }

      return true;
    }).toList();

    // 2. Sum spent cents
    final int spentCents = eligibleTransactions.fold(0, (sum, tx) => sum + tx.amount);

    // 3. Compute remaining, available, and exceeded amounts
    final int limit = budget.amount;
    final int remaining = limit - spentCents;
    final int available = remaining > 0 ? remaining : 0;
    final int exceeded = spentCents > limit ? (spentCents - limit) : 0;

    // 4. Percentage consumed & visual progress clamp
    final double percentage = limit > 0 ? (spentCents / limit) * 100.0 : 0.0;
    final double visualProgress = limit > 0 ? (spentCents / limit).clamp(0.0, 1.0) : 0.0;

    // 5. Health status
    final BudgetHealthStatus status;
    if (spentCents > limit) {
      status = BudgetHealthStatus.exceeded;
    } else if (limit > 0 && (spentCents / limit) >= budget.warningThreshold) {
      status = BudgetHealthStatus.approachingLimit;
    } else {
      status = BudgetHealthStatus.onTrack;
    }

    return BudgetCalculationResult(
      budget: budget,
      category: category,
      spentCents: spentCents,
      remainingCents: remaining,
      availableCents: available,
      exceededCents: exceeded,
      percentageConsumed: percentage,
      visualProgress: visualProgress,
      healthStatus: status,
      contributingTransactions: eligibleTransactions,
    );
  }

  /// Calculates aggregated overall spending and categorised summaries for an active period
  static OverallBudgetSummary calculateOverallSummary({
    required List<Budget> budgets,
    required List<FinancialTransaction> transactions,
    required Map<String, Category> categoryMap,
  }) {
    if (budgets.isEmpty) {
      return OverallBudgetSummary.empty();
    }

    final List<BudgetCalculationResult> catResults = [];
    final List<BudgetCalculationResult> overallResults = [];

    int totalAllocated = 0;
    int atRiskCount = 0;
    int exceededCount = 0;
    int onTrackCount = 0;

    for (final b in budgets) {
      if (b.isArchived) continue;
      totalAllocated += b.amount;

      final cat = b.categoryId != null ? categoryMap[b.categoryId] : null;
      final res = calculateBudgetProgress(
        budget: b,
        transactions: transactions,
        category: cat,
      );

      if (res.healthStatus == BudgetHealthStatus.exceeded) {
        exceededCount++;
      } else if (res.healthStatus == BudgetHealthStatus.approachingLimit) {
        atRiskCount++;
      } else {
        onTrackCount++;
      }

      if (b.budgetType == BudgetType.category) {
        catResults.add(res);
      } else {
        overallResults.add(res);
      }
    }

    // Determine overall unique eligible spending across all active budgets
    // To avoid double-counting transactions across multiple overlapping category budgets:
    final Set<String> uniqueExpenseIds = {};
    for (final res in [...catResults, ...overallResults]) {
      for (final tx in res.contributingTransactions) {
        uniqueExpenseIds.add(tx.id);
      }
    }

    final int totalSpent = transactions
        .where((tx) => uniqueExpenseIds.contains(tx.id))
        .fold(0, (sum, tx) => sum + tx.amount);

    final int remaining = totalAllocated - totalSpent;
    final int available = remaining > 0 ? remaining : 0;
    final int exceeded = totalSpent > totalAllocated ? (totalSpent - totalAllocated) : 0;
    final double percentage = totalAllocated > 0 ? (totalSpent / totalAllocated) * 100.0 : 0.0;
    final double visualProgress = totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0.0;

    return OverallBudgetSummary(
      totalAllocatedCents: totalAllocated,
      totalSpentCents: totalSpent,
      remainingCents: remaining,
      availableCents: available,
      exceededCents: exceeded,
      percentageConsumed: percentage,
      visualProgress: visualProgress,
      atRiskCount: atRiskCount,
      exceededCount: exceededCount,
      onTrackCount: onTrackCount,
      categoryBudgetResults: catResults,
      overallBudgetResults: overallResults,
    );
  }
}
