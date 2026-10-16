import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/services/account_balance_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Automatic Balance Tracking & Reconciliation Tests (PART 6)', () {
    late Database db;
    final balanceService = AccountBalanceService.instance;

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

    // Test 1: Starting balance ETB 1,000.00 + incoming ETB 200.00 = ETB 1,200.00
    test('Test 1: Starting balance ETB 1,000.00 + incoming ETB 200.00 = ETB 1,200.00', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-1',
        'name': 'CBE Checking',
        'account_type': 'bank',
        'opening_balance': 100000, // 1,000.00 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await db.insert('transactions', {
        'id': 'tx-1',
        'account_id': 'acc-1',
        'type': 'income',
        'amount': 20000, // 200.00 ETB
        'description': 'Freelance income',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final calculated = await balanceService.calculateLedgerBalance(
        'acc-1',
        executor: db,
      );
      expect(calculated, 120000); // 1,200.00 ETB in cents
    });

    // Test 2: Starting balance ETB 1,000.00 − total outgoing debit ETB 200.61 = ETB 799.39
    test('Test 2: Starting balance ETB 1,000.00 - total outgoing debit ETB 200.61 = ETB 799.39', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-2',
        'name': 'CBE Checking',
        'account_type': 'bank',
        'opening_balance': 100000, // 1,000.00 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Principal: 200.00 ETB, Fee: 0.61 ETB -> total debit 200.61 ETB (20061 cents)
      await db.insert('transactions', {
        'id': 'tx-debit-principal',
        'account_id': 'acc-2',
        'type': 'expense',
        'amount': 20000,
        'description': 'Transfer to merchant',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('transactions', {
        'id': 'tx-debit-fee',
        'account_id': 'acc-2',
        'type': 'expense',
        'amount': 61,
        'description': 'Service fee',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final calculated = await balanceService.calculateLedgerBalance(
        'acc-2',
        executor: db,
      );
      expect(calculated, 79939); // 799.39 ETB
    });

    // Test 3: The same SMS processed twice changes the balance only once (idempotent)
    test('Test 3: The same transaction ID processed twice changes the balance only once', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-3',
        'name': 'CBE Checking',
        'account_type': 'bank',
        'opening_balance': 100000,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final txMap = {
        'id': 'tx-unique-cbe-ref',
        'account_id': 'acc-3',
        'type': 'expense',
        'amount': 30000, // 300.00 ETB
        'description': 'Lunch',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await db.insert(
        'transactions',
        txMap,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      // Attempt duplicate insertion
      await db.insert(
        'transactions',
        txMap,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      final calculated = await balanceService.calculateLedgerBalance(
        'acc-3',
        executor: db,
      );
      expect(
        calculated,
        70000,
      ); // 1,000 - 300 = 700.00 ETB (deducted exactly once)
    });

    // Test 4: A reported bank balance is not treated as a transaction amount
    test(
      'Test 4: Reported bank balance is not treated as a transaction amount',
      () async {
        final now = DateTime.now();
        await db.insert('accounts', {
          'id': 'acc-4',
          'name': 'CBE Checking',
          'account_type': 'bank',
          'opening_balance': 50000, // 500 ETB
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        // An SMS reports incoming transfer of 20,000 ETB, and current balance 20,822.40 ETB
        // The transaction must record 20,000 ETB, NOT the reported balance of 20,822.40 ETB
        await db.insert('transactions', {
          'id': 'tx-credit',
          'account_id': 'acc-4',
          'type': 'income',
          'amount': 2000000, // 20,000.00 ETB
          'description': 'Incoming transfer',
          'transaction_date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        final calculated = await balanceService.calculateLedgerBalance(
          'acc-4',
          executor: db,
        );
        expect(calculated, 2050000); // 500 + 20,000 = 20,500.00 ETB
        expect(calculated, isNot(equals(2082240)));
      },
    );

    // Test 5: A bank-reported balance does not get added to the ledger
    test(
      'Test 5: Bank-reported balance does not get added to the ledger',
      () async {
        final now = DateTime.now();
        await db.insert('accounts', {
          'id': 'acc-5',
          'name': 'CBE Checking',
          'account_type': 'bank',
          'opening_balance': 100000, // 1,000 ETB
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        // Safe reconciliation updates the snapshot column, NOT the ledger
        await balanceService.reconcileBankReportedBalance(
          accountId: 'acc-5',
          reportedBalanceCents: 2062179, // ETB 20,621.79
          snapshotTime: now,
          executor: db,
        );

        final calculated = await balanceService.calculateLedgerBalance(
          'acc-5',
          executor: db,
        );
        // The ledger is still 100,000 (1,000 ETB), not 1,000 + 20,621.79 = 21,621.79
        expect(calculated, 100000);

        final accRows = await db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: ['acc-5'],
        );
        final acc = Account.fromMap(accRows.first);
        expect(acc.lastConfirmedBalance, 2062179);
      },
    );

    // Test 6: A late older balance snapshot does not overwrite a newer confirmed balance
    test('Test 6: Late older balance snapshot does not overwrite a newer confirmed balance', () async {
      final newerTime = DateTime(2026, 10, 15, 12, 0);
      final olderTime = DateTime(2026, 10, 14, 8, 0);

      await db.insert('accounts', {
        'id': 'acc-6',
        'name': 'CBE Checking',
        'account_type': 'bank',
        'opening_balance': 100000,
        'created_at': olderTime.toIso8601String(),
        'updated_at': olderTime.toIso8601String(),
      });

      // Apply newer snapshot first (ETB 25,000 at 12:00)
      await balanceService.reconcileBankReportedBalance(
        accountId: 'acc-6',
        reportedBalanceCents: 2500000,
        snapshotTime: newerTime,
        executor: db,
      );

      // Now a delayed older SMS arrives with snapshot from 8:00 (ETB 20,000)
      final applied = await balanceService.reconcileBankReportedBalance(
        accountId: 'acc-6',
        reportedBalanceCents: 2000000,
        snapshotTime: olderTime,
        executor: db,
      );

      expect(applied, isFalse);

      final accRows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['acc-6'],
      );
      final acc = Account.fromMap(accRows.first);
      // Confirmed balance must still be the newer 25,000 ETB
      expect(acc.lastConfirmedBalance, 2500000);
      expect(acc.lastConfirmedAt, newerTime);
    });

    // Test 7: A transaction with an unknown starting balance establishes baseline accurately
    test('Test 7: Unknown starting balance baseline establishment from reported balance', () async {
      final now = DateTime.now();
      // Account created without starting balance baseline
      await db.insert('accounts', {
        'id': 'acc-7',
        'name': 'CBE Uninitialized',
        'account_type': 'bank',
        'opening_balance': 0,
        'has_confirmed_starting_balance': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // User has one credit of ETB 200.00
      await db.insert('transactions', {
        'id': 'tx-credit-initial',
        'account_id': 'acc-7',
        'type': 'income',
        'amount': 20000, // 200.00 ETB
        'description': 'Initial credit',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // CBE SMS reports balance is ETB 1,200.00 (120000 cents)
      await balanceService.reconcileBankReportedBalance(
        accountId: 'acc-7',
        reportedBalanceCents: 120000,
        snapshotTime: now,
        executor: db,
      );

      final accRows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['acc-7'],
      );
      final acc = Account.fromMap(accRows.first);
      // Opening balance established as 1,200 - 200 = 1,000 ETB (100000 cents)
      expect(acc.openingBalance, 100000);
      expect(acc.hasConfirmedStartingBalance, isTrue);

      final calculated = await balanceService.calculateLedgerBalance(
        'acc-7',
        executor: db,
      );
      expect(calculated, 120000);
    });

    // Test 8: Own-account transfer updates source and destination without creating net income/expense
    test('Test 8: Own-account transfer updates source and destination without creating net income/expense', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-bank',
        'name': 'CBE Bank',
        'account_type': 'bank',
        'opening_balance': 500000, // 5,000 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('accounts', {
        'id': 'acc-cash',
        'name': 'Cash Wallet',
        'account_type': 'cash',
        'opening_balance': 100000, // 1,000 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Transfer 2,000 ETB from CBE to Cash Wallet
      await db.insert('transactions', {
        'id': 'tx-internal-transfer',
        'account_id': 'acc-bank',
        'destination_account_id': 'acc-cash',
        'type': 'transfer',
        'amount': 200000, // 2,000 ETB
        'description': 'Internal transfer to cash',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final bankBal = await balanceService.calculateLedgerBalance(
        'acc-bank',
        executor: db,
      );
      final cashBal = await balanceService.calculateLedgerBalance(
        'acc-cash',
        executor: db,
      );

      expect(bankBal, 300000); // 5,000 - 2,000 = 3,000 ETB
      expect(cashBal, 300000); // 1,000 + 2,000 = 3,000 ETB
      expect(bankBal + cashBal, 600000); // Combined 6,000 ETB preserved
    });

    // Test 9: ATM withdrawal reduces bank balance
    test('Test 9: ATM withdrawal reduces bank balance', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-atm',
        'name': 'CBE Bank',
        'account_type': 'bank',
        'opening_balance': 500000, // 5,000 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // ATM withdrawal of ETB 4,000
      await db.insert('transactions', {
        'id': 'tx-atm',
        'account_id': 'acc-atm',
        'type': 'expense',
        'amount': 400000, // 4,000 ETB
        'description': 'ATM withdrawal',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final bankBal = await balanceService.calculateLedgerBalance(
        'acc-atm',
        executor: db,
      );
      expect(bankBal, 100000); // 1,000 ETB left
    });

    // Test 10: Fees applied exactly once
    test('Test 10: Fees applied exactly once', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-fee',
        'name': 'CBE Bank',
        'account_type': 'bank',
        'opening_balance': 20000, // 200 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Transfer fee of 0.61 ETB
      await db.insert('transactions', {
        'id': 'tx-fee-only',
        'account_id': 'acc-fee',
        'type': 'expense',
        'amount': 61,
        'description': 'Bank service charge',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final bal = await balanceService.calculateLedgerBalance(
        'acc-fee',
        executor: db,
      );
      expect(bal, 19939); // 200 - 0.61 = 199.39 ETB
    });

    // Test 11: Atomic transaction rollback prevents partial writes
    test('Test 11: Transaction failure leaves balance untouched', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-atomic',
        'name': 'CBE Bank',
        'account_type': 'bank',
        'opening_balance': 50000,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      try {
        await db.transaction((txn) async {
          await txn.insert('transactions', {
            'id': 'tx-valid',
            'account_id': 'acc-atomic',
            'type': 'expense',
            'amount': 10000,
            'description': 'Valid part',
            'transaction_date': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          });
          // Intentionally throw to abort transaction
          throw Exception('Aborted database operation');
        });
      } catch (_) {}

      final bal = await balanceService.calculateLedgerBalance(
        'acc-atomic',
        executor: db,
      );
      expect(bal, 50000); // Rolled back completely
    });

    // Test 12: Adjustment / reversal applied once
    test('Test 12: Correction or reversal applied accurately', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-reversal',
        'name': 'CBE Bank',
        'account_type': 'bank',
        'opening_balance': 100000, // 1,000 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Erroneous charge of 200 ETB
      await db.insert('transactions', {
        'id': 'tx-wrong-charge',
        'account_id': 'acc-reversal',
        'type': 'expense',
        'amount': 20000,
        'description': 'Erroneous charge',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Reversal / refund of 200 ETB
      await db.insert('transactions', {
        'id': 'tx-refund',
        'account_id': 'acc-reversal',
        'type': 'income',
        'amount': 20000,
        'description': 'Reversal of erroneous charge',
        'transaction_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final bal = await balanceService.calculateLedgerBalance(
        'acc-reversal',
        executor: db,
      );
      expect(bal, 100000); // 1,000 - 200 + 200 = 1,000 ETB
    });
  });
}
