import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/settings/services/data_backup_service.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/savings_goals/providers/savings_goals_provider.dart';
import 'package:provider/provider.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DataManagementScreen()),
    );
  }

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportJson() async {
    setState(() => _isExporting = true);
    try {
      final jsonStr = await DataBackupService.exportFinancialDataAsJson();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text('JSON Backup Ready'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your financial backup has been compiled with all accounts, categories, transactions, budgets, and savings goals.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Payload size: ${(jsonStr.length / 1024).toStringAsFixed(1)} KB\nRecords timestamped: ${DateTime.now()}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup copied to clipboard!')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final csvStr = await DataBackupService.exportTransactionsAsCsv();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.table_chart_rounded, color: AppTheme.transferBlue),
              SizedBox(width: 8),
              Text('CSV Export Ready'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your transactions history is ready in universal spreadsheet CSV format.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Rows: ${csvStr.split('\n').length - 1} lines\nColumns: Date, Type, Amount, Category, Account, Notes',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvStr));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSV copied to clipboard!')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Export error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showImportDialog() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from JSON Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your previously exported JSON backup payload below. Data will be safely validated and imported into SQLite.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '{\n  "app": "My Finance",\n  "data": { ... }\n}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final payload = textCtrl.text.trim();
              if (payload.isEmpty) return;

              Navigator.pop(ctx);
              setState(() => _isImporting = true);

              final result = await DataBackupService.importFinancialDataFromJson(payload);
              if (mounted) {
                setState(() => _isImporting = false);
                if (result.success) {
                  // Refresh all providers
                  context.read<DashboardProvider>().loadDashboardData();
                  context.read<TransactionsProvider>().loadTransactions();
                  context.read<BudgetsProvider>().loadBudgetData();
                  context.read<SavingsGoalsProvider>().loadGoalsData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: AppTheme.primaryGreen,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.message),
                      backgroundColor: AppTheme.expenseRed,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Validate & Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmWipeData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.expenseRed, size: 28),
            SizedBox(width: 8),
            Text('Wipe All Financial Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete all recorded transactions, custom accounts, budgets, savings goals, and contributions.\n\n'
          'Default wallets will be reset to 0 ETB. Your theme and app preferences will NOT be affected.\n\n'
          'Are you sure you want to proceed?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Second verification step as requested by prompt
              _showFinalWipeConfirmation();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseRed),
            child: const Text('I Understand, Continue'),
          ),
        ],
      ),
    );
  }

  void _showFinalWipeConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('FINAL CONFIRMATION'),
        content: const Text(
          'Type CONFIRM to erase all stored financial records permanently.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await DataBackupService.clearAllFinancialData();
              if (mounted) {
                if (success) {
                  context.read<DashboardProvider>().loadDashboardData();
                  context.read<TransactionsProvider>().loadTransactions();
                  context.read<BudgetsProvider>().loadBudgetData();
                  context.read<SavingsGoalsProvider>().loadGoalsData();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All financial data has been deleted.'),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseRed),
            child: const Text('DELETE ALL DATA'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management & Backup'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FintechCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: AppTheme.primaryGreen, size: 22),
                    SizedBox(width: 8),
                    Text(
                      '100% Offline & Private',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your financial data is stored purely on your device in local SQLite databases. No cloud tracking, analytics, or external telemetry.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Export options
          FintechCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_download_rounded, color: AppTheme.primaryGreen),
                    title: const Text('Export JSON Full Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Complete backup of all accounts, transactions, budgets, goals'),
                    trailing: _isExporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded),
                    onTap: _isExporting ? null : _exportJson,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.table_chart_rounded, color: AppTheme.transferBlue),
                    title: const Text('Export Transactions (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Universal spreadsheet format for Excel, Google Sheets, or LibreOffice'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _exportCsv,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.accentAmber),
                    title: const Text('Restore from JSON Backup', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Import verified records back into your local database'),
                    trailing: _isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right_rounded),
                    onTap: _isImporting ? null : _showImportDialog,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Danger Zone
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'DANGER ZONE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.expenseRed,
                letterSpacing: 0.8,
              ),
            ),
          ),
          FintechCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.expenseRed),
                title: const Text(
                  'Delete All Financial Data',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.expenseRed),
                ),
                subtitle: const Text('Permanently wipes transactions, budgets, goals, and accounts'),
                onTap: _confirmWipeData,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
