import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/accounts/services/account_balance_service.dart';
import 'package:personal_finance/features/sms_parser/models/sms_import_log.dart';
import 'package:personal_finance/features/sms_parser/services/sms_parser_service.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/services/transaction_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('End-to-End Pipeline Integration Tests (PART 6)', () {
    late Database db;
    final parser = SmsParserService.instance;
    final balanceService = AccountBalanceService.instance;
    final reviewService = TransactionReviewService.instance;

    const exampleA =
        'Dear Bereket Anteneh Kassa You have received ETB 20,000.00 from account 1**6658 (Alemtshay Mekurya W/aregay) to your account 1**2313. Your current balance is ETB20,822.40. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHzZw3nl5PujC2Gx  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6';

    const exampleB =
        'Dear Bereket Anteneh Kassa You have successfully transferred ETB200.00 from account 1**2313 to account 1**9525 (Ethi.full Gos.ch. Haya Hulet M). Service charge of ETB 0.50 and VAT(15%) of ETB0.08 and Disaster Recovery(5%) of 0.03 with total of ETB200.61. Your current balance is ETB20,621.79. Thanks for Banking with CBE. https://mbreciept.cbe.com.et/v2-hfHCxHAlpPQoNHnmKA7C  for feedback: https://forms.gle/kGNGQpG3mQCCk3iD6';

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
            await db.execute('''
              CREATE TABLE sms_import_logs (
                id TEXT PRIMARY KEY,
                sender TEXT NOT NULL,
                account_suffix TEXT,
                amount_cents INTEGER NOT NULL,
                fee_cents INTEGER NOT NULL DEFAULT 0,
                reported_balance_cents INTEGER,
                reference_number TEXT,
                fingerprint TEXT UNIQUE NOT NULL,
                transaction_type TEXT NOT NULL,
                status TEXT NOT NULL,
                matched_account_id TEXT,
                linked_transaction_id TEXT,
                review_reason TEXT,
                confidence TEXT NOT NULL,
                raw_preview TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE sms_account_mappings (
                id TEXT PRIMARY KEY,
                bank_code TEXT NOT NULL,
                account_suffix TEXT NOT NULL,
                account_id TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(bank_code, account_suffix)
              )
            ''');
            await db.execute('''
              CREATE TABLE sms_category_rules (
                id TEXT PRIMARY KEY,
                keyword TEXT NOT NULL UNIQUE,
                category_id TEXT NOT NULL,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE sms_tracker_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            ''');

            await db.insert('sms_tracker_settings', {
              'key': 'auto_record_high_confidence',
              'value': '1',
            });
          },
        ),
      );
      DatabaseHelper.instance.setDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.instance.setDatabaseForTesting(null);
    });

    // Integration Test: Full pipeline with Example A (Incoming transfer)
    test('Integration 1: Example A is saved once, balance updated once, bank snapshot reconciled, enters review queue, and review enriches without duplicating balance', () async {
      final now = DateTime.now();
      // Setup CBE account ending in 2313
      await db.insert('accounts', {
        'id': 'acc-cbe-2313',
        'name': 'CBE Savings (...2313)',
        'account_type': 'bank',
        'opening_balance': 82240, // 822.40 ETB starting balance
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      // Map ...2313 to this account
      await db.insert('sms_account_mappings', {
        'id': 'map-1',
        'bank_code': 'cbe',
        'account_suffix': '...2313',
        'account_id': 'acc-cbe-2313',
        'created_at': now.toIso8601String(),
      });

      // 1. Process SMS Example A
      final result = await parser.processAndReconcileSms(
        exampleA,
        senderShortCode: 'CBE',
      );
      expect(result.status, SmsImportStatus.autoRecorded);

      // 2. Financial effect is applied once
      final calculated = await balanceService.calculateLedgerBalance(
        'acc-cbe-2313',
        executor: db,
      );
      expect(calculated, 2082240); // 822.40 + 20,000.00 = 20,822.40 ETB

      // 3. Bank balance snapshot reconciled
      final accRows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['acc-cbe-2313'],
      );
      final acc = Account.fromMap(accRows.first);
      expect(acc.lastConfirmedBalance, 2082240);

      // 4. Enters review queue
      final pending = await reviewService.getPendingTransactions();
      expect(pending.length, 1);
      final tx = pending.first;
      expect(tx.amount, 2000000);
      expect(tx.reviewStatus, ReviewStatus.needsReview);

      // 5. Reviewing the transaction does not change amount or apply it a second time
      await reviewService.saveTransactionReview(
        transactionId: tx.id,
        categoryId: 'cat-salary',
        purposeNote: 'October salary compensation',
      );

      final calculatedAfterReview = await balanceService.calculateLedgerBalance(
        'acc-cbe-2313',
        executor: db,
      );
      expect(calculatedAfterReview, 2082240); // Exactly same balance

      // 6. Review queue is now empty
      expect(await reviewService.getPendingReviewCount(), 0);

      // 7. Duplicate prevention: Processing same message a second time
      final dupResult = await parser.processAndReconcileSms(
        exampleA,
        senderShortCode: 'CBE',
      );
      expect(dupResult.status, SmsImportStatus.duplicate);
      final calculatedAfterDup = await balanceService.calculateLedgerBalance(
        'acc-cbe-2313',
        executor: db,
      );
      expect(calculatedAfterDup, 2082240);
    });

    // Integration Test: Full pipeline with Example B (Outgoing transfer + fees)
    test('Integration 2: Example B outgoing transfer separates principal and fee without double-counting', () async {
      final now = DateTime.now();
      await db.insert('accounts', {
        'id': 'acc-cbe-2313',
        'name': 'CBE Savings (...2313)',
        'account_type': 'bank',
        'opening_balance': 2082240, // 20,822.40 ETB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      await db.insert('sms_account_mappings', {
        'id': 'map-1',
        'bank_code': 'cbe',
        'account_suffix': '...2313',
        'account_id': 'acc-cbe-2313',
        'created_at': now.toIso8601String(),
      });

      // Process SMS Example B (Principal ETB 200.00 + Fee ETB 0.61 = Total debit ETB 200.61)
      final result = await parser.processAndReconcileSms(
        exampleB,
        senderShortCode: 'CBE',
      );
      expect(result.status, SmsImportStatus.autoRecorded);

      // Balance decreases by total 200.61 ETB (20,822.40 - 200.61 = 20,621.79 ETB)
      final calculated = await balanceService.calculateLedgerBalance(
        'acc-cbe-2313',
        executor: db,
      );
      expect(calculated, 2062179);

      // Reconciles bank snapshot exactly
      final accRows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['acc-cbe-2313'],
      );
      final acc = Account.fromMap(accRows.first);
      expect(acc.lastConfirmedBalance, 2062179);

      // Only the main transfer is queued for user purpose review (service fees are pre-reviewed)
      final pending = await reviewService.getPendingTransactions();
      expect(pending.length, 1);
      expect(pending.first.amount, 20000); // 200.00 ETB
      expect(pending.first.reviewStatus, ReviewStatus.needsReview);

      // User reviews the purpose
      await reviewService.saveTransactionReview(
        transactionId: pending.first.id,
        categoryId: 'cat-donation',
        purposeNote: 'Church donation transfer',
      );

      // Verify balance remains untouched after user explanation
      final balAfter = await balanceService.calculateLedgerBalance(
        'acc-cbe-2313',
        executor: db,
      );
      expect(balAfter, 2062179);
    });
  });
}
