import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

/// Accurate financial calculation model for a single local calendar day.
class DailyFinancialSummary {
  final DateTime date;
  final int totalExpenseCents;
  final int totalIncomeCents;
  final int netCashFlowCents; // totalIncome - totalExpense
  final int expenseTransactionCount;
  final int incomeTransactionCount;
  final List<FinancialTransaction> eligibleTransactions;
  final bool hasActivity;

  int get incomeCount => incomeTransactionCount;
  int get expenseCount => expenseTransactionCount;

  const DailyFinancialSummary({
    required this.date,
    required this.totalExpenseCents,
    required this.totalIncomeCents,
    required this.netCashFlowCents,
    required this.expenseTransactionCount,
    required this.incomeTransactionCount,
    required this.eligibleTransactions,
    required this.hasActivity,
  });

  /// Factory to calculate the summary from stored transactions for a target day
  /// Excludes internal transfers (type == transfer) and opening balance records.
  factory DailyFinancialSummary.fromTransactions({
    required DateTime targetDate,
    required List<FinancialTransaction> allTransactions,
  }) {
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);

    int expenses = 0;
    int income = 0;
    int expenseCount = 0;
    int incomeCount = 0;
    final List<FinancialTransaction> eligible = [];

    for (final tx in allTransactions) {
      // 1. Boundary filter in local time
      if (tx.transactionDate.isBefore(startOfDay) || tx.transactionDate.isAfter(endOfDay)) {
        continue;
      }

      // 2. Strict exclusion: Transfers between accounts (internal movement, not spending/earning)
      if (tx.type == TransactionType.transfer) {
        continue;
      }

      // 3. Strict exclusion: Opening balances
      final descLower = tx.description.toLowerCase().trim();
      if (descLower.contains('opening balance') || descLower.contains('initial balance')) {
        continue;
      }

      eligible.add(tx);

      if (tx.type == TransactionType.expense) {
        expenses += tx.amount;
        expenseCount++;
      } else if (tx.type == TransactionType.income) {
        income += tx.amount;
        incomeCount++;
      }
    }

    final net = income - expenses;
    final hasActivity = expenseCount > 0 || incomeCount > 0;

    return DailyFinancialSummary(
      date: targetDate,
      totalExpenseCents: expenses,
      totalIncomeCents: income,
      netCashFlowCents: net,
      expenseTransactionCount: expenseCount,
      incomeTransactionCount: incomeCount,
      eligibleTransactions: eligible,
      hasActivity: hasActivity,
    );
  }

  /// Builds a concise notification body for local notifications
  String toNotificationBody({String currencySymbol = 'ETB'}) {
    if (!hasActivity) {
      return 'Your daily check-in: No income or expenses recorded today. Take a moment to review your finances.';
    }

    final expenseFormatted = CurrencyFormatter.formatCents(totalExpenseCents);
    final incomeFormatted = CurrencyFormatter.formatCents(totalIncomeCents);

    final netSign = netCashFlowCents >= 0 ? '+' : '';
    final netFormatted = '$netSign${CurrencyFormatter.formatCents(netCashFlowCents)}';

    return 'Today: Expenses $expenseFormatted · Income $incomeFormatted · Net $netFormatted ($expenseTransactionCount ${expenseTransactionCount == 1 ? 'expense' : 'expenses'})';
  }

  /// Builds expanded lines for Android BigTextStyle notification view
  String toExpandedBigText({String currencySymbol = 'ETB'}) {
    if (!hasActivity) {
      return 'No income or expenses recorded today.\nTap to review your accounts or log new transactions.';
    }

    final expenseFormatted = CurrencyFormatter.formatCents(totalExpenseCents);
    final incomeFormatted = CurrencyFormatter.formatCents(totalIncomeCents);
    final netSign = netCashFlowCents >= 0 ? '+' : '';
    final netFormatted = '$netSign${CurrencyFormatter.formatCents(netCashFlowCents)}';

    final buffer = StringBuffer();
    buffer.writeln('• Total Expenses: $expenseFormatted ($expenseTransactionCount ${expenseTransactionCount == 1 ? 'transaction' : 'transactions'})');
    buffer.writeln('• Total Income: $incomeFormatted ($incomeCount ${incomeCount == 1 ? 'transaction' : 'transactions'})');
    buffer.write('• Net Cashflow: $netFormatted');

    return buffer.toString();
  }
}
