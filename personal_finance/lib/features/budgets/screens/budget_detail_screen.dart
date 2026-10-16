import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/formatting/date_formatter.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/budgets/screens/add_edit_budget_sheet.dart';
import 'package:personal_finance/features/budgets/services/budget_calculation_service.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/screens/transaction_detail_sheet.dart';

/// Screen displaying detailed budget analytics, spending breakdown, contributing expense transactions, and edit/delete actions
class BudgetDetailScreen extends StatelessWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  Future<void> _confirmDelete(BuildContext context, Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Budget?'),
        content: Text(
          'Are you sure you want to delete "${budget.name}"? Your expense transactions will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expenseRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<BudgetsProvider>().deleteBudget(
        budget.id,
      );
      if (context.mounted) {
        if (success) {
          context.read<DashboardProvider>().loadDashboardData();
          Navigator.of(context).pop(); // Return to budgets screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget deleted successfully.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<BudgetsProvider>();

    final budgetList = provider.budgets.where((b) => b.id == budgetId).toList();
    if (budgetList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget Details')),
        body: const Center(child: Text('Budget not found or removed.')),
      );
    }

    final budget = budgetList.first;
    final result = provider.calculateSingleBudget(budget);
    final category = result.category;

    final isExceeded = result.healthStatus == BudgetHealthStatus.exceeded;
    final isApproaching =
        result.healthStatus == BudgetHealthStatus.approachingLimit;

    final Color statusColor = isExceeded
        ? AppTheme.expenseRed
        : isApproaching
        ? AppTheme.accentAmber
        : AppTheme.primaryGreen;

    final String statusLabel = isExceeded
        ? 'Budget Exceeded'
        : isApproaching
        ? 'Approaching Limit (${(budget.warningThreshold * 100).toInt()}%)'
        : 'On Track';

    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Budget',
            onPressed: () =>
                AddEditBudgetSheet.show(context, budgetToEdit: budget),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.expenseRed,
            ),
            tooltip: 'Delete Budget',
            onPressed: () => _confirmDelete(context, budget),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Status & Progress Card
            FintechCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (category != null)
                            CategoryIconBadge(
                              iconKey: category.iconKey,
                              colorKey: category.colorKey,
                              size: 40,
                              iconSize: 20,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pie_chart_rounded,
                                size: 20,
                                color: statusColor,
                              ),
                            ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                budget.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                budget.budgetType.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(
                            alpha: isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: result.visualProgress,
                      minHeight: 12,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${result.percentageConsumed.toStringAsFixed(1)}% consumed',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'Limit: ${CurrencyFormatter.formatCents(budget.amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Spent vs Remaining breakdown
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Spent So Far',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatCents(result.spentCents),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExceeded
                                  ? 'Exceeded By'
                                  : 'Remaining Available',
                              style: TextStyle(
                                fontSize: 11,
                                color: isExceeded
                                    ? AppTheme.expenseRed
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isExceeded
                                  ? '+${CurrencyFormatter.formatCents(result.exceededCents)}'
                                  : CurrencyFormatter.formatCents(
                                      result.availableCents,
                                    ),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isExceeded
                                    ? AppTheme.expenseRed
                                    : AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Period details
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.date_range_rounded,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM d').format(budget.periodStart.toLocal())} - ${DateFormat('MMM d, yyyy').format(budget.periodEnd.toLocal())} • ${budget.frequency.name.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Contributing Expenses Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contributing Expenses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${result.contributingTransactions.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.primaryGreen
                          : AppTheme.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (result.contributingTransactions.isEmpty)
              FintechCard(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 36,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No Expenses Recorded Yet',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expenses recorded in this category during the active period will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...result.contributingTransactions.map(
                (tx) => _buildTransactionItem(context, tx, category, isDark),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    FinancialTransaction tx,
    Category? category,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: FintechCard(
        onTap: () => TransactionDetailSheet.show(context, tx),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 14,
        child: Row(
          children: [
            if (category != null)
              CategoryIconBadge(
                iconKey: category.iconKey,
                colorKey: category.colorKey,
                size: 38,
                iconSize: 18,
              )
            else
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.expenseRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppTheme.expenseRed,
                  size: 18,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormatter.formatDate(tx.transactionDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '-${CurrencyFormatter.formatCents(tx.amount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.expenseRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
