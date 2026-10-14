import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/budgets/services/budget_calculation_service.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

enum BudgetPeriodFilter {
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  custom,
}

class BudgetsProvider extends ChangeNotifier {
  List<Budget> _budgets = [];
  List<FinancialTransaction> _transactions = [];
  List<Category> _categories = [];
  List<Account> _accounts = [];
  Map<String, Category> _categoryMap = {};
  Map<String, Account> _accountMap = {};

  BudgetPeriodFilter _selectedPeriod = BudgetPeriodFilter.thisMonth;
  DateTime? _customPeriodStart;
  DateTime? _customPeriodEnd;

  bool _isLoading = true;

  List<Budget> get budgets => _budgets;
  List<Category> get categories => _categories;
  List<Account> get accounts => _accounts;
  Map<String, Category> get categoryMap => _categoryMap;
  Map<String, Account> get accountMap => _accountMap;
  BudgetPeriodFilter get selectedPeriod => _selectedPeriod;
  DateTime? get customPeriodStart => _customPeriodStart;
  DateTime? get customPeriodEnd => _customPeriodEnd;
  bool get isLoading => _isLoading;

  Future<void> loadBudgetData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load categories
      final catMaps = await db.query('categories', where: 'is_archived = 0');
      _categories = catMaps.map((e) => Category.fromMap(e)).toList();
      _categoryMap = {for (final c in _categories) c.id: c};

      // 2. Load accounts
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      _accounts = accMaps.map((e) => Account.fromMap(e)).toList();
      _accountMap = {for (final a in _accounts) a.id: a};

      // 3. Load transactions
      final txMaps = await db.query('transactions', orderBy: 'transaction_date DESC');
      _transactions = txMaps.map((e) => FinancialTransaction.fromMap(e)).toList();

      // 4. Load budgets
      final budgetMaps = await db.query('budgets', where: 'is_archived = 0');
      _budgets = budgetMaps.map((e) => Budget.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error loading budget data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPeriodFilter(BudgetPeriodFilter filter, {DateTime? customStart, DateTime? customEnd}) {
    _selectedPeriod = filter;
    _customPeriodStart = customStart;
    _customPeriodEnd = customEnd;
    notifyListeners();
  }

  /// Calculates the active date range boundaries based on the selected period
  (DateTime, DateTime) getActivePeriodDates() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case BudgetPeriodFilter.thisWeek:
        final weekday = now.weekday; // 1 = Monday
        final weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59, 999);
        return (weekStart, weekEnd);
      case BudgetPeriodFilter.thisMonth:
        final mStart = DateTime(now.year, now.month, 1);
        final nextM = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        final mEnd = nextM.subtract(const Duration(milliseconds: 1));
        return (mStart, mEnd);
      case BudgetPeriodFilter.lastMonth:
        final lastYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lmStart = DateTime(lastYear, lastMonth, 1);
        final thisM = DateTime(now.year, now.month, 1);
        final lmEnd = thisM.subtract(const Duration(milliseconds: 1));
        return (lmStart, lmEnd);
      case BudgetPeriodFilter.thisYear:
        final yStart = DateTime(now.year, 1, 1);
        final yEnd = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return (yStart, yEnd);
      case BudgetPeriodFilter.custom:
        if (_customPeriodStart != null && _customPeriodEnd != null) {
          return (
            DateTime(_customPeriodStart!.year, _customPeriodStart!.month, _customPeriodStart!.day),
            DateTime(_customPeriodEnd!.year, _customPeriodEnd!.month, _customPeriodEnd!.day, 23, 59, 59, 999),
          );
        }
        // Fallback to this month
        final mStart = DateTime(now.year, now.month, 1);
        final nextM = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        return (mStart, nextM.subtract(const Duration(milliseconds: 1)));
    }
  }

  /// Returns budgets applicable to the currently selected active period
  List<Budget> get filteredBudgetsForActivePeriod {
    final (periodStart, periodEnd) = getActivePeriodDates();

    return _budgets.where((b) {
      if (b.isArchived) return false;

      // If budget has overlapping dates with the selected period
      final bStart = b.periodStart.toLocal();
      final bEnd = b.periodEnd.toLocal();

      final overlaps = !(bEnd.isBefore(periodStart) || bStart.isAfter(periodEnd));
      return overlaps;
    }).toList();
  }

  /// Computes overall budget summary using the calculation service
  OverallBudgetSummary get overallSummary {
    return BudgetCalculationService.calculateOverallSummary(
      budgets: filteredBudgetsForActivePeriod,
      transactions: _transactions,
      categoryMap: _categoryMap,
    );
  }

  /// Calculates single budget progress with contributing transactions
  BudgetCalculationResult calculateSingleBudget(Budget budget) {
    final cat = budget.categoryId != null ? _categoryMap[budget.categoryId] : null;
    return BudgetCalculationService.calculateBudgetProgress(
      budget: budget,
      transactions: _transactions,
      category: cat,
    );
  }

  /// CRUD operations with SQLite persistence
  Future<bool> saveBudget(Budget budget, {bool isEditing = false}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      if (isEditing) {
        await db.update(
          'budgets',
          budget.toMap(),
          where: 'id = ?',
          whereArgs: [budget.id],
        );
      } else {
        await db.insert('budgets', budget.toMap());
      }
      await loadBudgetData();
      return true;
    } catch (e) {
      debugPrint('Error saving budget: $e');
      return false;
    }
  }

  Future<bool> deleteBudget(String budgetId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = await db.delete('budgets', where: 'id = ?', whereArgs: [budgetId]);
      if (count > 0) {
        await loadBudgetData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting budget: $e');
      return false;
    }
  }

  Future<bool> archiveBudget(String budgetId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'budgets',
        {'is_archived': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [budgetId],
      );
      await loadBudgetData();
      return true;
    } catch (e) {
      debugPrint('Error archiving budget: $e');
      return false;
    }
  }
}
