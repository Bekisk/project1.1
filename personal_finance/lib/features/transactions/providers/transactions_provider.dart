import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

enum DateRangePreset {
  allTime,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  last30Days,
  custom,
}

class TransactionFilterState {
  final TransactionType? type; // null = all
  final DateRangePreset datePreset;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? accountId; // null = all accounts
  final String? categoryId; // null = all categories
  final int? minAmountCents;
  final int? maxAmountCents;
  final String searchQuery;

  const TransactionFilterState({
    this.type,
    this.datePreset = DateRangePreset.thisMonth,
    this.customStartDate,
    this.customEndDate,
    this.accountId,
    this.categoryId,
    this.minAmountCents,
    this.maxAmountCents,
    this.searchQuery = '',
  });

  TransactionFilterState copyWith({
    TransactionType? type,
    bool clearType = false,
    DateRangePreset? datePreset,
    DateTime? customStartDate,
    DateTime? customEndDate,
    bool clearCustomDates = false,
    String? accountId,
    bool clearAccountId = false,
    String? categoryId,
    bool clearCategoryId = false,
    int? minAmountCents,
    bool clearMinAmount = false,
    int? maxAmountCents,
    bool clearMaxAmount = false,
    String? searchQuery,
  }) {
    return TransactionFilterState(
      type: clearType ? null : (type ?? this.type),
      datePreset: datePreset ?? this.datePreset,
      customStartDate: clearCustomDates ? null : (customStartDate ?? this.customStartDate),
      customEndDate: clearCustomDates ? null : (customEndDate ?? this.customEndDate),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      minAmountCents: clearMinAmount ? null : (minAmountCents ?? this.minAmountCents),
      maxAmountCents: clearMaxAmount ? null : (maxAmountCents ?? this.maxAmountCents),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (type != null) count++;
    if (datePreset != DateRangePreset.thisMonth && datePreset != DateRangePreset.allTime) count++;
    if (accountId != null) count++;
    if (categoryId != null) count++;
    if (minAmountCents != null || maxAmountCents != null) count++;
    if (searchQuery.trim().isNotEmpty) count++;
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;
}

class TransactionsProvider extends ChangeNotifier {
  List<FinancialTransaction> _allTransactions = [];
  List<Account> _accounts = [];
  List<Category> _categories = [];
  Map<String, Account> _accountMap = {};
  Map<String, Category> _categoryMap = {};

  TransactionFilterState _filter = const TransactionFilterState();
  bool _isLoading = true;

  List<FinancialTransaction> get allTransactions => _allTransactions;
  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  Map<String, Account> get accountMap => _accountMap;
  Map<String, Category> get categoryMap => _categoryMap;
  TransactionFilterState get filter => _filter;
  bool get isLoading => _isLoading;

  /// Loads accounts, categories, and all transactions from local SQLite database
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch accounts
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      _accounts = accMaps.map((e) => Account.fromMap(e)).toList();
      _accountMap = {for (final a in _accounts) a.id: a};

      // 2. Fetch categories
      final catMaps = await db.query('categories', where: 'is_archived = 0');
      _categories = catMaps.map((e) => Category.fromMap(e)).toList();
      _categoryMap = {for (final c in _categories) c.id: c};

      // 3. Fetch all transactions ordered by transaction_date DESC, created_at DESC
      final txMaps = await db.query(
        'transactions',
        orderBy: 'transaction_date DESC, created_at DESC',
      );
      _allTransactions = txMaps.map((e) => FinancialTransaction.fromMap(e)).toList();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(TransactionFilterState newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  void setTransactionType(TransactionType? type) {
    _filter = _filter.copyWith(type: type, clearType: type == null);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _filter = _filter.copyWith(searchQuery: query);
    notifyListeners();
  }

  void resetFilters() {
    _filter = const TransactionFilterState();
    notifyListeners();
  }

  /// Calculates boundary dates [start, end] in local timezone for date presets
  (DateTime?, DateTime?) _resolveDateRange(DateRangePreset preset, DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (preset) {
      case DateRangePreset.allTime:
        return (null, null);
      case DateRangePreset.today:
        return (todayStart, todayEnd);
      case DateRangePreset.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59, 999);
        return (yStart, yEnd);
      case DateRangePreset.thisWeek:
        // Week starting Monday
        final weekday = now.weekday; // 1 = Monday
        final weekStart = todayStart.subtract(Duration(days: weekday - 1));
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6, 23, 59, 59, 999);
        return (weekStart, weekEnd);
      case DateRangePreset.thisMonth:
        final mStart = DateTime(now.year, now.month, 1);
        final nextM = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        final mEnd = nextM.subtract(const Duration(milliseconds: 1));
        return (mStart, mEnd);
      case DateRangePreset.lastMonth:
        final lastMYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMMonth = now.month == 1 ? 12 : now.month - 1;
        final lmStart = DateTime(lastMYear, lastMMonth, 1);
        final thisM = DateTime(now.year, now.month, 1);
        final lmEnd = thisM.subtract(const Duration(milliseconds: 1));
        return (lmStart, lmEnd);
      case DateRangePreset.last30Days:
        final start30 = todayStart.subtract(const Duration(days: 29));
        return (start30, todayEnd);
      case DateRangePreset.custom:
        if (customStart == null && customEnd == null) return (null, null);
        final cStart = customStart != null ? DateTime(customStart.year, customStart.month, customStart.day) : null;
        final cEnd = customEnd != null
            ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999)
            : null;
        return (cStart, cEnd);
    }
  }

  /// Filters transactions based on current filter state
  List<FinancialTransaction> get filteredTransactions {
    final (startDate, endDate) = _resolveDateRange(
      _filter.datePreset,
      _filter.customStartDate,
      _filter.customEndDate,
    );

    final query = _filter.searchQuery.trim().toLowerCase();

    return _allTransactions.where((tx) {
      // 1. Transaction Type filter
      if (_filter.type != null && tx.type != _filter.type) {
        return false;
      }

      // 2. Date Range filter (inclusive)
      if (startDate != null && tx.transactionDate.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && tx.transactionDate.isAfter(endDate)) {
        return false;
      }

      // 3. Account Filter: For transfers, match if account is either source or destination!
      if (_filter.accountId != null) {
        final matchesSource = tx.accountId == _filter.accountId;
        final matchesDest = tx.destinationAccountId == _filter.accountId;
        if (!matchesSource && !matchesDest) {
          return false;
        }
      }

      // 4. Category Filter
      if (_filter.categoryId != null) {
        if (tx.categoryId != _filter.categoryId) {
          return false;
        }
      }

      // 5. Amount Range
      if (_filter.minAmountCents != null && tx.amount < _filter.minAmountCents!) {
        return false;
      }
      if (_filter.maxAmountCents != null && tx.amount > _filter.maxAmountCents!) {
        return false;
      }

      // 6. Search query
      if (query.isNotEmpty) {
        final desc = tx.description.toLowerCase();
        final notes = (tx.notes ?? '').toLowerCase();
        final cat = tx.categoryId != null ? (_categoryMap[tx.categoryId]?.name.toLowerCase() ?? '') : '';
        final acc = _accountMap[tx.accountId]?.name.toLowerCase() ?? '';
        final destAcc = tx.destinationAccountId != null
            ? (_accountMap[tx.destinationAccountId]?.name.toLowerCase() ?? '')
            : '';

        final matches = desc.contains(query) ||
            notes.contains(query) ||
            cat.contains(query) ||
            acc.contains(query) ||
            destAcc.contains(query);

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /// Calculated totals for the filtered results (or selected period)
  /// Crucial rule: Transfers are NOT counted in income or expenses.
  int get filteredTotalIncome {
    return filteredTransactions
        .where((tx) => tx.type == TransactionType.income)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  int get filteredTotalExpense {
    return filteredTransactions
        .where((tx) => tx.type == TransactionType.expense)
        .fold(0, (sum, tx) => sum + tx.amount);
  }

  int get filteredNetCashFlow => filteredTotalIncome - filteredTotalExpense;

  /// Groups the filtered transactions by local calendar date (descending)
  Map<DateTime, List<FinancialTransaction>> get groupedTransactionsByDate {
    final list = filteredTransactions;
    final Map<DateTime, List<FinancialTransaction>> groups = {};

    for (final tx in list) {
      // Normalize to calendar day (midnight in local timezone)
      final localDate = tx.transactionDate.toLocal();
      final dayKey = DateTime(localDate.year, localDate.month, localDate.day);
      if (!groups.containsKey(dayKey)) {
        groups[dayKey] = [];
      }
      groups[dayKey]!.add(tx);
    }

    return groups;
  }

  /// Deletes a transaction persistently from SQLite database
  Future<bool> deleteTransaction(String transactionId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = await db.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (count > 0) {
        await loadTransactions();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      return false;
    }
  }

  /// Updates an existing transaction persistently in SQLite database
  Future<bool> updateTransaction(FinancialTransaction transaction) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final count = await db.update(
        'transactions',
        transaction.toMap(),
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      if (count > 0) {
        await loadTransactions();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      return false;
    }
  }

  /// Inserts a new transaction persistently in SQLite database
  Future<bool> insertTransaction(FinancialTransaction transaction) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('transactions', transaction.toMap());
      await loadTransactions();
      return true;
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      return false;
    }
  }
}
