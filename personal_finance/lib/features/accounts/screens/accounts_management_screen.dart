import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/debts/widgets/add_edit_debt_dialog.dart';
import 'package:personal_finance/features/debts/widgets/debts_list_view.dart';

class AccountsManagementScreen extends StatefulWidget {
  const AccountsManagementScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountsManagementScreen()),
    );
  }

  @override
  State<AccountsManagementScreen> createState() => _AccountsManagementScreenState();
}

class _AccountsManagementScreenState extends State<AccountsManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Account> _accounts = [];
  Map<String, int> _accountBalances = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAccountsWithBalances();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountsWithBalances() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      final accounts = accMaps.map((e) => Account.fromMap(e)).toList();

      final Map<String, int> balances = {};
      for (final acc in accounts) {
        int bal = acc.openingBalance;
        // Inflows
        final inRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'income'",
          [acc.id],
        );
        bal += (inRes.first['total'] as int?) ?? 0;

        // Outflows
        final outRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'expense'",
          [acc.id],
        );
        bal -= (outRes.first['total'] as int?) ?? 0;

        // Transfers Out
        final trOutRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE account_id = ? AND type = 'transfer'",
          [acc.id],
        );
        bal -= (trOutRes.first['total'] as int?) ?? 0;

        // Transfers In
        final trInRes = await db.rawQuery(
          "SELECT SUM(amount) as total FROM transactions WHERE destination_account_id = ? AND type = 'transfer'",
          [acc.id],
        );
        bal += (trInRes.first['total'] as int?) ?? 0;

        balances[acc.id] = bal;
      }

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _accountBalances = balances;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditAccountDialog({Account? accountToEdit}) {
    final nameCtrl = TextEditingController(text: accountToEdit?.name ?? '');
    final openingCtrl = TextEditingController(
      text: accountToEdit != null ? (accountToEdit.openingBalance / 100.0).toStringAsFixed(2) : '0.00',
    );
    String selectedType = accountToEdit?.accountType ?? 'cash';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(accountToEdit == null ? 'New Account / Wallet' : 'Edit Account'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Account Name *',
                      hintText: 'e.g. CBE Account, Telebirr, Cash',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter account name' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Account Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Account (CBE, Awash, etc.)')),
                      DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money (Telebirr, CBE Birr)')),
                      DropdownMenuItem(value: 'savings', child: Text('Dedicated Savings')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: openingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Opening Balance (ETB)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final nav = Navigator.of(ctx);
                  final dash = context.read<DashboardProvider>();
                  final txs = context.read<TransactionsProvider>();

                  final opening = (double.tryParse(openingCtrl.text.trim()) ?? 0 * 100).round();
                  final db = await DatabaseHelper.instance.database;
                  final now = DateTime.now();

                  if (accountToEdit == null) {
                    final newAcc = Account(
                      id: const Uuid().v4(),
                      name: nameCtrl.text.trim(),
                      accountType: selectedType,
                      openingBalance: opening,
                      createdAt: now,
                      updatedAt: now,
                    );
                    await db.insert('accounts', newAcc.toMap());
                  } else {
                    final updated = accountToEdit.copyWith(
                      name: nameCtrl.text.trim(),
                      accountType: selectedType,
                      openingBalance: opening,
                      updatedAt: now,
                    );
                    await db.update('accounts', updated.toMap(), where: 'id = ?', whereArgs: [accountToEdit.id]);
                  }

                  nav.pop();
                  dash.loadDashboardData();
                  txs.loadTransactions();
                  if (mounted) {
                    _loadAccountsWithBalances();
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmArchive(Account acc) {
    if (_accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one active account')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Account?'),
        content: Text('Archive "${acc.name}"? Existing transactions referencing this account will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = await DatabaseHelper.instance.database;
              await db.update('accounts', {'is_archived': 1}, where: 'id = ?', whereArgs: [acc.id]);
              if (mounted) {
                context.read<DashboardProvider>().loadDashboardData();
                context.read<TransactionsProvider>().loadTransactions();
                _loadAccountsWithBalances();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'mobile_money':
        return Icons.phone_android_rounded;
      case 'savings':
        return Icons.savings_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Wallets'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
          unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: 'Wallets & Banks'),
            Tab(icon: Icon(Icons.handshake_outlined, size: 20), text: 'Lend & Borrow'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add',
            onPressed: () {
              if (_tabController.index == 0) {
                _showAddEditAccountDialog();
              } else {
                AddEditDebtDialog.show(context, accounts: _accounts);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _loadAccountsWithBalances,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                  ..._accounts.map((acc) {
                    final balance = _accountBalances[acc.id] ?? 0;
                    final profileProvider = context.watch<UserProfileProvider>();
                    final isMain = profileProvider.mainAccountId == acc.id;
                    final isSavings = profileProvider.designatedSavingsAccountId == acc.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FintechCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(_iconForType(acc.accountType), color: AppTheme.primaryGreen, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          acc.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                      if (isMain) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('MAIN',
                                              style: TextStyle(
                                                  fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                        ),
                                      ],
                                      if (isSavings) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.transferBlue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('SAVINGS',
                                              style: TextStyle(
                                                  fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.transferBlue)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    acc.accountType.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCents(balance),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: balance >= 0 ? (isDark ? Colors.white : AppTheme.primaryNavy) : AppTheme.expenseRed,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                                      tooltip: 'Account Roles & Actions',
                                      onSelected: (val) async {
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        if (val == 'set_main') {
                                          await profileProvider.setMainAccountId(acc.id);
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(content: Text('${acc.name} set as Main Account')),
                                          );
                                        } else if (val == 'set_savings') {
                                          await profileProvider.setDesignatedSavingsAccountId(acc.id);
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(content: Text('${acc.name} set as Designated Savings Account')),
                                          );
                                        } else if (val == 'unset_savings') {
                                          await profileProvider.setDesignatedSavingsAccountId(null);
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(content: Text('Removed Savings Account designation')),
                                          );
                                        } else if (val == 'edit') {
                                          _showAddEditAccountDialog(accountToEdit: acc);
                                        } else if (val == 'archive') {
                                          _confirmArchive(acc);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'set_main',
                                          enabled: !isMain,
                                          child: Row(
                                            children: [
                                              Icon(Icons.star_rounded, size: 18, color: isMain ? Colors.grey : AppTheme.primaryGreen),
                                              const SizedBox(width: 8),
                                              Text(isMain ? 'Current Main Account' : 'Set as Main Account'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: isSavings ? 'unset_savings' : 'set_savings',
                                          child: Row(
                                            children: [
                                              Icon(Icons.savings_rounded, size: 18, color: isSavings ? AppTheme.accentCoral : AppTheme.transferBlue),
                                              const SizedBox(width: 8),
                                              Text(isSavings ? 'Remove Savings Role' : 'Set as Savings Account'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit Account Details'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'archive',
                                          child: Row(
                                            children: [
                                              Icon(Icons.archive_outlined, size: 18, color: AppTheme.accentCoral),
                                              SizedBox(width: 8),
                                              Text('Archive Account', style: TextStyle(color: AppTheme.accentCoral)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // Tab 2: Lend & Borrow IOU Tracker
            DebtsListView(accounts: _accounts),
          ],
        ),
    );
  }
}
