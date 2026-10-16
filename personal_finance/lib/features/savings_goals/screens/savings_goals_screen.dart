import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/widgets/liquid_atmosphere_background.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/providers/savings_goals_provider.dart';
import 'package:personal_finance/features/savings_goals/screens/add_contribution_sheet.dart';
import 'package:personal_finance/features/savings_goals/screens/add_edit_goal_sheet.dart';
import 'package:personal_finance/features/savings_goals/screens/goal_detail_screen.dart';
import 'package:personal_finance/features/savings_goals/services/savings_calculation_service.dart';
import 'package:provider/provider.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavingsGoalsProvider>().loadGoalsData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String iconKey) {
    switch (iconKey) {
      case 'emergency':
        return Icons.health_and_safety_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'person':
        return Icons.person_rounded;
      default:
        return Icons.savings_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Emergency Fund':
        return AppTheme.primaryGreen;
      case 'Education':
        return AppTheme.accentTeal;
      case 'Technology':
        return AppTheme.accentBlue;
      case 'Business':
        return AppTheme.accentPurple;
      case 'Travel':
        return AppTheme.accentAmber;
      case 'Housing':
        return AppTheme.accentCoral;
      case 'Personal':
        return AppTheme.accentIndigo;
      default:
        return AppTheme.primaryNavy;
    }
  }

  void _showSortSheet(BuildContext context) {
    final provider = context.read<SavingsGoalsProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Sort Goals By',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              _sortTile(
                ctx,
                provider,
                'Highest Priority',
                GoalSortOption.highestPriority,
                Icons.priority_high_rounded,
              ),
              _sortTile(
                ctx,
                provider,
                'Target Date',
                GoalSortOption.targetDate,
                Icons.event_rounded,
              ),
              _sortTile(
                ctx,
                provider,
                'Highest Progress',
                GoalSortOption.highestProgress,
                Icons.trending_up_rounded,
              ),
              _sortTile(
                ctx,
                provider,
                'Lowest Progress',
                GoalSortOption.lowestProgress,
                Icons.trending_down_rounded,
              ),
              _sortTile(
                ctx,
                provider,
                'Recently Created',
                GoalSortOption.recentlyCreated,
                Icons.access_time_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(
    BuildContext ctx,
    SavingsGoalsProvider provider,
    String title,
    GoalSortOption option,
    IconData icon,
  ) {
    final isSelected = provider.sortOption == option;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryGreen : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppTheme.primaryGreen)
          : null,
      onTap: () {
        provider.setSortOption(option);
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SavingsGoalsProvider>();

    final summary = provider.overallSummary;
    final goals = provider.filteredGoals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort Goals',
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => provider.loadGoalsData(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84.0),
        child: FloatingActionButton(
          onPressed: () => AddEditGoalSheet.show(context),
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          tooltip: 'Create Goal',
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
              ),
            )
          : LiquidAtmosphereBackground(
              child: RefreshIndicator(
                onRefresh: () => provider.loadGoalsData(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    // Total Savings Hero Card
                    _buildTotalSavingsHeroCard(context, summary, isDark),
                    const SizedBox(height: 16),

                    // Search and Status Filters
                    _buildSearchBarAndFilterChips(context, provider, isDark),
                    const SizedBox(height: 16),

                    // Goals List
                    if (goals.isEmpty)
                      _buildEmptyState(context, provider, isDark)
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: goals.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          final goalSummary = provider.getSummaryForGoal(goal);
                          return _buildGoalCard(
                            context,
                            goal,
                            goalSummary,
                            isDark,
                          );
                        },
                      ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTotalSavingsHeroCard(
    BuildContext context,
    OverallSavingsSummary summary,
    bool isDark,
  ) {
    final target = summary.totalActiveTarget;
    final saved = summary.totalActiveSaved;
    final remaining = summary.totalActiveRemaining;
    final percent = summary.overallProgressPercent;
    final clamped = (percent / 100.0).clamp(0.0, 1.0);

    return FintechCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        colors: isDark
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
            : [AppTheme.primaryNavy, const Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.savings_rounded,
                    color: AppTheme.accentAmber,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Active Savings Target',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${percent.toStringAsFixed(0)}% reached',
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Big total saved
          Text(
            CurrencyFormatter.formatCents(saved),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Target: ${CurrencyFormatter.formatCents(target)} • ${CurrencyFormatter.formatCents(remaining)} left',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Linear Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Count chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metricPill(
                '${summary.activeGoalsCount} Active Goals',
                Icons.flag_rounded,
                Colors.white70,
              ),
              _metricPill(
                '${summary.completedGoalsCount} Completed',
                Icons.check_circle_rounded,
                AppTheme.accentTeal,
              ),
              if (summary.pausedGoalsCount > 0)
                _metricPill(
                  '${summary.pausedGoalsCount} Paused',
                  Icons.pause_circle_rounded,
                  AppTheme.accentAmber,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBarAndFilterChips(
    BuildContext context,
    SavingsGoalsProvider provider,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: (val) => provider.setSearchQuery(val),
          decoration: InputDecoration(
            hintText: 'Search goals (e.g. Laptop, Tuition)...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),

        // Status filter chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(provider, 'Active', GoalStatus.active),
              const SizedBox(width: 8),
              _filterChip(provider, 'Completed', GoalStatus.completed),
              const SizedBox(width: 8),
              _filterChip(provider, 'Paused', GoalStatus.paused),
              const SizedBox(width: 8),
              _filterChip(provider, 'Archived', GoalStatus.archived),
              const SizedBox(width: 8),
              _filterChip(provider, 'All Goals', null),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    SavingsGoalsProvider provider,
    String label,
    GoalStatus? status,
  ) {
    final isSelected = provider.filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) provider.setFilterStatus(status);
      },
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    SavingsGoal goal,
    GoalProgressSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final percent = summary.progressPercent;
    final clamped = summary.visualClampedProgress;
    final catColor = _getCategoryColor(goal.category);
    final catIcon = _getCategoryIcon(goal.iconKey);

    return FintechCard(
      onTap: () => GoalDetailScreen.navigate(context, goal.id),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon Badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catIcon, color: catColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          goal.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (goal.targetDate != null) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            DateFormat('MMM yyyy').format(goal.targetDate!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.isCompleted
                      ? AppTheme.accentTeal.withValues(alpha: 0.15)
                      : AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: summary.isCompleted
                        ? AppTheme.accentTeal
                        : AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amounts row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(summary.totalSaved),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Target',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(goal.targetAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    summary.excessAmount > 0 ? 'Surplus' : 'Remaining',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    summary.excessAmount > 0
                        ? '+${CurrencyFormatter.formatCents(summary.excessAmount)}'
                        : CurrencyFormatter.formatCents(
                            summary.remainingAmount,
                          ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: summary.excessAmount > 0
                          ? AppTheme.accentTeal
                          : AppTheme.accentCoral,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 6,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                summary.isCompleted
                    ? AppTheme.accentTeal
                    : AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick actions footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.status == GoalStatus.completed
                      ? 'Completed 🎉'
                      : (summary.planResult?.statusDescription ??
                            '${summary.milestones.where((m) => m.isReached).length}/5 milestones reached'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => AddContributionSheet.show(context, goal: goal),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Add Money',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryNavy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    SavingsGoalsProvider provider,
    bool isDark,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                size: 52,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Savings Goals Found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a popular savings template below or create your own custom goal to start tracking progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Quick Start Template Chips
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
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildGoalTemplateChip(
                  context: context,
                  label: '+ Emergency Fund',
                  category: 'Emergency Fund',
                  iconKey: 'emergency',
                  targetAmount: 5000000, // 50,000 ETB
                  isDark: isDark,
                  color: AppTheme.primaryGreen,
                ),
                _buildGoalTemplateChip(
                  context: context,
                  label: '+ Laptop / Tech',
                  category: 'Technology',
                  iconKey: 'laptop',
                  targetAmount: 8500000, // 85,000 ETB
                  isDark: isDark,
                  color: AppTheme.accentBlue,
                ),
                _buildGoalTemplateChip(
                  context: context,
                  label: '+ University / Tuition',
                  category: 'Education',
                  iconKey: 'school',
                  targetAmount: 3000000, // 30,000 ETB
                  isDark: isDark,
                  color: AppTheme.accentTeal,
                ),
                _buildGoalTemplateChip(
                  context: context,
                  label: '+ Travel / Vacation',
                  category: 'Travel',
                  iconKey: 'flight',
                  targetAmount: 2500000, // 25,000 ETB
                  isDark: isDark,
                  color: AppTheme.accentAmber,
                ),
              ],
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () => AddEditGoalSheet.show(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Custom Goal'),
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryNavy,
                foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
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

  Widget _buildGoalTemplateChip({
    required BuildContext context,
    required String label,
    required String category,
    required String iconKey,
    required int targetAmount,
    required bool isDark,
    required Color color,
  }) {
    return ActionChip(
      onPressed: () {
        AddEditGoalSheet.show(
          context,
          initialName: label.replaceFirst('+ ', ''),
          initialCategory: category,
          initialIconKey: iconKey,
          initialTargetAmount: targetAmount,
        );
      },
      avatar: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.primaryText : AppTheme.textDark,
        ),
      ),
      backgroundColor: isDark
          ? const Color(0xFF1E293B)
          : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
