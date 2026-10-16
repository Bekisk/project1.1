import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/models/goal_contribution.dart';
import 'package:personal_finance/features/savings_goals/services/savings_calculation_service.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:uuid/uuid.dart';

enum GoalSortOption {
  highestPriority,
  targetDate,
  highestProgress,
  lowestProgress,
  recentlyCreated,
}

class SavingsGoalsProvider extends ChangeNotifier {
  List<SavingsGoal> _allGoals = [];
  Map<String, List<GoalContribution>> _contributionsByGoal = {};
  List<Account> _accounts = [];
  Map<String, Account> _accountMap = {};

  GoalStatus? _filterStatus = GoalStatus.active; // null means 'all'
  GoalSortOption _sortOption = GoalSortOption.highestPriority;
  String _searchQuery = '';
  bool _isLoading = true;

  List<SavingsGoal> get allGoals => _allGoals;
  Map<String, List<GoalContribution>> get contributionsByGoal =>
      _contributionsByGoal;
  List<Account> get accounts => _accounts;
  Map<String, Account> get accountMap => _accountMap;
  GoalStatus? get filterStatus => _filterStatus;
  GoalSortOption get sortOption => _sortOption;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  /// Loads all goals, contributions, and accounts from SQLite database
  Future<void> loadGoalsData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load accounts
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      _accounts = accMaps.map((e) => Account.fromMap(e)).toList();
      _accountMap = {for (final a in _accounts) a.id: a};

      // 2. Load all savings goals
      final goalMaps = await db.query(
        'savings_goals',
        orderBy: 'created_at DESC',
      );
      _allGoals = goalMaps.map((e) => SavingsGoal.fromMap(e)).toList();

      // 3. Load all contributions
      final contribMaps = await db.query(
        'goal_contributions',
        orderBy: 'contribution_date DESC, created_at DESC',
      );
      final allContribs = contribMaps
          .map((e) => GoalContribution.fromMap(e))
          .toList();

      _contributionsByGoal = {};
      for (final g in _allGoals) {
        _contributionsByGoal[g.id] = [];
      }
      for (final c in allContribs) {
        if (_contributionsByGoal.containsKey(c.goalId)) {
          _contributionsByGoal[c.goalId]!.add(c);
        } else {
          _contributionsByGoal[c.goalId] = [c];
        }
      }
    } catch (e) {
      debugPrint('Error loading savings goals data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilterStatus(GoalStatus? status) {
    _filterStatus = status;
    notifyListeners();
  }

  void setSortOption(GoalSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Returns contributions for a given goal
  List<GoalContribution> getContributionsForGoal(String goalId) {
    return _contributionsByGoal[goalId] ?? [];
  }

  /// Returns computed GoalProgressSummary for a specific goal
  GoalProgressSummary getSummaryForGoal(SavingsGoal goal) {
    final contribs = getContributionsForGoal(goal.id);
    return SavingsCalculationService.calculateGoalSummary(
      goal: goal,
      contributions: contribs,
    );
  }

  /// Returns overall aggregate savings summary
  OverallSavingsSummary get overallSummary {
    return SavingsCalculationService.calculateOverallSummary(
      _allGoals,
      _contributionsByGoal,
    );
  }

  /// Filtered and sorted goals list
  List<SavingsGoal> get filteredGoals {
    List<SavingsGoal> list = List.from(_allGoals);

    // Filter by status if selected
    if (_filterStatus != null) {
      list = list.where((g) => g.status == _filterStatus).toList();
    }

    // Filter by search query
    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((g) {
        final matchesName = g.name.toLowerCase().contains(query);
        final matchesCat = g.category.toLowerCase().contains(query);
        final matchesDesc = (g.description ?? '').toLowerCase().contains(query);
        return matchesName || matchesCat || matchesDesc;
      }).toList();
    }

    // Sort goals
    list.sort((a, b) {
      switch (_sortOption) {
        case GoalSortOption.highestPriority:
          // high (2) > medium (1) > low (0)
          final pA = a.priority.index;
          final pB = b.priority.index;
          return pB.compareTo(pA);

        case GoalSortOption.targetDate:
          if (a.targetDate == null && b.targetDate == null) return 0;
          if (a.targetDate == null) return 1;
          if (b.targetDate == null) return -1;
          return a.targetDate!.compareTo(b.targetDate!);

        case GoalSortOption.highestProgress:
          final summaryA = getSummaryForGoal(a);
          final summaryB = getSummaryForGoal(b);
          return summaryB.progressPercent.compareTo(summaryA.progressPercent);

        case GoalSortOption.lowestProgress:
          final summaryA = getSummaryForGoal(a);
          final summaryB = getSummaryForGoal(b);
          return summaryA.progressPercent.compareTo(summaryB.progressPercent);

        case GoalSortOption.recentlyCreated:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  /// Create a new Savings Goal
  Future<SavingsGoal?> createGoal({
    required String name,
    required int targetAmount, // in cents
    DateTime? targetDate,
    String? description,
    required String category,
    required String iconKey,
    GoalPriority priority = GoalPriority.medium,
    String? linkedAccountId,
    ContributionPlanFrequency? planFrequency,
    int? plannedPeriodicAmount,
    String? notes,
    int initialContributionAmount = 0, // optional initial contribution in cents
    ContributionMode initialMode = ContributionMode.manual,
    String? sourceAccountId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      const uuid = Uuid();
      final now = DateTime.now();

      final goalId = uuid.v4();
      final goal = SavingsGoal(
        id: goalId,
        name: name.trim(),
        targetAmount: targetAmount,
        targetDate: targetDate,
        description: description?.trim().isEmpty == true
            ? null
            : description?.trim(),
        category: category,
        iconKey: iconKey,
        status: GoalStatus.active,
        priority: priority,
        linkedAccountId: linkedAccountId,
        planFrequency: planFrequency,
        plannedPeriodicAmount: plannedPeriodicAmount,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('savings_goals', goal.toMap());

      // If initial contribution was provided, record it
      if (initialContributionAmount > 0) {
        await addContribution(
          goalId: goalId,
          amount: initialContributionAmount,
          contributionDate: now,
          mode: initialMode,
          sourceAccountId: sourceAccountId,
          destinationAccountId: linkedAccountId,
          notes: 'Initial contribution',
          suppressReload: true,
        );
      }

      await loadGoalsData();
      return goal;
    } catch (e) {
      debugPrint('Error creating savings goal: $e');
      return null;
    }
  }

  /// Update an existing Savings Goal
  Future<bool> updateGoal(SavingsGoal goal) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // Check if target was reduced below saved amount to automatically update completion state
      final contribs = getContributionsForGoal(goal.id);
      final totalSaved = SavingsCalculationService.calculateTotalSaved(
        contribs,
      );

      GoalStatus status = goal.status;
      DateTime? completedAt = goal.completedAt;
      if (totalSaved >= goal.targetAmount && goal.targetAmount > 0) {
        if (status == GoalStatus.active) {
          status = GoalStatus.completed;
          completedAt = completedAt ?? now;
        }
      } else if (status == GoalStatus.completed &&
          totalSaved < goal.targetAmount) {
        // If target was increased above saved amount, reopen to active
        status = GoalStatus.active;
        completedAt = null;
      }

      final updatedGoal = goal.copyWith(
        status: status,
        completedAt: completedAt,
        updatedAt: now,
      );

      final count = await db.update(
        'savings_goals',
        updatedGoal.toMap(),
        where: 'id = ?',
        whereArgs: [goal.id],
      );

      if (count > 0) {
        await loadGoalsData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating savings goal: $e');
      return false;
    }
  }

  /// Change Goal status (pause, resume, archive, complete)
  Future<bool> setGoalStatus(String goalId, GoalStatus newStatus) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      final current = _allGoals.firstWhere((g) => g.id == goalId);
      final updated = current.copyWith(
        status: newStatus,
        completedAt: newStatus == GoalStatus.completed
            ? (current.completedAt ?? now)
            : (newStatus == GoalStatus.active ? null : current.completedAt),
        clearCompletedAt: newStatus == GoalStatus.active,
        updatedAt: now,
      );

      final count = await db.update(
        'savings_goals',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [goalId],
      );

      if (count > 0) {
        await loadGoalsData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error changing goal status: $e');
      return false;
    }
  }

  /// Delete a goal safely. Reconciles any linked transfer transactions without corrupting account balances.
  Future<bool> deleteGoal(String goalId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Note: Foreign keys ON will cascade delete goal_contributions.
      // But if any contribution had an associated transfer_transaction_id, we keep or remove the transaction as appropriate.
      // The requirement states: "Deleting a goal must not silently delete unrelated account transactions or historical financial records."
      // Foreign key SET NULL handles `transfer_transaction_id` safely.
      final count = await db.delete(
        'savings_goals',
        where: 'id = ?',
        whereArgs: [goalId],
      );

      if (count > 0) {
        await loadGoalsData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting savings goal: $e');
      return false;
    }
  }

  /// Add Contribution with support for manual earmark or internal transfer
  Future<GoalContribution?> addContribution({
    required String goalId,
    required int amount, // in cents
    required DateTime contributionDate,
    required ContributionMode mode,
    String? sourceAccountId,
    String? destinationAccountId,
    String? notes,
    bool suppressReload = false,
  }) async {
    if (amount <= 0) return null;

    try {
      final db = await DatabaseHelper.instance.database;
      const uuid = Uuid();
      final now = DateTime.now();
      final contributionId = uuid.v4();

      String? transferTxId;

      // If mode is account transfer, create an actual internal transfer transaction
      if (mode == ContributionMode.accountTransfer &&
          sourceAccountId != null &&
          destinationAccountId != null) {
        transferTxId = uuid.v4();
        final transferTx = FinancialTransaction(
          id: transferTxId,
          accountId: sourceAccountId,
          destinationAccountId: destinationAccountId,
          type: TransactionType.transfer,
          amount: amount,
          categoryId:
              null, // transfers don't count toward income/expense categories
          description: 'Savings Goal Transfer',
          notes: notes,
          transactionDate: contributionDate,
          createdAt: now,
          updatedAt: now,
        );

        await db.insert('transactions', transferTx.toMap());
      }

      final contribution = GoalContribution(
        id: contributionId,
        goalId: goalId,
        amount: amount,
        contributionDate: contributionDate,
        mode: mode,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        transferTransactionId: transferTxId,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await db.insert('goal_contributions', contribution.toMap());

      // Check if goal reached completion with this contribution
      final currentGoal = _allGoals.firstWhere((g) => g.id == goalId);
      final existingContribs = getContributionsForGoal(goalId);
      final newTotalSaved =
          SavingsCalculationService.calculateTotalSaved(existingContribs) +
          amount;

      if (newTotalSaved >= currentGoal.targetAmount &&
          currentGoal.targetAmount > 0) {
        if (currentGoal.status == GoalStatus.active) {
          await db.update(
            'savings_goals',
            {
              'status': GoalStatus.completed.name,
              'completed_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [goalId],
          );
        }
      }

      if (!suppressReload) {
        await loadGoalsData();
      }
      return contribution;
    } catch (e) {
      debugPrint('Error adding contribution: $e');
      return null;
    }
  }

  /// Edit an existing contribution with balance reconciliation
  Future<bool> editContribution({
    required GoalContribution contribution,
    required int newAmount,
    required DateTime newDate,
    String? newNotes,
  }) async {
    if (newAmount <= 0) return false;

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // If there is an associated transfer transaction, update its amount & date too
      if (contribution.transferTransactionId != null) {
        await db.update(
          'transactions',
          {
            'amount': newAmount,
            'transaction_date': newDate.toIso8601String(),
            'notes': newNotes,
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [contribution.transferTransactionId],
        );
      }

      final updatedContrib = contribution.copyWith(
        amount: newAmount,
        contributionDate: newDate,
        notes: newNotes,
        updatedAt: now,
      );

      await db.update(
        'goal_contributions',
        updatedContrib.toMap(),
        where: 'id = ?',
        whereArgs: [contribution.id],
      );

      await loadGoalsData();
      return true;
    } catch (e) {
      debugPrint('Error editing contribution: $e');
      return false;
    }
  }

  /// Delete a contribution with proper reconciliation of any linked transfer transaction
  Future<bool> deleteContribution(GoalContribution contribution) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // If there was a linked transfer transaction, delete it so account balances reconcile
      if (contribution.transferTransactionId != null) {
        await db.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: [contribution.transferTransactionId],
        );
      }

      final count = await db.delete(
        'goal_contributions',
        where: 'id = ?',
        whereArgs: [contribution.id],
      );

      if (count > 0) {
        // Re-evaluate goal completion status
        final currentGoal = _allGoals.firstWhere(
          (g) => g.id == contribution.goalId,
        );
        final remainingContribs = getContributionsForGoal(contribution.goalId)
            .where((c) => c.id != contribution.id)
            .toList();
        final newTotal = SavingsCalculationService.calculateTotalSaved(
          remainingContribs,
        );

        if (currentGoal.status == GoalStatus.completed &&
            newTotal < currentGoal.targetAmount) {
          await db.update(
            'savings_goals',
            {
              'status': GoalStatus.active.name,
              'completed_at': null,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [contribution.goalId],
          );
        }

        await loadGoalsData();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting contribution: $e');
      return false;
    }
  }
}
