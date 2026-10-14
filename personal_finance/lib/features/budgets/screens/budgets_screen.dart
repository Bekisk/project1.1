import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/budgets/screens/add_edit_budget_sheet.dart';
import 'package:personal_finance/features/budgets/screens/budget_detail_screen.dart';
import 'package:personal_finance/features/budgets/services/budget_calculation_service.dart';

/// Complete Budget Management and Spending Progress Screen
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetsProvider>().loadBudgetData();
    });
  }

  Future<void> _pickCustomPeriod(BuildContext context) async {
    final provider = context.read<BudgetsProvider>();
    final (start, end) = provider.getActivePeriodDates();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: DateTimeRange(start: start, end: end),
    );

    if (picked != null) {
      provider.setPeriodFilter(
        BudgetPeriodFilter.custom,
        customStart: picked.start,
        customEnd: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<BudgetsProvider>();

    final summary = provider.overallSummary;
    final (periodStart, periodEnd) = provider.getActivePeriodDates();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets & Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded),
            tooltip: 'New Budget',
            onPressed: () => AddEditBudgetSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => provider.loadBudgetData(),
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
                onRefresh: () => provider.loadBudgetData(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    // 1. Period Selector Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildPeriodSelector(context, provider, isDark),
                      ),
                    ),

                    // 2. Active Period Dates subtitle
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white60 : Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              '${DateFormat('MMM d').format(periodStart)} – ${DateFormat('MMM d, yyyy').format(periodEnd)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Overall Budget Progress & Health Card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: _buildOverallBudgetCard(context, summary, isDark),
                      ),
                    ),

                    // 4. Alert Banner if any budgets exceeded or at risk
                    if (summary.exceededCount > 0 || summary.atRiskCount > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: _buildAlertBanner(context, summary, isDark),
                        ),
                      ),

                    // 5. Category Budgets Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Category Budgets',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${summary.categoryBudgetResults.length} active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 6. Category Budgets List or Empty State
                  if (summary.categoryBudgetResults.isEmpty && summary.overallBudgetResults.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, isDark),
                    )
                  else ...[
                    // Category Budget Cards
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final result = summary.categoryBudgetResults[index];
                            return _buildCategoryBudgetCard(context, result, isDark);
                          },
                          childCount: summary.categoryBudgetResults.length,
                        ),
                      ),
                    ),

                    // Overall / Custom Budgets Section (if any separate ones exist)
                    if (summary.overallBudgetResults.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                          child: Text(
                            'Overall & Custom Budgets',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final result = summary.overallBudgetResults[index];
                              return _buildCategoryBudgetCard(context, result, isDark);
                            },
                            childCount: summary.overallBudgetResults.length,
                          ),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 110)),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildPeriodSelector(BuildContext context, BudgetsProvider provider, bool isDark) {
    final current = provider.selectedPeriod;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight),
      ),
      child: Row(
        children: [
          _buildPeriodTab('This Month', BudgetPeriodFilter.thisMonth, current, provider, isDark),
          _buildPeriodTab('This Week', BudgetPeriodFilter.thisWeek, current, provider, isDark),
          _buildPeriodTab('Last Month', BudgetPeriodFilter.lastMonth, current, provider, isDark),
          _buildPeriodTab(
            'Custom',
            BudgetPeriodFilter.custom,
            current,
            provider,
            isDark,
            onTapOverride: () => _pickCustomPeriod(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(
    String label,
    BudgetPeriodFilter filter,
    BudgetPeriodFilter current,
    BudgetsProvider provider,
    bool isDark, {
    VoidCallback? onTapOverride,
  }) {
    final isSelected = current == filter;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onTapOverride != null) {
            onTapOverride();
          } else {
            provider.setPeriodFilter(filter);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppTheme.primaryNavy)
                    : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverallBudgetCard(
    BuildContext context,
    OverallBudgetSummary summary,
    bool isDark,
  ) {
    final isExceeded = summary.exceededCount > 0 || (summary.totalAllocatedCents > 0 && summary.totalSpentCents > summary.totalAllocatedCents);
    final isApproaching = summary.atRiskCount > 0;

    final Color statusColor = isExceeded
        ? AppTheme.expenseRed
        : isApproaching
            ? AppTheme.accentAmber
            : AppTheme.primaryGreen;

    return FintechCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overall Spending Progress',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExceeded
                      ? 'Exceeded'
                      : isApproaching
                          ? 'Approaching Limit'
                          : 'On Track',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.visualProgress,
              minHeight: 12,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${summary.percentageConsumed.toStringAsFixed(1)}% consumed',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
              ),
              Text(
                'Limit: ${CurrencyFormatter.formatCents(summary.totalAllocatedCents)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Two-column Spent vs Remaining
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Spent', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatCents(summary.totalSpentCents),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExceeded ? 'Exceeded By' : 'Remaining Available',
                      style: TextStyle(
                        fontSize: 11,
                        color: isExceeded ? AppTheme.expenseRed : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isExceeded
                          ? '+${CurrencyFormatter.formatCents(summary.exceededCents)}'
                          : CurrencyFormatter.formatCents(summary.availableCents),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isExceeded ? AppTheme.expenseRed : AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner(BuildContext context, OverallBudgetSummary summary, bool isDark) {
    final isExceeded = summary.exceededCount > 0;
    final color = isExceeded ? AppTheme.expenseRed : AppTheme.accentAmber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(isExceeded ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isExceeded
                  ? '${summary.exceededCount} budget(s) have exceeded their allocated spending limit!'
                  : '${summary.atRiskCount} budget(s) are approaching their alert threshold limit.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetCard(
    BuildContext context,
    BudgetCalculationResult result,
    bool isDark,
  ) {
    final budget = result.budget;
    final category = result.category;

    final isExceeded = result.healthStatus == BudgetHealthStatus.exceeded;
    final isApproaching = result.healthStatus == BudgetHealthStatus.approachingLimit;

    final Color statusColor = isExceeded
        ? AppTheme.expenseRed
        : isApproaching
            ? AppTheme.accentAmber
            : AppTheme.primaryGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: FintechCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => BudgetDetailScreen(budgetId: budget.id),
            ),
          );
        },
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.pie_chart_rounded, size: 18, color: statusColor),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.formatCents(result.spentCents)} of ${CurrencyFormatter.formatCents(budget.amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${result.percentageConsumed.toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: statusColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isExceeded
                          ? 'Over +${CurrencyFormatter.formatCents(result.exceededCents)}'
                          : '${CurrencyFormatter.formatCents(result.availableCents)} left',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isExceeded ? AppTheme.expenseRed : AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: result.visualProgress,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pie_chart_outline_rounded,
                size: 48,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Budgets Set For This Period',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a popular budget template below or customize your own limits to start tracking expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // 1-tap Category Budget Templates
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'QUICK START TEMPLATES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBudgetTemplateChip(
                  context: context,
                  label: '+ Food & Dining (Monthly)',
                  categoryName: 'Food',
                  suggestedAmount: 500000, // 5,000 ETB
                  frequency: BudgetFrequency.monthly,
                  color: AppTheme.accentCoral,
                  isDark: isDark,
                ),
                _buildBudgetTemplateChip(
                  context: context,
                  label: '+ Transport',
                  categoryName: 'Transport',
                  suggestedAmount: 300000, // 3,000 ETB
                  frequency: BudgetFrequency.monthly,
                  color: AppTheme.accentTeal,
                  isDark: isDark,
                ),
                _buildBudgetTemplateChip(
                  context: context,
                  label: '+ Bills & Subscriptions',
                  categoryName: 'Bills',
                  suggestedAmount: 200000, // 2,000 ETB
                  frequency: BudgetFrequency.monthly,
                  color: AppTheme.accentAmber,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () => AddEditBudgetSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create Custom Budget'),
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

  Widget _buildBudgetTemplateChip({
    required BuildContext context,
    required String label,
    required String categoryName,
    required int suggestedAmount,
    required BudgetFrequency frequency,
    required Color color,
    required bool isDark,
  }) {
    return ActionChip(
      onPressed: () {
        AddEditBudgetSheet.show(
          context,
          initialName: label.replaceFirst('+ ', ''),
          initialCategoryName: categoryName,
          initialAmount: suggestedAmount,
          initialFrequency: frequency,
        );
      },
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.primaryText : AppTheme.textDark,
        ),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
