import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/debts/models/debt.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:uuid/uuid.dart';

class DebtsProvider extends ChangeNotifier {
  List<Debt> _debts = [];
  bool _isLoading = true;

  List<Debt> get debts => _debts;
  bool get isLoading => _isLoading;

  List<Debt> get debtsIOwe => _debts.where((d) => d.type == DebtType.iOwe).toList();
  List<Debt> get debtsOwedToMe => _debts.where((d) => d.type == DebtType.owesMe).toList();

  int get totalIOweCents => debtsIOwe
      .where((d) => d.status != DebtStatus.settled)
      .fold(0, (sum, d) => sum + d.remainingAmount);

  int get totalOwedToMeCents => debtsOwedToMe
      .where((d) => d.status != DebtStatus.settled)
      .fold(0, (sum, d) => sum + d.remainingAmount);

  int get netDebtBalanceCents => totalOwedToMeCents - totalIOweCents;

  Future<void> loadDebts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query('debts', orderBy: 'created_at DESC');
      _debts = maps.map((m) => Debt.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error loading debts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebt(Debt debt) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('debts', debt.toMap());
      await loadDebts();
      return true;
    } catch (e) {
      debugPrint('Error adding debt: $e');
      return false;
    }
  }

  Future<bool> updateDebt(Debt debt) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('debts', debt.toMap(), where: 'id = ?', whereArgs: [debt.id]);
      await loadDebts();
      return true;
    } catch (e) {
      debugPrint('Error updating debt: $e');
      return false;
    }
  }

  Future<bool> deleteDebt(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('debts', where: 'id = ?', whereArgs: [id]);
      await loadDebts();
      return true;
    } catch (e) {
      debugPrint('Error deleting debt: $e');
      return false;
    }
  }

  /// Settlement Handler:
  /// When a debt is settled or partially repaid:
  /// 1. Updates debt's settled_amount and status in SQLite.
  /// 2. If a wallet is linked (or specified), automatically generates a corresponding
  ///    Income (if OWES_ME was received) or Expense (if I_OWE was paid) transaction
  ///    to ensure net worth balances in real time.
  Future<bool> settleDebt({
    required Debt debt,
    required int settleAmountCents,
    String? walletId,
    DateTime? settlementDate,
    String? note,
  }) async {
    if (settleAmountCents <= 0) return false;

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final date = settlementDate ?? now;
      final newSettledTotal = debt.settledAmount + settleAmountCents;
      final isFullySettled = newSettledTotal >= debt.totalAmount;
      final newStatus = isFullySettled ? DebtStatus.settled : DebtStatus.partial;

      // 1. Update Debt record
      await db.update(
        'debts',
        {
          'settled_amount': newSettledTotal,
          'status': newStatus.name.toUpperCase(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );

      // 2. Insert into debt_repayments
      final repaymentId = const Uuid().v4();
      final targetWalletId = walletId ?? debt.linkedWalletId;
      String? txId;

      // 3. Balance Net Worth: Automatically create corresponding Income or Expense transaction
      if (targetWalletId != null && targetWalletId.isNotEmpty) {
        txId = const Uuid().v4();
        final isIncome = debt.type == DebtType.owesMe;
        final tx = FinancialTransaction(
          id: txId,
          accountId: targetWalletId,
          destinationAccountId: null,
          type: isIncome ? TransactionType.income : TransactionType.expense,
          amount: settleAmountCents,
          categoryId: null,
          description: isIncome
              ? 'Debt Repaid by ${debt.personName}'
              : 'Debt Payment to ${debt.personName}',
          notes: note ?? 'IOU settlement record',
          transactionDate: date,
          createdAt: now,
          updatedAt: now,
        );
        await db.insert('transactions', tx.toMap());
      }

      await db.insert('debt_repayments', {
        'id': repaymentId,
        'debt_id': debt.id,
        'amount': settleAmountCents,
        'repayment_date': date.toIso8601String(),
        'account_id': targetWalletId,
        'transaction_id': txId,
        'notes': note,
        'created_at': now.toIso8601String(),
      });

      await loadDebts();
      return true;
    } catch (e) {
      debugPrint('Error settling debt: $e');
      return false;
    }
  }
}
