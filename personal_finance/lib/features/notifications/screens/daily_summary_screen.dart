import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/notifications/models/daily_financial_summary.dart';
import 'package:personal_finance/features/notifications/services/notification_service.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:personal_finance/features/transactions/screens/add_transaction_sheet.dart';

/// Screen displayed when the user taps on the Daily Financial Summary notification
/// or inspects today's financial summary breakdown in detail.
class DailySummaryScreen extends StatefulWidget {
  final DateTime? targetDate;

  const DailySummaryScreen({super.key, this.targetDate});

  static void navigate(BuildContext context, {DateTime? targetDate}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailySummaryScreen(targetDate: targetDate),
      ),
    );
  }

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  DailyFinancialSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final target = widget.targetDate ?? DateTime.now();
    final transactionsProvider = context.read<TransactionsProvider>();

    // If transactions are loaded, use the in-memory repository for maximum responsiveness
    final allTxs = transactionsProvider.allTransactions;
    if (allTxs.isNotEmpty) {
      final calculated = DailyFinancialSummary.fromTransactions(
        targetDate: target,
        allTransactions: allTxs,
      );
      setState(() {
        _summary = calculated;
        _isLoading = false;
      });
    } else {
      // Fallback to database direct query via NotificationService
      final calculated = await NotificationService.instance.getTodaySummary();
      setState(() {
        _summary = calculated;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final date = widget.targetDate ?? DateTime.now();
    final dateFormatted = DateFormat('EEEE, MMMM d, y').format(date);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Daily Financial Summary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidAtmosphereBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppTheme.primaryGreen,
                  onRefresh: () async {
                    await context
                        .read<TransactionsProvider>()
                        .loadTransactions();
                    await _loadSummary();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date header chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.primaryAccent.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.today_rounded,
                                size: 16,
                                color: AppTheme.primaryAccent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Hero Cash Flow Breakdown Card
                        _buildHeroSummaryCard(context, _summary!, isDark),
                        const SizedBox(height: 20),

                        // Transaction List Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's Activity",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
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
                                '${_summary!.eligibleTransactions.length}',
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
                        const SizedBox(height: 12),

                        // Transactions List or truthful empty state
                        if (!_summary!.hasActivity)
                          _buildEmptyActivityCard(context, isDark)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _summary!.eligibleTransactions.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final tx = _summary!.eligibleTransactions[index];
                              return _buildTransactionItem(context, tx, isDark);
                            },
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeroSummaryCard(
    BuildContext context,
    DailyFinancialSummary summary,
    bool isDark,
  ) {
    final netColor = summary.netCashFlowCents >= 0
        ? AppTheme.accentTeal
        : AppTheme.accentCoral;

    final netSign = summary.netCashFlowCents >= 0 ? '+' : '';

    return FintechCard(
      padding: const EdgeInsets.all(20),
      gradient: isDark
          ? AppTheme.walletHeroGradient
          : const LinearGradient(
              colors: [Color(0xFF0F5747), Color(0xFF093E33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NET DAILY CASHFLOW',
                style: TextStyle(
                  color: Color(0xFFBBE5DA),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(
                Icons.shield_rounded,
                color: AppTheme.primaryAccent,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            '$netSign${CurrencyFormatter.formatCents(summary.netCashFlowCents)}',
            style: TextStyle(
              color: netColor,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 18),

          // Income vs Expense Metrics Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.arrow_downward_rounded,
                            size: 14,
                            color: AppTheme.accentTeal,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Income',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatCents(summary.totalIncomeCents),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${summary.incomeTransactionCount} ${summary.incomeTransactionCount == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.arrow_upward_rounded,
                            size: 14,
                            color: AppTheme.accentCoral,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Expenses',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatCents(
                          summary.totalExpenseCents,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${summary.expenseTransactionCount} ${summary.expenseTransactionCount == 1 ? 'entry' : 'entries'}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    FinancialTransaction tx,
    bool isDark,
  ) {
    final isExpense = tx.type == TransactionType.expense;
    final color = isExpense ? AppTheme.accentCoral : AppTheme.accentTeal;
    final prefix = isExpense ? '-' : '+';

    return FintechCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isExpense ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('hh:mm a').format(tx.transactionDate),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '$prefix${CurrencyFormatter.formatCents(tx.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityCard(BuildContext context, bool isDark) {
    return FintechCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppTheme.primaryAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Financial Records Today',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Take a moment to record your daily spending or income to keep your analytics up to date.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => AddTransactionSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
