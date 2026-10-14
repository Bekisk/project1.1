import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/recurring/models/recurring_schedule.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:uuid/uuid.dart';

class RecurringProvider extends ChangeNotifier {
  List<RecurringSchedule> _schedules = [];
  bool _isLoading = true;

  List<RecurringSchedule> get schedules => _schedules;
  bool get isLoading => _isLoading;

  List<RecurringSchedule> get activeExpenses =>
      _schedules.where((s) => s.isActive && s.type == 'expense').toList();

  /// Total monthly commitment in cents (e.g. Monthly Fixed Costs: $45.00 / Month)
  int get totalMonthlyCommitmentCents {
    return activeExpenses.fold(0, (sum, s) => sum + s.monthlyCostCents);
  }

  Future<void> loadSchedules() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query('recurring_schedules', orderBy: 'created_at DESC');
      _schedules = maps.map((m) => RecurringSchedule.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading recurring schedules: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Automated Background / App Start Trigger:
  /// Evaluates all active schedules. If nextOccurrence <= now and not yet processed,
  /// auto-injects a transaction into SQLite transactions ledger and advances nextOccurrence.
  Future<int> processDueRecurringTransactions() async {
    int injectedCount = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final maps = await db.query(
        'recurring_schedules',
        where: 'is_active = 1 OR is_enabled = 1',
      );
      final activeList = maps.map((m) => RecurringSchedule.fromMap(m)).toList();

      for (final schedule in activeList) {
        // If next occurrence has arrived
        if (!schedule.nextOccurrence.isAfter(now)) {
          // Check if already injected today
          if (schedule.lastProcessedDate != null &&
              schedule.lastProcessedDate!.year == now.year &&
              schedule.lastProcessedDate!.month == now.month &&
              schedule.lastProcessedDate!.day == now.day) {
            continue;
          }

          // Inject transaction
          final txId = const Uuid().v4();
          final isExpense = schedule.type == 'expense';
          final tx = FinancialTransaction(
            id: txId,
            accountId: schedule.accountId,
            destinationAccountId: null,
            type: isExpense ? TransactionType.expense : TransactionType.income,
            amount: schedule.amount,
            categoryId: schedule.categoryId,
            description: schedule.name,
            notes: 'Auto-executed recurring subscription. ${schedule.frequencyLabel}',
            transactionDate: schedule.nextOccurrence,
            recurringScheduleId: schedule.id,
            createdAt: now,
            updatedAt: now,
          );
          await db.insert('transactions', tx.toMap());

          // Advance next occurrence
          final nextDate = _calculateNextOccurrence(schedule.nextOccurrence, schedule.frequency);
          await db.update(
            'recurring_schedules',
            {
              'next_occurrence': nextDate.toIso8601String(),
              'last_processed_date': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [schedule.id],
          );

          injectedCount++;
        }
      }

      if (injectedCount > 0) {
        await loadSchedules();
      }
    } catch (e) {
      debugPrint('Error processing recurring schedules: $e');
    }
    return injectedCount;
  }

  DateTime _calculateNextOccurrence(DateTime current, RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.weekly:
        return current.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        final nextMonth = current.month == 12 ? 1 : current.month + 1;
        final nextYear = current.month == 12 ? current.year + 1 : current.year;
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final day = current.day > daysInNextMonth ? daysInNextMonth : current.day;
        return DateTime(nextYear, nextMonth, day, current.hour, current.minute);
      case RecurringFrequency.yearly:
        return DateTime(current.year + 1, current.month, current.day, current.hour, current.minute);
    }
  }

  Future<bool> addSchedule(RecurringSchedule schedule) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('recurring_schedules', schedule.toMap());
      await loadSchedules();
      return true;
    } catch (e) {
      debugPrint('Error adding recurring schedule: $e');
      return false;
    }
  }

  Future<bool> updateSchedule(RecurringSchedule schedule) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('recurring_schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
      await loadSchedules();
      return true;
    } catch (e) {
      debugPrint('Error updating recurring schedule: $e');
      return false;
    }
  }

  Future<bool> deleteSchedule(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('recurring_schedules', where: 'id = ?', whereArgs: [id]);
      await loadSchedules();
      return true;
    } catch (e) {
      debugPrint('Error deleting recurring schedule: $e');
      return false;
    }
  }

  Future<bool> toggleActive(RecurringSchedule schedule) async {
    final updated = schedule.copyWith(
      isActive: !schedule.isActive,
      updatedAt: DateTime.now(),
    );
    return updateSchedule(updated);
  }
}
