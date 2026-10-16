import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/formatting/date_formatter.dart';
import 'package:personal_finance/core/widgets/animated_balance_text.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/dashboard/widgets/burn_rate_card.dart';
import 'package:personal_finance/features/dashboard/widgets/inflow_outflow_ratio_bar.dart';
import 'package:personal_finance/features/dashboard/widgets/spending_distribution_donut_chart.dart';
import 'package:personal_finance/features/dashboard/widgets/swipeable_multi_account_balance_card.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/profile/screens/profile_screen.dart';
import 'package:personal_finance/features/profile/widgets/profile_avatar.dart';
import 'package:personal_finance/features/recurring/screens/subscriptions_screen.dart';
import 'package:personal_finance/features/recurring/widgets/subscription_summary_card.dart';
import 'package:personal_finance/features/sms_parser/widgets/sms_scanner_dialog.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/screens/add_transaction_sheet.dart';
import 'package:personal_finance/features/transactions/screens/transaction_detail_sheet.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToTransactions;
  final VoidCallback onNavigateToGoals;
  final VoidCallback onNavigateToBudgets;
  final VoidCallback onAddTransaction;
  final VoidCallback? onNavigateToSettings;

  const DashboardScreen({
    super.key,
    required this.onNavigateToTransactions,
    required this.onNavigateToGoals,
    required this.onNavigateToBudgets,
    required this.onAddTransaction,
    this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  'Updating portfolio...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          );
        }

        final summary = provider.summary;
        final hasTransactions = summary.recentTransactions.isNotEmpty;

        return LiquidAtmosphereBackground(
          child: RefreshIndicator(
            color: AppTheme.primaryGreen,
            onRefresh: () => provider.loadDashboardData(),
            child: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Greeting & Notification Profile Bar
                    _buildTopGreetingBar(context, isDark),

                    // 1. Swipeable Multi-Account Balance Hero Card
                    SwipeableMultiAccountBalanceCard(
                      accounts: summary.accounts,
                      accountBalances: summary.accountBalances,
                      accountBalanceInfos: summary.accountBalanceInfos,
                      mainAccountId: context
                          .watch<UserProfileProvider>()
                          .mainAccountId,
                      designatedSavingsAccountId: context
                          .watch<UserProfileProvider>()
                          .designatedSavingsAccountId,
                      isDark: isDark,
                      onAddAccount: onAddTransaction,
                    ),
                    const SizedBox(height: 18),

                    // Quick Action Circles (Send, Withdraw, Add Money, Paybill, Bank SMS)
                    _buildQuickActionRow(context, isDark),
                    const SizedBox(height: 18),

                    // Feature 2: Financial Health & Burn Rate Analytics Dashboard
                    BurnRateCard(summary: summary, isDark: isDark),
                    const SizedBox(height: 16),

                    // Feature 2: Inflow vs. Outflow Cash Flow Bar
                    InflowOutflowRatioBar(
                      totalIncomeCents: summary.monthIncome,
                      totalExpenseCents: summary.monthExpense,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // Feature 2: Category Distribution Donut Chart
                    SpendingDistributionDonutChart(
                      topCategories: summary.topCategories,
                      totalExpenseCents: summary.monthExpense,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),

                    // Feature 4: Recurring Expenses & Subscription Fixed Commitment Card
                    SubscriptionSummaryCard(
                      isDark: isDark,
                      onTap: () => SubscriptionsScreen.navigate(context),
                    ),
                    const SizedBox(height: 16),

                    // High-Impact Income vs Expense Cashflow Card
                    _buildCashflowBreakdownCard(context, summary, isDark),
                    const SizedBox(height: 16),

                    // Weekly Spending Trend Analytics Chart
                    _buildSpendingAnalyticsCard(context, summary, isDark),
                    const SizedBox(height: 16),

                    // Savings Goals Progress & Insight
                    _buildSavingsGoalProgressCard(context, summary, isDark),
                    const SizedBox(height: 24),

                    // 5. Recent Transactions Header & Dynamic List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recent Transactions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.elevatedCharcoal
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${summary.recentTransactions.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppTheme.pureWhite
                                      : AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: onNavigateToTransactions,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: isDark
                                ? AppTheme.primaryGreen
                                : AppTheme.primaryNavy,
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'View All',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (!hasTransactions)
                      _buildEmptyStateCard(
                        context,
                        title: 'No Transactions Recorded',
                        description: 'Keep track of your income and day-to-day expenses with instant analytics.',
                        buttonText: 'Add First Transaction',
                        icon: Icons.receipt_long_rounded,
                        onTap: () => AddTransactionSheet.show(context),
                      )
                    else
                      ...summary.recentTransactions.map(
                        (tx) =>
                            _buildTransactionTile(context, tx, summary, isDark),
                      ),

                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 17) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }

  Widget _buildTopGreetingBar(BuildContext context, bool isDark) {
    final profileProvider = context.watch<UserProfileProvider>();
    final profile = profileProvider.profile;
    final displayName = profileProvider.displayName;
    final imagePath = profile?.profileImagePath;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => ProfileScreen.navigate(context),
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  // Real Avatar with fallback initials / icon
                  ProfileAvatar(
                    imagePath: imagePath,
                    displayName: displayName,
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppTheme.secondaryText
                                : AppTheme.textSecondaryLight,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: isDark
                                ? AppTheme.primaryText
                                : AppTheme.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Settings / Profile shortcut button
          GestureDetector(
            onTap: () {
              if (onNavigateToSettings != null) {
                onNavigateToSettings!();
              } else {
                ProfileScreen.navigate(context);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppTheme.elevatedCharcoal : Colors.white,
                border: Border.all(
                  color: isDark
                      ? AppTheme.borderPrimary
                      : const Color(0xFFD1EBE3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 20,
                color: isDark ? AppTheme.pureWhite : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleActionButton(
            context,
            icon: Icons.north_east_rounded,
            label: 'Send',
            onTap: () => AddTransactionSheet.show(
              context,
              initialType: TransactionType.expense,
            ),
            isDark: isDark,
          ),
          _buildCircleActionButton(
            context,
            icon: Icons.mark_email_read_rounded,
            label: 'Bank SMS',
            onTap: () => SmsScannerDialog.show(context),
            isDark: isDark,
          ),
          _buildCircleActionButton(
            context,
            icon: Icons.add_rounded,
            label: 'Add Money',
            onTap: () => AddTransactionSheet.show(
              context,
              initialType: TransactionType.income,
            ),
            isDark: isDark,
          ),
          _buildCircleActionButton(
            context,
            icon: Icons.receipt_long_rounded,
            label: 'Paybill',
            onTap: () => AddTransactionSheet.show(
              context,
              initialType: TransactionType.transfer,
            ),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppTheme.elevatedCharcoal : Colors.white,
              border: Border.all(
                color: isDark
                    ? AppTheme.borderPrimary
                    : const Color(0xFFD1EBE3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: isDark ? AppTheme.pureWhite : const Color(0xFF0F5747),
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.secondaryText : AppTheme.textDark,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowBreakdownCard(
    BuildContext context,
    DashboardSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final netPositive = summary.netCashFlow >= 0;

    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<DashboardPeriod>(
                tooltip: 'Select Reporting Period',
                onSelected: (period) async {
                  final provider = context.read<DashboardProvider>();
                  if (period == DashboardPeriod.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      provider.setPeriod(
                        DashboardPeriod.custom,
                        customStart: picked.start,
                        customEnd: picked.end,
                      );
                    }
                  } else {
                    provider.setPeriod(period);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: DashboardPeriod.thisMonth,
                    child: Text('This Month'),
                  ),
                  const PopupMenuItem(
                    value: DashboardPeriod.lastMonth,
                    child: Text('Last Month'),
                  ),
                  const PopupMenuItem(
                    value: DashboardPeriod.thisYear,
                    child: Text('This Year'),
                  ),
                  const PopupMenuItem(
                    value: DashboardPeriod.allTime,
                    child: Text('All Time'),
                  ),
                  const PopupMenuItem(
                    value: DashboardPeriod.custom,
                    child: Text('Custom Date Range...'),
                  ),
                ],
                child: Row(
                  children: [
                    Text(
                      '${summary.periodLabel} Flow',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 20),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (netPositive
                              ? AppTheme.primaryGreen
                              : AppTheme.expenseRed)
                          .withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      netPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: netPositive
                          ? AppTheme.primaryGreen
                          : AppTheme.expenseRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      netPositive ? 'Net Positive' : 'Net Negative',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: netPositive
                            ? AppTheme.primaryGreen
                            : AppTheme.expenseRed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Income Column
              Expanded(
                child: _buildCashflowPill(
                  context,
                  title: 'Income',
                  cents: summary.monthIncome,
                  color: AppTheme.incomeGreen,
                  icon: Icons.arrow_downward_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              // Expense Column
              Expanded(
                child: _buildCashflowPill(
                  context,
                  title: 'Expenses',
                  cents: summary.monthExpense,
                  color: AppTheme.expenseRed,
                  icon: Icons.arrow_upward_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          // Progress bar comparison
          _buildCashflowVisualRatio(summary, isDark),
        ],
      ),
    );
  }

  Widget _buildCashflowPill(
    BuildContext context, {
    required String title,
    required int cents,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBalanceText(
              cents: cents,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashflowVisualRatio(DashboardSummary summary, bool isDark) {
    final total = summary.monthIncome + summary.monthExpense;
    final incomeRatio = total > 0
        ? (summary.monthIncome / total).clamp(0.0, 1.0)
        : 0.5;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: (incomeRatio * 100).toInt(),
                  child: Container(color: AppTheme.incomeGreen),
                ),
                Expanded(
                  flex: ((1.0 - incomeRatio) * 100).toInt(),
                  child: Container(color: AppTheme.expenseRed),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(incomeRatio * 100).toStringAsFixed(0)}% Inflow',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.incomeGreen,
              ),
            ),
            Text(
              '${((1.0 - incomeRatio) * 100).toStringAsFixed(0)}% Outflow',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.expenseRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpendingAnalyticsCard(
    BuildContext context,
    DashboardSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final weeklySpending = summary.weeklySpending;

    int maxCents = 1;
    for (var val in weeklySpending) {
      if (val > maxCents) maxCents = val;
    }

    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Spending Trend',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const Icon(
                Icons.bar_chart_rounded,
                size: 20,
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day Bar Chart using fl_chart
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCents.toDouble() * 1.15,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? AppTheme.elevatedCharcoal : Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        CurrencyFormatter.formatCents(rod.toY.round()),
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days[idx],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final cents = weeklySpending[i];
                  final isLatest = i == 6;
                  // For 0 spend, provide a subtle minimum baseline so the day is visually anchored
                  final displayValue = cents > 0 ? cents.toDouble() : 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: displayValue,
                        gradient: LinearGradient(
                          colors: isLatest
                              ? (isDark
                                    ? [
                                        AppTheme.primaryGreen,
                                        const Color(0xFF059669),
                                      ]
                                    : [
                                        const Color(0xFF10B981),
                                        const Color(0xFF059669),
                                      ])
                              : (isDark
                                    ? [
                                        const Color(0xFF334155),
                                        const Color(0xFF1E293B),
                                      ]
                                    : [
                                        const Color(0xFF94A3B8),
                                        const Color(0xFF64748B),
                                      ]),
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          if (weeklySpending.every((c) => c == 0)) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                'No expenses recorded yet this week',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ),
          ],

          if (summary.topCategories.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Top Expense Categories',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppTheme.textSecondaryDark
                    : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 10),
            ...summary.topCategories.take(3).map((catSpend) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    CategoryIconBadge(
                      iconKey: catSpend.category.iconKey,
                      colorKey: catSpend.category.colorKey,
                      size: 28,
                      iconSize: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                catSpend.category.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatCents(
                                  catSpend.totalCents,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: catSpend.percentage,
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? AppTheme.borderPrimary
                                  : const Color(0xFFF1F5F9),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CategoryIconBadge.getColor(
                                  catSpend.category.colorKey,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildSavingsGoalProgressCard(
    BuildContext context,
    DashboardSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final target = summary.goalsTotalTarget;
    final saved = summary.goalsTotalSaved;
    final hasGoals = target > 0;
    final double percent = hasGoals ? (saved / target).clamp(0.0, 1.0) : 0.0;

    return FintechCard(
      onTap: onNavigateToGoals,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      color: AppTheme.accentAmber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Savings Goals',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              if (hasGoals)
                Text(
                  '${(percent * 100).toStringAsFixed(0)}% reached',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryNavy,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasGoals) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'No active savings goals set. Tap to start building your emergency fund or target purchase.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 8,
                backgroundColor: isDark
                    ? AppTheme.borderPrimary
                    : const Color(0xFFF1F5F9),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved: ${CurrencyFormatter.formatCents(saved)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.pureWhite : AppTheme.primaryNavy,
                  ),
                ),
                Text(
                  'Target: ${CurrencyFormatter.formatCents(target)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    FinancialTransaction tx,
    DashboardSummary summary,
    bool isDark,
  ) {
    final isExpense = tx.type == TransactionType.expense;
    final isIncome = tx.type == TransactionType.income;
    final amountColor = isExpense
        ? AppTheme.expenseRed
        : isIncome
        ? AppTheme.incomeGreen
        : AppTheme.transferBlue;

    final prefix = isExpense ? '-' : (isIncome ? '+' : '');

    // Category icon badge lookup
    final cat = tx.categoryId != null
        ? summary.categoryMap[tx.categoryId]
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: FintechCard(
        onTap: () => TransactionDetailSheet.show(context, tx),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 20,
        child: Row(
          children: [
            if (cat != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppTheme.elevatedCharcoal
                      : const Color(0xFFE2F4EE),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderPrimary
                        : const Color(0xFFC7EADB),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: CategoryIconBadge(
                    iconKey: cat.iconKey,
                    colorKey: cat.colorKey,
                    size: 30,
                    iconSize: 16,
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppTheme.elevatedCharcoal
                      : const Color(0xFFE2F4EE),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.borderPrimary
                        : const Color(0xFFC7EADB),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isExpense
                        ? Icons.arrow_upward_rounded
                        : isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.swap_horiz_rounded,
                    color: amountColor,
                    size: 20,
                  ),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? AppTheme.primaryText : AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormatter.formatRelative(tx.transactionDate)} • ${tx.type.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppTheme.secondaryText
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$prefix${CurrencyFormatter.formatCents(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.2,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FintechCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.elevatedCharcoal
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 36,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
