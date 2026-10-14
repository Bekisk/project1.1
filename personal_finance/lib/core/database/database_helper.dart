import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static const _databaseName = "personal_finance.db";
  static const _databaseVersion = 6;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints in SQLite
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate budgets table with additional fields if missing
      await _upgradeBudgetsTableV2(db);
    }
    if (oldVersion < 3) {
      // Migrate savings goals and contributions tables
      await _upgradeSavingsGoalsTableV3(db);
    }
    if (oldVersion < 4) {
      await _upgradeUserProfileTableV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeDebtsAndRecurringTableV5(db);
    }
    if (oldVersion < 6) {
      await _upgradeSmsTrackerTablesV6(db);
    }
  }

  Future<void> _upgradeSmsTrackerTablesV6(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_import_logs (
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
        created_at TEXT NOT NULL,
        FOREIGN KEY (matched_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (linked_transaction_id) REFERENCES transactions (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_account_mappings (
        id TEXT PRIMARY KEY,
        bank_code TEXT NOT NULL,
        account_suffix TEXT NOT NULL,
        account_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        UNIQUE(bank_code, account_suffix)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_category_rules (
        id TEXT PRIMARY KEY,
        keyword TEXT NOT NULL UNIQUE,
        category_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_tracker_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default settings
    await db.insert('sms_tracker_settings', {
      'key': 'auto_record_high_confidence',
      'value': '0', // Safer default: Ask for confirmation first
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sms_tracker_settings', {
      'key': 'tracking_enabled',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('sms_tracker_settings', {
      'key': 'notify_on_detection',
      'value': '1',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _upgradeDebtsAndRecurringTableV5(Database db) async {
    final debtCols = await db.rawQuery("PRAGMA table_info(debts)");
    final existingDebtCols = debtCols.map((c) => c['name'] as String).toSet();
    if (!existingDebtCols.contains('person_name')) {
      await db.execute("ALTER TABLE debts ADD COLUMN person_name TEXT NOT NULL DEFAULT ''");
    }
    if (!existingDebtCols.contains('total_amount')) {
      await db.execute("ALTER TABLE debts ADD COLUMN total_amount INTEGER NOT NULL DEFAULT 0");
    }
    if (!existingDebtCols.contains('settled_amount')) {
      await db.execute("ALTER TABLE debts ADD COLUMN settled_amount INTEGER NOT NULL DEFAULT 0");
    }
    if (!existingDebtCols.contains('linked_wallet_id')) {
      await db.execute("ALTER TABLE debts ADD COLUMN linked_wallet_id TEXT");
    }

    final recCols = await db.rawQuery("PRAGMA table_info(recurring_schedules)");
    final existingRecCols = recCols.map((c) => c['name'] as String).toSet();
    if (!existingRecCols.contains('name')) {
      await db.execute("ALTER TABLE recurring_schedules ADD COLUMN name TEXT NOT NULL DEFAULT 'Subscription'");
    }
    if (!existingRecCols.contains('frequency')) {
      await db.execute("ALTER TABLE recurring_schedules ADD COLUMN frequency TEXT NOT NULL DEFAULT 'monthly'");
    }
    if (!existingRecCols.contains('last_processed_date')) {
      await db.execute("ALTER TABLE recurring_schedules ADD COLUMN last_processed_date TEXT");
    }
    if (!existingRecCols.contains('is_active')) {
      await db.execute("ALTER TABLE recurring_schedules ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1");
    }
    if (!existingRecCols.contains('notes')) {
      await db.execute("ALTER TABLE recurring_schedules ADD COLUMN notes TEXT");
    }
  }

  Future<void> _upgradeUserProfileTableV4(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        full_name TEXT,
        nickname TEXT,
        occupation TEXT,
        country_or_region TEXT NOT NULL DEFAULT 'Ethiopia',
        age_range TEXT,
        profile_image_path TEXT,
        discovery_source TEXT,
        discovery_source_other TEXT,
        personal_goal TEXT,
        preferred_language TEXT NOT NULL DEFAULT 'English',
        preferred_currency TEXT NOT NULL DEFAULT 'ETB',
        main_account_id TEXT,
        designated_savings_account_id TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (main_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (designated_savings_account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');
  }

  Future<void> _upgradeBudgetsTableV2(Database db) async {
    final columnsResult = await db.rawQuery("PRAGMA table_info(budgets)");
    final existingColumns = columnsResult.map((c) => c['name'] as String).toSet();

    if (!existingColumns.contains('name')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN name TEXT NOT NULL DEFAULT 'Budget'");
    }
    if (!existingColumns.contains('budget_type')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN budget_type TEXT NOT NULL DEFAULT 'category'");
    }
    if (!existingColumns.contains('frequency')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN frequency TEXT NOT NULL DEFAULT 'monthly'");
    }
    if (!existingColumns.contains('account_id')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN account_id TEXT");
    }
    if (!existingColumns.contains('is_archived')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0");
    }
    if (!existingColumns.contains('notes')) {
      await db.execute("ALTER TABLE budgets ADD COLUMN notes TEXT");
    }
  }

  Future<void> _upgradeSavingsGoalsTableV3(Database db) async {
    final goalCols = await db.rawQuery("PRAGMA table_info(savings_goals)");
    final existingGoalCols = goalCols.map((c) => c['name'] as String).toSet();

    if (!existingGoalCols.contains('category')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN category TEXT NOT NULL DEFAULT 'General Savings'");
    }
    if (!existingGoalCols.contains('icon_key')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'savings'");
    }
    if (!existingGoalCols.contains('priority')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium'");
    }
    if (!existingGoalCols.contains('linked_account_id')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN linked_account_id TEXT");
    }
    if (!existingGoalCols.contains('plan_frequency')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN plan_frequency TEXT");
    }
    if (!existingGoalCols.contains('planned_periodic_amount')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN planned_periodic_amount INTEGER");
    }
    if (!existingGoalCols.contains('notes')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN notes TEXT");
    }
    if (!existingGoalCols.contains('completed_at')) {
      await db.execute("ALTER TABLE savings_goals ADD COLUMN completed_at TEXT");
    }

    final contribCols = await db.rawQuery("PRAGMA table_info(goal_contributions)");
    final existingContribCols = contribCols.map((c) => c['name'] as String).toSet();
    if (!existingContribCols.contains('destination_account_id')) {
      await db.execute("ALTER TABLE goal_contributions ADD COLUMN destination_account_id TEXT");
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Accounts Table
    // opening_balance and balances are stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        currency_code TEXT NOT NULL DEFAULT 'ETB',
        opening_balance INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 2. Categories Table
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

    // 3. Transactions Table
    // amount stored as INTEGER (cents)
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (destination_account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // 4. Budgets Table
    // amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        budget_type TEXT NOT NULL DEFAULT 'category',
        category_id TEXT,
        amount INTEGER NOT NULL,
        period_start TEXT NOT NULL,
        period_end TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'monthly',
        account_id TEXT,
        warning_threshold REAL NOT NULL DEFAULT 0.8,
        is_archived INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 5. Savings Goals Table
    // target_amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL,
        target_date TEXT,
        description TEXT,
        category TEXT NOT NULL DEFAULT 'General Savings',
        icon_key TEXT NOT NULL DEFAULT 'savings',
        status TEXT NOT NULL DEFAULT 'active',
        priority TEXT NOT NULL DEFAULT 'medium',
        linked_account_id TEXT,
        plan_frequency TEXT,
        planned_periodic_amount INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY (linked_account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 6. Goal Contributions Table
    // amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE goal_contributions (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        contribution_date TEXT NOT NULL,
        mode TEXT NOT NULL,
        source_account_id TEXT,
        destination_account_id TEXT,
        transfer_transaction_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (goal_id) REFERENCES savings_goals (id) ON DELETE CASCADE,
        FOREIGN KEY (source_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (destination_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (transfer_transaction_id) REFERENCES transactions (id) ON DELETE SET NULL
      )
    ''');

    // 7. Recurring Schedules Table
    // amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE recurring_schedules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT 'Subscription',
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        account_id TEXT NOT NULL,
        category_id TEXT,
        frequency TEXT NOT NULL DEFAULT 'monthly',
        interval_type TEXT NOT NULL DEFAULT 'month',
        interval_value INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        next_occurrence TEXT NOT NULL,
        last_processed_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    // 8. Debts Table
    // total_amount and settled_amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        person_name TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        debt_type TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        settled_amount INTEGER NOT NULL DEFAULT 0,
        original_amount INTEGER NOT NULL DEFAULT 0,
        due_date TEXT,
        start_date TEXT NOT NULL,
        linked_wallet_id TEXT,
        status TEXT NOT NULL DEFAULT 'UNPAID',
        description TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (linked_wallet_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 9. Debt Repayments Table
    // amount stored as INTEGER (cents)
    await db.execute('''
      CREATE TABLE debt_repayments (
        id TEXT PRIMARY KEY,
        debt_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        repayment_date TEXT NOT NULL,
        account_id TEXT,
        transaction_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts (id) ON DELETE CASCADE,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE SET NULL
      )
    ''');

    // 10. App Settings (Key-Value)
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 11. User Profile Table
    await db.execute('''
      CREATE TABLE user_profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        full_name TEXT,
        nickname TEXT,
        occupation TEXT,
        country_or_region TEXT NOT NULL DEFAULT 'Ethiopia',
        age_range TEXT,
        profile_image_path TEXT,
        discovery_source TEXT,
        discovery_source_other TEXT,
        personal_goal TEXT,
        preferred_language TEXT NOT NULL DEFAULT 'English',
        preferred_currency TEXT NOT NULL DEFAULT 'ETB',
        main_account_id TEXT,
        designated_savings_account_id TEXT,
        onboarding_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (main_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
        FOREIGN KEY (designated_savings_account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // Seed default categories
    await _seedDefaultCategories(db);
    // Seed default primary account
    await _seedDefaultAccount(db);
    // Create SMS tracker tables and default settings
    await _upgradeSmsTrackerTablesV6(db);
  }

  Future<void> _seedDefaultCategories(Database db) async {
    const uuid = Uuid();
    final defaultCategories = [
      // Expense categories
      {'name': 'Food & Dining', 'type': 'expense', 'icon': 'restaurant', 'color': '0xFFFF7043'},
      {'name': 'Groceries', 'type': 'expense', 'icon': 'shopping_cart', 'color': '0xFF26A69A'},
      {'name': 'Transportation', 'type': 'expense', 'icon': 'directions_car', 'color': '0xFF42A5F5'},
      {'name': 'Housing & Rent', 'type': 'expense', 'icon': 'home', 'color': '0xFFAB47BC'},
      {'name': 'Utilities & Bills', 'type': 'expense', 'icon': 'receipt_long', 'color': '0xFFFFA726'},
      {'name': 'Healthcare', 'type': 'expense', 'icon': 'medical_services', 'color': '0xFFEC407A'},
      {'name': 'Education', 'type': 'expense', 'icon': 'school', 'color': '0xFF5C6BC0'},
      {'name': 'Entertainment', 'type': 'expense', 'icon': 'movie', 'color': '0xFF7E57C2'},
      {'name': 'Shopping', 'type': 'expense', 'icon': 'shopping_bag', 'color': '0xFF26C6DA'},
      {'name': 'Other Expense', 'type': 'expense', 'icon': 'category', 'color': '0xFF78909C'},

      // Income categories
      {'name': 'Salary', 'type': 'income', 'icon': 'work', 'color': '0xFF66BB6A'},
      {'name': 'Business', 'type': 'income', 'icon': 'store', 'color': '0xFF29B6F6'},
      {'name': 'Freelance', 'type': 'income', 'icon': 'laptop', 'color': '0xFF8D6E63'},
      {'name': 'Investments', 'type': 'income', 'icon': 'trending_up', 'color': '0xFF26A69A'},
      {'name': 'Gifts & Grants', 'type': 'income', 'icon': 'card_giftcard', 'color': '0xFFFFCA28'},
      {'name': 'Other Income', 'type': 'income', 'icon': 'attach_money', 'color': '0xFF9CCC65'},
    ];

    for (var cat in defaultCategories) {
      await db.insert('categories', {
        'id': uuid.v4(),
        'name': cat['name']!,
        'transaction_type': cat['type']!,
        'icon_key': cat['icon']!,
        'color_key': cat['color']!,
        'is_default': 1,
        'is_archived': 0,
      });
    }
  }

  Future<void> _seedDefaultAccount(Database db) async {
    const uuid = Uuid();
    final now = DateTime.now().toIso8601String();
    await db.insert('accounts', {
      'id': uuid.v4(),
      'name': 'Cash Wallet',
      'account_type': 'cash',
      'currency_code': 'ETB',
      'opening_balance': 0,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
