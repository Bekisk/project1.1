import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/animated_balance_text.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:personal_finance/features/transactions/screens/add_transaction_sheet.dart';
import 'package:personal_finance/features/transactions/screens/transaction_detail_sheet.dart';
import 'package:personal_finance/features/transactions/screens/transaction_filter_sheet.dart';

/// Full-featured Transactions Management Screen with period summaries, type tabs,
/// date grouping, live search, multi-dimensional filters, and detail dialogs.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionsProvider>().loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, d MMMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TransactionsProvider>();

    final filter = provider.filter;
    final grouped = provider.groupedTransactionsByDate;
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : AppTheme.textDark),
                decoration: InputDecoration(
                  hintText: 'Search title, account, category...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                onChanged: (val) => provider.setSearchQuery(val),
              )
            : const Text('Transactions'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  provider.setSearchQuery('');
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () => setState(() => _isSearching = true),
            ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filter',
                onPressed: () => TransactionFilterSheet.show(context),
              ),
              if (filter.hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                strokeWidth: 2.5,
              ),
            )
          : LiquidAtmosphereBackground(
              child: RefreshIndicator(
                color: AppTheme.primaryGreen,
                onRefresh: () => provider.loadTransactions(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // 1. Period Cashflow Summary Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildSummaryCard(context, provider, isDark),
                      ),
                    ),

                    // 2. Segmented Transaction Type Tabs
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildTypeTabs(context, provider, isDark),
                      ),
                    ),

                    // 3. Active filter indicator chips
                    if (filter.hasActiveFilters)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _buildActiveFilterBar(context, provider, isDark),
                        ),
                      ),

                    // 4. Grouped Transactions or Empty State
                    if (sortedDates.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context, provider, isDark),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 110),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final date = sortedDates[index];
                              final transactionsOnDate = grouped[date]!;
                              return _buildDateGroupSection(
                                context,
                                date,
                                transactionsOnDate,
                                provider,
                                isDark,
                              );
                            },
                            childCount: sortedDates.length,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, TransactionsProvider provider, bool isDark) {
    final income = provider.filteredTotalIncome;
    final expense = provider.filteredTotalExpense;
    final net = provider.filteredNetCashFlow;
    final netPositive = net >= 0;

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Period Cash Flow (${provider.filter.datePreset.name.toUpperCase()})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (netPositive ? AppTheme.primaryGreen : AppTheme.expenseRed)
                        .withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Net: ${CurrencyFormatter.formatCents(net)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: netPositive ? AppTheme.primaryGreen : AppTheme.expenseRed,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.incomeGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 14, color: AppTheme.incomeGreen),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Income', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          AnimatedBalanceText(
                            cents: income,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.incomeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppTheme.expenseRed),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expense', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            AnimatedBalanceText(
                              cents: expense,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.expenseRed,
                              ),
                            ),
                          ],
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

  Widget _buildTypeTabs(BuildContext context, TransactionsProvider provider, bool isDark) {
    final currentType = provider.filter.type;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.inputCharcoal : const Color(0xFFE2F4EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.borderPrimary : const Color(0xFFC7EADB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            label: 'All',
            isSelected: currentType == null,
            onTap: () => provider.setTransactionType(null),
            isDark: isDark,
          ),
          _buildTabItem(
            label: 'Expenses',
            isSelected: currentType == TransactionType.expense,
            onTap: () => provider.setTransactionType(TransactionType.expense),
            isDark: isDark,
          ),
          _buildTabItem(
            label: 'Income',
            isSelected: currentType == TransactionType.income,
            onTap: () => provider.setTransactionType(TransactionType.income),
            isDark: isDark,
          ),
          _buildTabItem(
            label: 'Transfers',
            isSelected: currentType == TransactionType.transfer,
            onTap: () => provider.setTransactionType(TransactionType.transfer),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.pureWhite : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected && isDark
                ? null
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppTheme.pureBlack : const Color(0xFF0F5747))
                    : (isDark ? AppTheme.secondaryGray : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterBar(BuildContext context, TransactionsProvider provider, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.primaryGreen),
              const SizedBox(width: 4),
              Text(
                '${provider.filter.activeFilterCount} Active Filters',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => provider.resetFilters(),
          child: const Text(
            'Clear',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildDateGroupSection(
    BuildContext context,
    DateTime date,
    List<FinancialTransaction> transactions,
    TransactionsProvider provider,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateHeader(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              Text(
                '${transactions.length} items',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
        ...transactions.map(
          (tx) => _buildTransactionCard(context, tx, provider, isDark),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(
    BuildContext context,
    FinancialTransaction tx,
    TransactionsProvider provider,
    bool isDark,
  ) {
    final isExpense = tx.type == TransactionType.expense;
    final isIncome = tx.type == TransactionType.income;
    final isTransfer = tx.type == TransactionType.transfer;

    final color = isExpense
        ? AppTheme.expenseRed
        : isIncome
            ? AppTheme.incomeGreen
            : AppTheme.transferBlue;

    final prefix = isExpense ? '-' : (isIncome ? '+' : '');

    final sourceAccount = provider.accountMap[tx.accountId]?.name ?? 'Account';
    final destinationAccount = tx.destinationAccountId != null
        ? (provider.accountMap[tx.destinationAccountId]?.name ?? 'Account')
        : null;

    final category = tx.categoryId != null ? provider.categoryMap[tx.categoryId] : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: FintechCard(
        onTap: () => TransactionDetailSheet.show(context, tx),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 16,
        child: Row(
          children: [
            // Icon Badge
            if (category != null)
              CategoryIconBadge(
                iconKey: category.iconKey,
                colorKey: category.colorKey,
                size: 42,
                iconSize: 20,
              )
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.swap_horiz_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
            const SizedBox(width: 12),

            // Description & Account
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  if (isTransfer)
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sourceAccount,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded, size: 11, color: AppTheme.transferBlue),
                        ),
                        Flexible(
                          child: Text(
                            destinationAccount ?? 'Account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sourceAccount,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (category != null) ...[
                          const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Flexible(
                            child: Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount and Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$prefix${CurrencyFormatter.formatCents(tx.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: -0.2,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('hh:mm a').format(tx.transactionDate.toLocal()),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TransactionsProvider provider, bool isDark) {
    final hasFilter = provider.filter.hasActiveFilters;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.elevatedCharcoal : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFilter ? Icons.filter_alt_off_rounded : Icons.receipt_long_rounded,
                size: 44,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'No Matching Transactions' : 'No Transactions Recorded',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              hasFilter
                  ? 'Try modifying your search or resetting active filters to view your transaction records.'
                  : 'Start tracking your daily income, expense, and account transfers to build your financial history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: hasFilter
                  ? () => provider.resetFilters()
                  : () => AddTransactionSheet.show(context),
              icon: Icon(hasFilter ? Icons.restart_alt_rounded : Icons.add_rounded, size: 18),
              label: Text(hasFilter ? 'Reset Filters' : 'Add First Transaction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
