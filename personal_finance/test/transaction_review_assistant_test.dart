import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/services/transaction_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Transaction Review Assistant Tests (PART 6)', () {
    late Database db;
    final reviewService = TransactionReviewService.instance;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                account_type TEXT NOT NULL,
                currency_code TEXT NOT NULL DEFAULT 'ETB',
                opening_balance INTEGER NOT NULL DEFAULT 0,
                last_confirmed_balance INTEGER,
                last_confirmed_at TEXT,
                has_confirmed_starting_balance INTEGER NOT NULL DEFAULT 1,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                transaction_type TEXT NOT NULL,
                icon_key TEXT NOT NULL,
                color_key TEXT NOT NULL,
                is_default INTEGER NOT NULL DEFAULT 0,
                is_archived INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL,
                destination_account_id TEXT,
                type TEXT NOT NULL,
                amount INTEGER NOT NULL,
                category_id TEXT,
                description TEXT NOT NULL,
                notes TEXT,
                transaction_date TEXT NOT NULL,
                recurring_schedule_id TEXT,
                review_status TEXT NOT NULL DEFAULT 'reviewed',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          },
        ),
      );
      DatabaseHelper.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });

    // Test 1: A newly detected expense appears in the review queue
    test('Test 1: Newly detected expense appears in review queue', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-expense-pending',
        'account_id': 'acc-1',
        'type': 'expense',
        'amount': 20061, // ETB 200.61
        'description': 'Money debited',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final pending = await reviewService.getPendingTransactions();
      expect(pending.length, 1);
      expect(pending.first.id, 'tx-expense-pending');
      expect(pending.first.reviewStatus, ReviewStatus.needsReview);
    });

    // Test 2: A newly detected incoming credit asks what the money was for
    test('Test 2: Newly detected incoming credit appears in review queue with income type', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-income-pending',
        'account_id': 'acc-1',
        'type': 'income',
        'amount': 2000000, // ETB 20,000.00
        'description': 'Received from Alemtshay Mekurya W/aregay',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final pending = await reviewService.getPendingTransactions();
      expect(pending.length, 1);
      final item = pending.first;
      expect(item.type, TransactionType.income);
      expect(item.amount, 2000000);
    });

    // Test 3: Saving a purpose and category updates the existing transaction without creating duplicates
    test('Test 3: Saving purpose and category updates the existing transaction record', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-to-update',
        'account_id': 'acc-1',
        'type': 'expense',
        'amount': 20085,
        'description': 'Money debited',
        'notes': 'Ref: short_auUX0',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final saved = await reviewService.saveTransactionReview(
        transactionId: 'tx-to-update',
        categoryId: 'cat-groceries',
        purposeNote: 'Supermarket vegetables',
      );

      expect(saved, isTrue);

      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: ['tx-to-update'],
      );
      final updated = FinancialTransaction.fromMap(rows.first);

      // Verify enriched data
      expect(updated.categoryId, 'cat-groceries');
      expect(updated.notes, contains('Supermarket vegetables'));
      expect(updated.notes, contains('Ref: short_auUX0'));
      // Verify preserved metadata & amounts
      expect(updated.amount, 20085);
      expect(updated.type, TransactionType.expense);
      expect(updated.accountId, 'acc-1');

      // Verify only 1 transaction in DB (no duplicates)
      final all = await db.query('transactions');
      expect(all.length, 1);
    });

    // Test 4: A transaction is marked reviewed only after save succeeds
    test('Test 4: Transaction is marked reviewed only after persistence succeeds', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-marked-reviewed',
        'account_id': 'acc-1',
        'type': 'income',
        'amount': 50000,
        'description': 'Bonus',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Saving invalid transaction ID fails and does NOT mark anything reviewed
      final failedSave = await reviewService.saveTransactionReview(
        transactionId: 'non-existent-id',
        categoryId: 'cat-1',
        purposeNote: 'Note',
      );
      expect(failedSave, isFalse);

      final pendingBefore = await reviewService.getPendingTransactions();
      expect(pendingBefore.length, 1);

      // Successful save
      final successSave = await reviewService.saveTransactionReview(
        transactionId: 'tx-marked-reviewed',
        categoryId: 'cat-1',
        purposeNote: 'Valid note',
      );
      expect(successSave, isTrue);

      final pendingAfter = await reviewService.getPendingTransactions();
      expect(pendingAfter.isEmpty, isTrue);
    });

    // Test 5: Skipping leaves the transaction pending
    test('Test 5: Skipping leaves the transaction pending', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-skipped',
        'account_id': 'acc-1',
        'type': 'expense',
        'amount': 15000,
        'description': 'Dinner',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await reviewService.skipTransaction('tx-skipped', deferForLater: true);

      final pending = await reviewService.getPendingTransactions();
      expect(pending.length, 1);
      expect(pending.first.id, 'tx-skipped');
      expect(pending.first.reviewStatus, ReviewStatus.needsReview);
    });

    // Test 6: Reopening the app resumes pending reviews
    test(
      'Test 6: Persistent review state resumes pending reviews on fresh query',
      () async {
        final now = DateTime.now();
        await db.insert('transactions', {
          'id': 'tx-pending-1',
          'account_id': 'acc-1',
          'type': 'expense',
          'amount': 10000,
          'description': 'First',
          'transaction_date': now.toIso8601String(),
          'review_status': ReviewStatus.needsReview.name,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        await db.insert('transactions', {
          'id': 'tx-pending-2',
          'account_id': 'acc-1',
          'type': 'expense',
          'amount': 20000,
          'description': 'Second',
          'transaction_date': now.toIso8601String(),
          'review_status': ReviewStatus.needsReview.name,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        // User reviews only the first one
        await reviewService.saveTransactionReview(
          transactionId: 'tx-pending-1',
          categoryId: null,
          purposeNote: 'Reviewed first',
        );

        // Simulate app restart / fresh service query:
        final freshQueue = await reviewService.getPendingTransactions();
        expect(freshQueue.length, 1);
        expect(freshQueue.first.id, 'tx-pending-2');
      },
    );

    // Test 7: Once all transactions are reviewed, pending count is zero
    test(
      'Test 7: Once all transactions are reviewed, pending count becomes zero',
      () async {
        final now = DateTime.now();
        await db.insert('transactions', {
          'id': 'tx-done-1',
          'account_id': 'acc-1',
          'type': 'expense',
          'amount': 10000,
          'description': 'Done',
          'transaction_date': now.toIso8601String(),
          'review_status': ReviewStatus.needsReview.name,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        expect(await reviewService.getPendingReviewCount(), 1);

        await reviewService.saveTransactionReview(
          transactionId: 'tx-done-1',
          categoryId: null,
          purposeNote: 'Done note',
        );

        expect(await reviewService.getPendingReviewCount(), 0);
      },
    );

    // Test 8: No pending transactions means pending count is 0
    test('Test 8: No pending transactions returns 0', () async {
      final count = await reviewService.getPendingReviewCount();
      expect(count, 0);
    });

    // Test 9: Already reviewed transactions do not appear again
    test(
      'Test 9: Already reviewed transactions do not appear in review queue',
      () async {
        final now = DateTime.now();
        await db.insert('transactions', {
          'id': 'tx-already-reviewed',
          'account_id': 'acc-1',
          'type': 'expense',
          'amount': 5000,
          'description': 'Manual transaction',
          'transaction_date': now.toIso8601String(),
          'review_status': ReviewStatus.reviewed.name,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        final pending = await reviewService.getPendingTransactions();
        expect(pending.isEmpty, isTrue);
      },
    );

    // Test 10: Review flow preserves original amounts and never duplicates financial amounts
    test('Test 10: Review flow preserves original amounts and never duplicates financial amounts', () async {
      final now = DateTime.now();
      await db.insert('transactions', {
        'id': 'tx-exact-cents',
        'account_id': 'acc-1',
        'type': 'expense',
        'amount': 20061, // 200.61 ETB
        'description': 'Transfer',
        'transaction_date': now.toIso8601String(),
        'review_status': ReviewStatus.needsReview.name,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await reviewService.saveTransactionReview(
        transactionId: 'tx-exact-cents',
        categoryId: 'cat-transfer',
        purposeNote: 'School tuition fee',
      );

      final rows = await db.query(
        'transactions',
        where: 'id = ?',
        whereArgs: ['tx-exact-cents'],
      );
      final tx = FinancialTransaction.fromMap(rows.first);
      expect(tx.amount, 20061);
      expect(tx.reviewStatus, ReviewStatus.reviewed);

      // Verify total expense in transactions table has not doubled
      final sumRes = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions",
      );
      expect(sumRes.first['total'], 20061);
    });
  });
}
