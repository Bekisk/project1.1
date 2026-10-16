import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/debts/models/debt.dart';
import 'package:personal_finance/features/debts/providers/debts_provider.dart';
import 'package:personal_finance/features/debts/widgets/add_edit_debt_dialog.dart';
import 'package:personal_finance/features/debts/widgets/settle_debt_dialog.dart';
import 'package:provider/provider.dart';

class DebtsListView extends StatelessWidget {
  final List<Account> accounts;

  const DebtsListView({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<DebtsProvider>(
      builder: (context, debtsProvider, child) {
        if (debtsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final debts = debtsProvider.debts;

        return RefreshIndicator(
          onRefresh: () => debtsProvider.loadDebts(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary Banner Card
              FintechCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'IOU Summary',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (debtsProvider.netDebtBalanceCents >= 0
                                        ? AppTheme.primaryGreen
                                        : AppTheme.expenseRed)
                                    .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            debtsProvider.netDebtBalanceCents >= 0
                                ? 'Net Receivable'
                                : 'Net Payable',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: debtsProvider.netDebtBalanceCents >= 0
                                  ? AppTheme.primaryGreen
                                  : AppTheme.expenseRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Owed to me
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'They Owe Me',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatCents(
                                  debtsProvider.totalOwedToMeCents,
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                        const SizedBox(width: 14),
                        // I owe
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'I Owe',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatCents(
                                  debtsProvider.totalIOweCents,
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.expenseRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Empty State
              if (debts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.handshake_outlined,
                          size: 48,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active debts or IOUs',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track informal loans, shared bills, and receivables effortlessly.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add First IOU'),
                          onPressed: () => AddEditDebtDialog.show(
                            context,
                            accounts: accounts,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...debts.map((debt) => _buildDebtCard(context, debt, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebtCard(BuildContext context, Debt debt, bool isDark) {
    final isReceivable = debt.type == DebtType.owesMe;
    final isSettled = debt.isSettled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FintechCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      (isReceivable
                              ? AppTheme.primaryGreen
                              : AppTheme.expenseRed)
                          .withOpacity(0.15),
                  child: Icon(
                    isReceivable ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                    color: isReceivable
                        ? AppTheme.primaryGreen
                        : AppTheme.expenseRed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.personName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isReceivable ? 'OWES YOU' : 'YOU OWE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isReceivable
                              ? AppTheme.primaryGreen
                              : AppTheme.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatCents(debt.remainingAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSettled
                            ? Colors.grey
                            : (isReceivable
                                  ? AppTheme.primaryGreen
                                  : AppTheme.expenseRed),
                      ),
                    ),
                    if (debt.settledAmount > 0)
                      Text(
                        'Total: ${CurrencyFormatter.formatCents(debt.totalAmount)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  onSelected: (val) {
                    if (val == 'edit') {
                      AddEditDebtDialog.show(
                        context,
                        debtToEdit: debt,
                        accounts: accounts,
                      );
                    } else if (val == 'delete') {
                      context.read<DebtsProvider>().deleteDebt(debt.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: debt.progressPercentage,
                minHeight: 5,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isSettled
                      ? Colors.grey
                      : (isReceivable
                            ? AppTheme.primaryGreen
                            : AppTheme.expenseRed),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (debt.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${DateFormat('MMM dd').format(debt.dueDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  )
                else
                  const Text(
                    'No due date',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (!isSettled)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(
                      isReceivable ? 'Receive' : 'Pay',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => SettleDebtDialog.show(
                      context,
                      debt: debt,
                      accounts: accounts,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SETTLED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
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
}
