import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';

class DataBackupService {
  /// Exports all financial data (accounts, categories, transactions, budgets, goals, contributions) as a formatted JSON string
  static Future<String> exportFinancialDataAsJson() async {
    final db = await DatabaseHelper.instance.database;

    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final transactions = await db.query('transactions');
    final budgets = await db.query('budgets');
    final goals = await db.query('savings_goals');
    final contributions = await db.query('goal_contributions');

    final exportMap = {
      'app': 'My Finance Personal Finance Manager',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'budgets': budgets,
        'savings_goals': goals,
        'goal_contributions': contributions,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  /// Exports transactions as CSV text
  static Future<String> exportTransactionsAsCsv() async {
    final db = await DatabaseHelper.instance.database;
    final transactions = await db.rawQuery('''
      SELECT t.id, t.transaction_date, t.type, t.amount, t.description, t.notes,
             a.name as account_name,
             da.name as dest_account_name,
             c.name as category_name
      FROM transactions t
      LEFT JOIN accounts a ON t.account_id = a.id
      LEFT JOIN accounts da ON t.destination_account_id = da.id
      LEFT JOIN categories c ON t.category_id = c.id
      ORDER BY t.transaction_date DESC
    ''');

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('ID,Date,Type,Amount(Cents),Amount(ETB),Description,Category,Account,Destination Account,Notes');

    for (final row in transactions) {
      final id = _escapeCsv(row['id']?.toString() ?? '');
      final date = _escapeCsv(row['transaction_date']?.toString() ?? '');
      final type = _escapeCsv(row['type']?.toString() ?? '');
      final cents = (row['amount'] as int?) ?? 0;
      final etb = (cents / 100.0).toStringAsFixed(2);
      final desc = _escapeCsv(row['description']?.toString() ?? '');
      final cat = _escapeCsv(row['category_name']?.toString() ?? '');
      final acc = _escapeCsv(row['account_name']?.toString() ?? '');
      final destAcc = _escapeCsv(row['dest_account_name']?.toString() ?? '');
      final notes = _escapeCsv(row['notes']?.toString() ?? '');

      buffer.writeln('$id,$date,$type,$cents,$etb,$desc,$cat,$acc,$destAcc,$notes');
    }

    return buffer.toString();
  }

  /// Atomically validates and imports financial data from JSON string
  static Future<({bool success, String message, int importedTxCount})> importFinancialDataFromJson(String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
        return (success: false, message: 'Invalid file format: Missing "data" section', importedTxCount: 0);
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      int txCount = 0;

      await db.transaction((txn) async {
        // 1. Accounts
        if (data.containsKey('accounts')) {
          final accounts = List<Map<String, dynamic>>.from(data['accounts'] as List);
          for (final acc in accounts) {
            await txn.insert('accounts', acc, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // 2. Categories
        if (data.containsKey('categories')) {
          final categories = List<Map<String, dynamic>>.from(data['categories'] as List);
          for (final cat in categories) {
            await txn.insert('categories', cat, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // 3. Transactions
        if (data.containsKey('transactions')) {
          final transactions = List<Map<String, dynamic>>.from(data['transactions'] as List);
          for (final tx in transactions) {
            await txn.insert('transactions', tx, conflictAlgorithm: ConflictAlgorithm.replace);
            txCount++;
          }
        }

        // 4. Budgets
        if (data.containsKey('budgets')) {
          final budgets = List<Map<String, dynamic>>.from(data['budgets'] as List);
          for (final b in budgets) {
            await txn.insert('budgets', b, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // 5. Goals
        if (data.containsKey('savings_goals')) {
          final goals = List<Map<String, dynamic>>.from(data['savings_goals'] as List);
          for (final g in goals) {
            await txn.insert('savings_goals', g, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }

        // 6. Contributions
        if (data.containsKey('goal_contributions')) {
          final contributions = List<Map<String, dynamic>>.from(data['goal_contributions'] as List);
          for (final c in contributions) {
            await txn.insert('goal_contributions', c, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });

      return (
        success: true,
        message: 'Imported successfully! ($txCount transactions restored)',
        importedTxCount: txCount,
      );
    } catch (e) {
      debugPrint('Error importing data: $e');
      return (success: false, message: 'Failed to import: $e', importedTxCount: 0);
    }
  }

  /// Clears all user financial data safely while retaining database schema and default primary wallet
  static Future<bool> clearAllFinancialData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('goal_contributions');
        await txn.delete('savings_goals');
        await txn.delete('budgets');
        await txn.delete('transactions');
        await txn.delete('debt_repayments');
        await txn.delete('debts');
        await txn.delete('recurring_schedules');
        // Delete custom accounts but preserve at least 1 default cash wallet
        await txn.delete('accounts');
        // Re-seed single default Cash Wallet
        await txn.insert('accounts', {
          'id': 'default-cash-wallet',
          'name': 'Cash Wallet',
          'account_type': 'cash',
          'currency_code': 'ETB',
          'opening_balance': 0,
          'is_archived': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error clearing financial data: $e');
      return false;
    }
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
