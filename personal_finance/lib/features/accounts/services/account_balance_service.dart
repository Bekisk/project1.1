import 'package:flutter/foundation.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:sqflite/sqflite.dart';

/// Status of an account's balance relative to bank-reported balances.
enum AccountBalanceStatus {
  /// Calculated from ledger without a bank snapshot
  calculated,

  /// Exactly matches the latest bank-reported snapshot
  confirmed,

  /// A discrepancy exists between calculated balance and bank-reported snapshot
  discrepancy,

  /// Account starting balance is unconfirmed and needs user baseline setup
  unconfirmedBaseline,
}

class AccountBalanceInfo {
  final Account account;
  final int calculatedBalance; // in cents
  final int? bankReportedBalance; // in cents
  final DateTime? lastConfirmedAt;
  final AccountBalanceStatus status;
  final int discrepancyCents; // bankReportedBalance - calculatedBalance

  const AccountBalanceInfo({
    required this.account,
    required this.calculatedBalance,
    this.bankReportedBalance,
    this.lastConfirmedAt,
    required this.status,
    this.discrepancyCents = 0,
  });

  bool get hasDiscrepancy => status == AccountBalanceStatus.discrepancy;
  bool get isConfirmed => status == AccountBalanceStatus.confirmed;
  bool get needsBaselineSetup =>
      status == AccountBalanceStatus.unconfirmedBaseline;
}

class AccountBalanceService {
  AccountBalanceService._();
  static final AccountBalanceService instance = AccountBalanceService._();

  /// Calculates the ledger balance for a given account.
  /// Equation: Opening balance + income - expenses - transfersOut + transfersIn.
  /// If [asOfDate] is provided, only transactions up to that date are counted.
  Future<int> calculateLedgerBalance(
    String accountId, {
    DatabaseExecutor? executor,
    DateTime? asOfDate,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;

    // Get opening balance
    final accRows = await db.query(
      'accounts',
      columns: ['opening_balance'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (accRows.isEmpty) return 0;
    final opening = (accRows.first['opening_balance'] as int?) ?? 0;

    String dateClause = '';
    List<dynamic> incomeArgs = [accountId];
    List<dynamic> expenseArgs = [accountId];
    List<dynamic> transferOutArgs = [accountId];
    List<dynamic> transferInArgs = [accountId];

    if (asOfDate != null) {
      final iso = asOfDate.toIso8601String();
      dateClause = ' AND transaction_date <= ?';
      incomeArgs.add(iso);
      expenseArgs.add(iso);
      transferOutArgs.add(iso);
      transferInArgs.add(iso);
    }

    final incomeRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'income'$dateClause",
      incomeArgs,
    );
    final income = (incomeRes.first['total'] as int?) ?? 0;

    final expenseRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'expense'$dateClause",
      expenseArgs,
    );
    final expense = (expenseRes.first['total'] as int?) ?? 0;

    final transferOutRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'transfer'$dateClause",
      transferOutArgs,
    );
    final transferOut = (transferOutRes.first['total'] as int?) ?? 0;

    final transferInRes = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE destination_account_id = ? AND type = 'transfer'$dateClause",
      transferInArgs,
    );
    final transferIn = (transferInRes.first['total'] as int?) ?? 0;

    return opening + income - expense - transferOut + transferIn;
  }

  /// Fetches the comprehensive balance information for an account.
  Future<AccountBalanceInfo> getAccountBalanceInfo(
    Account account, {
    DatabaseExecutor? executor,
  }) async {
    final calculated = await calculateLedgerBalance(
      account.id,
      executor: executor,
    );

    if (!account.hasConfirmedStartingBalance) {
      return AccountBalanceInfo(
        account: account,
        calculatedBalance: calculated,
        bankReportedBalance: account.lastConfirmedBalance,
        lastConfirmedAt: account.lastConfirmedAt,
        status: AccountBalanceStatus.unconfirmedBaseline,
      );
    }

    if (account.lastConfirmedBalance == null) {
      return AccountBalanceInfo(
        account: account,
        calculatedBalance: calculated,
        status: AccountBalanceStatus.calculated,
      );
    }

    final reported = account.lastConfirmedBalance!;
    final discrepancy = reported - calculated;

    AccountBalanceStatus status;
    if (discrepancy == 0) {
      status = AccountBalanceStatus.confirmed;
    } else {
      status = AccountBalanceStatus.discrepancy;
    }

    return AccountBalanceInfo(
      account: account,
      calculatedBalance: calculated,
      bankReportedBalance: reported,
      lastConfirmedAt: account.lastConfirmedAt,
      status: status,
      discrepancyCents: discrepancy,
    );
  }

  /// Safe Bank-Reported Balance Reconciliation.
  ///
  /// Guarantees:
  /// 1. Out-of-order protection: An older snapshot will NEVER overwrite a newer confirmed snapshot.
  /// 2. If the account had no confirmed baseline, uses this snapshot to establish the baseline accurately:
  ///    openingBalance = reportedBalance - (sum_credits - sum_debits).
  /// 3. Never blindly overwrites or adds the reported balance to the transaction ledger.
  /// 4. Updates `last_confirmed_balance` and `last_confirmed_at` atomically.
  Future<bool> reconcileBankReportedBalance({
    required String accountId,
    required int reportedBalanceCents,
    required DateTime snapshotTime,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await DatabaseHelper.instance.database;

    final accRows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (accRows.isEmpty) return false;

    final account = Account.fromMap(accRows.first);

    // Guard: Prevent stale/out-of-order snapshots from overwriting newer snapshots
    if (account.lastConfirmedAt != null &&
        snapshotTime.isBefore(account.lastConfirmedAt!)) {
      debugPrint(
        'Reconciliation skipped: snapshot from $snapshotTime is older than last confirmed at ${account.lastConfirmedAt}',
      );
      return false;
    }

    // Baseline establishment: If account did not have a confirmed baseline yet,
    // we calculate net transaction movement and set openingBalance = reported - netMovement
    if (!account.hasConfirmedStartingBalance) {
      // Calculate net transactions in the account currently
      final incomeRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'income'",
        [accountId],
      );
      final income = (incomeRes.first['total'] as int?) ?? 0;

      final expenseRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'expense'",
        [accountId],
      );
      final expense = (expenseRes.first['total'] as int?) ?? 0;

      final transferOutRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'transfer'",
        [accountId],
      );
      final transferOut = (transferOutRes.first['total'] as int?) ?? 0;

      final transferInRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE destination_account_id = ? AND type = 'transfer'",
        [accountId],
      );
      final transferIn = (transferInRes.first['total'] as int?) ?? 0;

      final netMovement = income - expense - transferOut + transferIn;
      final establishedOpening = reportedBalanceCents - netMovement;

      await db.update(
        'accounts',
        {
          'opening_balance': establishedOpening,
          'has_confirmed_starting_balance': 1,
          'last_confirmed_balance': reportedBalanceCents,
          'last_confirmed_at': snapshotTime.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );
      return true;
    }

    // Normal reconciliation snapshot update
    await db.update(
      'accounts',
      {
        'last_confirmed_balance': reportedBalanceCents,
        'last_confirmed_at': snapshotTime.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );

    return true;
  }
}
