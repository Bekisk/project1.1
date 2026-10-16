import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/services/account_balance_service.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';

enum DashboardPeriod { thisMonth, lastMonth, thisYear, allTime, custom }

class CategorySpending {
  final Category category;
  final int totalCents;
  final double percentage;

  CategorySpending({
    required this.category,
    required this.totalCents,
    required this.percentage,
  });
}

class DashboardSummary {
  final int totalBalance; // cents across all active accounts
  final int monthIncome; // cents for selected period
  final int monthExpense; // cents for selected period
  final int netCashFlow; // cents for selected period
  final int budgetTotalLimit; // cents
  final int budgetTotalSpent; // cents
  final int goalsTotalTarget; // cents
  final int goalsTotalSaved; // cents
  final List<FinancialTransaction> recentTransactions;
  final List<Account> accounts;
  final Map<String, int>
  accountBalances; // balance in cents keyed by account.id
  final Map<String, AccountBalanceInfo>
  accountBalanceInfos; // rich balance info keyed by account.id
  final List<SavingsGoal> activeGoals;
  final List<CategorySpending> topCategories;
  final List<int> weeklySpending; // last 7 days daily spending in cents
  final Map<String, Category> categoryMap;
  final DashboardPeriod period;
  final String periodLabel;
  final int dailySpend7Days; // average daily spend over last 7 days in cents
  final int dailySpend30Days; // average daily spend over last 30 days in cents
  final int runwayDays; // available cash / dailySpend30Days (or 7Days fallback)

  DashboardSummary({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.netCashFlow,
    required this.budgetTotalLimit,
    required this.budgetTotalSpent,
    required this.goalsTotalTarget,
    required this.goalsTotalSaved,
    required this.recentTransactions,
    required this.accounts,
    required this.accountBalances,
    this.accountBalanceInfos = const {},
    required this.activeGoals,
    required this.topCategories,
    required this.weeklySpending,
    required this.categoryMap,
    this.period = DashboardPeriod.thisMonth,
    this.periodLabel = 'This Month',
    this.dailySpend7Days = 0,
    this.dailySpend30Days = 0,
    this.runwayDays = 0,
  });

  factory DashboardSummary.empty() {
    return DashboardSummary(
      totalBalance: 0,
      monthIncome: 0,
      monthExpense: 0,
      netCashFlow: 0,
      budgetTotalLimit: 0,
      budgetTotalSpent: 0,
      goalsTotalTarget: 0,
      goalsTotalSaved: 0,
      recentTransactions: [],
      accounts: [],
      accountBalances: {},
      accountBalanceInfos: {},
      activeGoals: [],
      topCategories: [],
      weeklySpending: [0, 0, 0, 0, 0, 0, 0],
      categoryMap: {},
      period: DashboardPeriod.thisMonth,
      periodLabel: 'This Month',
      dailySpend7Days: 0,
      dailySpend30Days: 0,
      runwayDays: 0,
    );
  }
}

class DashboardProvider extends ChangeNotifier {
  DashboardSummary _summary = DashboardSummary.empty();
  DashboardPeriod _selectedPeriod = DashboardPeriod.thisMonth;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isLoading = true;

  DashboardSummary get summary => _summary;
  DashboardPeriod get selectedPeriod => _selectedPeriod;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  bool get isLoading => _isLoading;

  void setPeriod(
    DashboardPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    _selectedPeriod = period;
    _customStartDate = customStart;
    _customEndDate = customEnd;
    loadDashboardData();
  }

  (String?, String?, String) _resolvePeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case DashboardPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(
          now.month == 12 ? now.year + 1 : now.year,
          now.month == 12 ? 1 : now.month + 1,
          1,
        );
        return (
          start.toIso8601String(),
          nextMonth.toIso8601String(),
          'This Month',
        );

      case DashboardPeriod.lastMonth:
        final prevYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final start = DateTime(prevYear, prevMonth, 1);
        final end = DateTime(now.year, now.month, 1);
        return (start.toIso8601String(), end.toIso8601String(), 'Last Month');

      case DashboardPeriod.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1);
        return (start.toIso8601String(), end.toIso8601String(), 'This Year');

      case DashboardPeriod.allTime:
        return (null, null, 'All Time');

      case DashboardPeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final start = DateTime(
            _customStartDate!.year,
            _customStartDate!.month,
            _customStartDate!.day,
          );
          final end = DateTime(
            _customEndDate!.year,
            _customEndDate!.month,
            _customEndDate!.day,
            23,
            59,
            59,
            999,
          );
          return (
            start.toIso8601String(),
            end.toIso8601String(),
            'Custom Range',
          );
        }
        return (null, null, 'Custom Range');
    }
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load Accounts
      final accountMaps = await db.query('accounts', where: 'is_archived = 0');
      final accounts = accountMaps.map((e) => Account.fromMap(e)).toList();

      // 2. Load Categories
      final catMaps = await db.query('categories', where: 'is_archived = 0');
      final allCategories = catMaps.map((e) => Category.fromMap(e)).toList();
      final categoryMap = {for (var c in allCategories) c.id: c};

      // 3. Calculate balance for each account using AccountBalanceService
      int calculatedTotalBalance = 0;
      final Map<String, int> calculatedBalances = {};
      final Map<String, AccountBalanceInfo> calculatedInfos = {};
      for (final acc in accounts) {
        final info = await AccountBalanceService.instance.getAccountBalanceInfo(
          acc,
          executor: db,
        );
        calculatedBalances[acc.id] = info.calculatedBalance;
        calculatedInfos[acc.id] = info;
        calculatedTotalBalance += info.calculatedBalance;
      }

      // 4. Resolve selected period dates for period-specific income and expenses
      final (periodStart, periodEnd, periodLabel) = _resolvePeriodDates();

      int periodIncome = 0;
      int periodExpense = 0;

      if (periodStart != null && periodEnd != null) {
        final incomeRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND transaction_date >= ? AND transaction_date < ?",
          [periodStart, periodEnd],
        );
        periodIncome = (incomeRes.first['total'] as int?) ?? 0;

        final expenseRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND transaction_date >= ? AND transaction_date < ?",
          [periodStart, periodEnd],
        );
        periodExpense = (expenseRes.first['total'] as int?) ?? 0;
      } else {
        // All time
        final incomeRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'income'",
        );
        periodIncome = (incomeRes.first['total'] as int?) ?? 0;

        final expenseRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense'",
        );
        periodExpense = (expenseRes.first['total'] as int?) ?? 0;
      }

      // 5. Budgets
      final now = DateTime.now();
      final budgetLimitRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM budgets WHERE period_start <= ? AND period_end >= ? AND is_archived = 0",
        [now.toIso8601String(), now.toIso8601String()],
      );
      final int budgetTotalLimit = (budgetLimitRes.first['total'] as int?) ?? 0;

      // 6. Active Goals & Saved amounts
      final goalMaps = await db.query(
        'savings_goals',
        where: "status = 'active'",
      );
      final activeGoals = goalMaps.map((e) => SavingsGoal.fromMap(e)).toList();

      int goalsTarget = 0;
      int goalsSaved = 0;
      for (final g in activeGoals) {
        goalsTarget += g.targetAmount;
        final contribRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM goal_contributions WHERE goal_id = ?",
          [g.id],
        );
        final dynamic rawSum = contribRes.first['total'];
        final int contribTotal = rawSum is num ? rawSum.round() : 0;
        goalsSaved += contribTotal;
      }

      // 7. Recent transactions
      final recentTxMaps = await db.query(
        'transactions',
        orderBy: 'transaction_date DESC, created_at DESC',
        limit: 8,
      );
      final recentTransactions = recentTxMaps
          .map((e) => FinancialTransaction.fromMap(e))
          .toList();

      // 8. Spending breakdown by category for selected period
      List<Map<String, Object?>> catSpendingRes;
      if (periodStart != null && periodEnd != null) {
        catSpendingRes = await db.rawQuery(
          '''
          SELECT category_id, SUM(amount) as total
          FROM transactions
          WHERE type = 'expense' AND transaction_date >= ? AND transaction_date < ? AND category_id IS NOT NULL
          GROUP BY category_id
          ORDER BY total DESC
        ''',
          [periodStart, periodEnd],
        );
      } else {
        catSpendingRes = await db.rawQuery('''
          SELECT category_id, SUM(amount) as total
          FROM transactions
          WHERE type = 'expense' AND category_id IS NOT NULL
          GROUP BY category_id
          ORDER BY total DESC
        ''');
      }

      final List<CategorySpending> topCategories = [];
      for (final row in catSpendingRes) {
        final catId = row['category_id'] as String;
        final total = (row['total'] as int?) ?? 0;
        final cat = categoryMap[catId];
        if (cat != null && periodExpense > 0) {
          topCategories.add(
            CategorySpending(
              category: cat,
              totalCents: total,
              percentage: (total / periodExpense).clamp(0.0, 1.0),
            ),
          );
        }
      }

      // 9. Last 7 days spending for dynamic trend chart
      final List<int> weeklySpending = [];
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        final dayStart = day.toIso8601String();
        final dayEnd = day.add(const Duration(days: 1)).toIso8601String();

        final dayRes = await db.rawQuery(
          '''
          SELECT SUM(amount) as total
          FROM transactions
          WHERE type = 'expense' AND transaction_date >= ? AND transaction_date < ?
        ''',
          [dayStart, dayEnd],
        );

        final dayTotal = (dayRes.first['total'] as int?) ?? 0;
        weeklySpending.add(dayTotal);
      }

      // 10. Calculate Spending Velocity & Burn Rate (7-day and 30-day)
      final sevenDaysAgo = now
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final thirtyDaysAgo = now
          .subtract(const Duration(days: 30))
          .toIso8601String();
      final nowIso = now.toIso8601String();

      final res7 = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'expense' AND transaction_date >= ? AND transaction_date <= ?
      ''',
        [sevenDaysAgo, nowIso],
      );
      final total7Days = (res7.first['total'] as int?) ?? 0;
      final int dailySpend7Days = (total7Days / 7.0).round();

      final res30 = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'expense' AND transaction_date >= ? AND transaction_date <= ?
      ''',
        [thirtyDaysAgo, nowIso],
      );
      final total30Days = (res30.first['total'] as int?) ?? 0;
      final int dailySpend30Days = (total30Days / 30.0).round();

      // Effective daily burn rate for runway calculation:
      // use 30-day if positive, otherwise fall back to 7-day
      final effectiveDailySpend = dailySpend30Days > 0
          ? dailySpend30Days
          : dailySpend7Days;
      int runwayDays = 999;
      if (effectiveDailySpend > 0) {
        if (calculatedTotalBalance <= 0) {
          runwayDays = 0;
        } else {
          runwayDays = (calculatedTotalBalance / effectiveDailySpend).floor();
        }
      }

      _summary = DashboardSummary(
        totalBalance: calculatedTotalBalance,
        monthIncome: periodIncome,
        monthExpense: periodExpense,
        netCashFlow: periodIncome - periodExpense,
        budgetTotalLimit: budgetTotalLimit,
        budgetTotalSpent: periodExpense,
        goalsTotalTarget: goalsTarget,
        goalsTotalSaved: goalsSaved,
        recentTransactions: recentTransactions,
        accounts: accounts,
        accountBalances: calculatedBalances,
        accountBalanceInfos: calculatedInfos,
        activeGoals: activeGoals,
        topCategories: topCategories,
        weeklySpending: weeklySpending,
        categoryMap: categoryMap,
        period: _selectedPeriod,
        periodLabel: periodLabel,
        dailySpend7Days: dailySpend7Days,
        dailySpend30Days: dailySpend30Days,
        runwayDays: runwayDays,
      );
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
