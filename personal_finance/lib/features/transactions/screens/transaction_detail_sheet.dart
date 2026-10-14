import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:personal_finance/features/transactions/screens/add_transaction_sheet.dart';

/// Bottom sheet displaying complete details of a transaction with Edit and Delete capabilities
class TransactionDetailSheet extends StatelessWidget {
  final FinancialTransaction transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static Future<void> show(BuildContext context, FinancialTransaction transaction) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransactionDetailSheet(transaction: transaction),
    );
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction? This will restore balances and update your summaries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<TransactionsProvider>().deleteTransaction(transaction.id);
      if (context.mounted) {
        if (success) {
          context.read<DashboardProvider>().loadDashboardData();
          context.read<BudgetsProvider>().loadBudgetData();
          Navigator.of(context).pop(); // Close detail sheet
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryNavy,
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Transaction deleted successfully.'),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete transaction.')),
          );
        }
      }
    }
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).pop(); // Close detail sheet
    AddTransactionSheet.show(context, transactionToEdit: transaction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TransactionsProvider>();

    final isExpense = transaction.type == TransactionType.expense;
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;

    final color = isExpense
        ? AppTheme.expenseRed
        : isIncome
            ? AppTheme.incomeGreen
            : AppTheme.transferBlue;

    final prefix = isExpense ? '-' : (isIncome ? '+' : '');

    final sourceAccount = provider.accountMap[transaction.accountId]?.name ?? 'Unknown Account';
    final destinationAccount = transaction.destinationAccountId != null
        ? (provider.accountMap[transaction.destinationAccountId]?.name ?? 'Unknown Account')
        : null;

    final category = transaction.categoryId != null ? provider.categoryMap[transaction.categoryId] : null;

    return Container(
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 28),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardCharcoal : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.borderPrimary : Colors.transparent,
          width: 1,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.disabledGray : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Header Badge & Amount
          if (category != null)
            CategoryIconBadge(
              iconKey: category.iconKey,
              colorKey: category.colorKey,
              size: 56,
              iconSize: 28,
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isExpense
                      ? Icons.arrow_upward_rounded
                      : isIncome
                          ? Icons.arrow_downward_rounded
                          : Icons.swap_horiz_rounded,
                  color: color,
                  size: 28,
                ),
              ),
            ),
          const SizedBox(height: 12),

          Text(
            transaction.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          Text(
            '$prefix${CurrencyFormatter.formatCents(transaction.amount)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatCents(transaction.amount, amharicSuffix: true),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 20),

          // Detail Info Tiles in a FintechCard
          FintechCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  label: 'Type',
                  value: transaction.type.name.toUpperCase(),
                  valueColor: color,
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildInfoRow(
                  context,
                  label: 'Date & Time',
                  value: DateFormat('EEEE, MMM d, yyyy • hh:mm a').format(transaction.transactionDate.toLocal()),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                if (!isTransfer) ...[
                  _buildInfoRow(
                    context,
                    label: 'Account',
                    value: sourceAccount,
                    isDark: isDark,
                  ),
                  if (category != null) ...[
                    _buildDivider(isDark),
                    _buildInfoRow(
                      context,
                      label: 'Category',
                      value: category.name,
                      isDark: isDark,
                    ),
                  ],
                ] else ...[
                  _buildInfoRow(
                    context,
                    label: 'From Account',
                    value: sourceAccount,
                    isDark: isDark,
                  ),
                  _buildDivider(isDark),
                  _buildInfoRow(
                    context,
                    label: 'To Account',
                    value: destinationAccount ?? '—',
                    isDark: isDark,
                  ),
                ],
                if (transaction.notes != null && transaction.notes!.trim().isNotEmpty) ...[
                  _buildDivider(isDark),
                  _buildInfoRow(
                    context,
                    label: 'Notes',
                    value: transaction.notes!,
                    isDark: isDark,
                  ),
                ],
                if (transaction.notes != null &&
                    (transaction.notes!.contains('Auto-imported') ||
                     transaction.notes!.contains('Confirmed from Bank SMS') ||
                     transaction.notes!.contains('Auto-synced'))) ...[
                  _buildDivider(isDark),
                  _buildInfoRow(
                    context,
                    label: 'Import Source',
                    value: 'Bank SMS Alert (Local)',
                    valueColor: AppTheme.primaryGreen,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions: Edit and Delete
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmAndDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.expenseRed),
                  label: const Text('Delete', style: TextStyle(color: AppTheme.expenseRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.expenseRed, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openEdit(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                    foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 16,
      color: isDark ? AppTheme.borderSecondary : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? (isDark ? Colors.white : AppTheme.textDark),
            ),
          ),
        ),
      ],
    );
  }
}
