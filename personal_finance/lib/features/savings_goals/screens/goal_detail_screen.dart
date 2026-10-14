import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/savings_goals/models/goal_contribution.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/providers/savings_goals_provider.dart';
import 'package:personal_finance/features/savings_goals/screens/add_contribution_sheet.dart';
import 'package:personal_finance/features/savings_goals/screens/add_edit_goal_sheet.dart';
import 'package:personal_finance/features/savings_goals/services/savings_calculation_service.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  static void navigate(BuildContext context, String goalId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: goalId)),
    );
  }

  void _confirmDelete(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Savings Goal?'),
        content: Text(
          'Are you sure you want to delete "${goal.name}"? '
          'Contribution records for this goal will be removed. '
          'Any historical account transfers remain intact and balances are safely preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<SavingsGoalsProvider>();
              final success = await provider.deleteGoal(goal.id);
              if (context.mounted) {
                if (success) {
                  context.read<DashboardProvider>().loadDashboardData();
                  context.read<TransactionsProvider>().loadTransactions();
                  Navigator.pop(context); // Pop detail screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Goal "${goal.name}" deleted.'),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteContribution(
    BuildContext context,
    GoalContribution contrib,
    String goalName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contribution?'),
        content: Text(
          'Remove contribution of ${CurrencyFormatter.formatCents(contrib.amount)}? '
          '${contrib.transferTransactionId != null ? 'The associated transfer transaction will also be reconciled.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<SavingsGoalsProvider>();
              await provider.deleteContribution(contrib);
              if (context.mounted) {
                context.read<DashboardProvider>().loadDashboardData();
                context.read<TransactionsProvider>().loadTransactions();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contribution deleted and balances reconciled.')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentCoral),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SavingsGoalsProvider>();

    final goalList = provider.allGoals.where((g) => g.id == goalId).toList();
    if (goalList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal Details')),
        body: const Center(child: Text('Savings goal not found')),
      );
    }

    final goal = goalList.first;
    final summary = provider.getSummaryForGoal(goal);
    final contributions = provider.getContributionsForGoal(goal.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Goal',
            onPressed: () => AddEditGoalSheet.show(context, goalToEdit: goal),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'pause') {
                await provider.setGoalStatus(goal.id, GoalStatus.paused);
              } else if (val == 'resume') {
                await provider.setGoalStatus(goal.id, GoalStatus.active);
              } else if (val == 'archive') {
                await provider.setGoalStatus(goal.id, GoalStatus.archived);
              } else if (val == 'complete') {
                await provider.setGoalStatus(goal.id, GoalStatus.completed);
              } else if (val == 'delete') {
                _confirmDelete(context, goal);
              }
            },
            itemBuilder: (ctx) => [
              if (goal.status == GoalStatus.active)
                const PopupMenuItem(value: 'pause', child: Text('Pause Goal'))
              else if (goal.status == GoalStatus.paused)
                const PopupMenuItem(value: 'resume', child: Text('Resume Goal')),
              if (goal.status != GoalStatus.completed)
                const PopupMenuItem(value: 'complete', child: Text('Mark Complete')),
              if (goal.status != GoalStatus.archived)
                const PopupMenuItem(value: 'archive', child: Text('Archive Goal')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Goal', style: TextStyle(color: AppTheme.accentCoral)),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
          border: Border(top: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => AddContributionSheet.show(context, goal: goal),
              icon: const Icon(Icons.add_circle_rounded),
              label: const Text('Add Contribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Progress Card
            _buildHeroProgressCard(context, goal, summary, isDark),
            const SizedBox(height: 18),

            // Plan & Projection Card
            _buildPlanAndProjectionCard(context, goal, summary, isDark),
            const SizedBox(height: 18),

            // Milestones Timeline
            _buildMilestonesCard(context, summary, isDark),
            const SizedBox(height: 18),

            // Contribution History
            _buildContributionHistoryCard(context, goal, contributions, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroProgressCard(
    BuildContext context,
    SavingsGoal goal,
    dynamic summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final percent = summary.progressPercent as double;
    final clamped = summary.visualClampedProgress as double;

    Color statusColor;
    switch (goal.status) {
      case GoalStatus.active:
        statusColor = AppTheme.primaryGreen;
        break;
      case GoalStatus.completed:
        statusColor = AppTheme.accentTeal;
        break;
      case GoalStatus.paused:
        statusColor = AppTheme.accentAmber;
        break;
      case GoalStatus.archived:
        statusColor = Colors.grey;
        break;
    }

    return FintechCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  goal.status.name.toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${goal.priority.name.toUpperCase()} PRIORITY',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Saved vs Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Saved', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatCents(summary.totalSaved),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Target', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatCents(goal.targetAmount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 12,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                summary.isCompleted ? AppTheme.accentTeal : AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Progress percentage and remaining
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percent.toStringAsFixed(1)}% achieved',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
              ),
              if (summary.excessAmount > 0)
                Text(
                  '+${CurrencyFormatter.formatCents(summary.excessAmount)} surplus',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.accentTeal),
                )
              else
                Text(
                  '${CurrencyFormatter.formatCents(summary.remainingAmount)} remaining',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.accentCoral),
                ),
            ],
          ),

          if (goal.description != null && goal.description!.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              goal.description!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanAndProjectionCard(
    BuildContext context,
    SavingsGoal goal,
    dynamic summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final plan = summary.planResult;
    final projection = summary.projection;

    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Plan & Timeline Projections',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Target date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target Date', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text(
                goal.targetDate != null
                    ? DateFormat('MMM dd, yyyy').format(goal.targetDate!)
                    : 'No target date set',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Recommended periodic contribution
          if (plan != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Required ${goal.planFrequency?.name ?? "Monthly"}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  CurrencyFormatter.formatCents(plan.requiredPeriodicAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              plan.statusDescription,
              style: TextStyle(
                fontSize: 11,
                color: plan.isOverdue ? AppTheme.accentCoral : Colors.grey,
                fontWeight: plan.isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Divider(height: 20),
          ],

          // Projected completion
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Projected Completion', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    projection.projectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(projection.projectedDate!)
                        : 'Not enough data',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    projection.description,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesCard(
    BuildContext context,
    GoalProgressSummary summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final milestones = summary.milestones;

    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: AppTheme.accentAmber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Milestones Tracking',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ...milestones.map((m) {
            final isReached = m.isReached;
            final pct = m.percentage;
            final req = m.requiredAmount;
            final reachedDate = m.reachedAt;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isReached
                          ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isReached ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isReached ? AppTheme.primaryGreen : Colors.grey,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pct% Milestone (${CurrencyFormatter.formatCents(req)})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isReached ? (isDark ? Colors.white : AppTheme.deepNavy) : Colors.grey,
                          ),
                        ),
                        if (isReached && reachedDate != null)
                          Text(
                            'Achieved on ${DateFormat("MMM dd, yyyy").format(reachedDate)}',
                            style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen),
                          )
                        else
                          const Text(
                            'In progress',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContributionHistoryCard(
    BuildContext context,
    SavingsGoal goal,
    List<GoalContribution> contributions,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return FintechCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppTheme.accentTeal, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Contribution History',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '${contributions.length} recorded',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (contributions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.savings_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No contributions yet', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap "Add Contribution" below to start saving toward this goal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: contributions.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, i) {
                final contrib = contributions[i];
                final isTransfer = contrib.mode == ContributionMode.accountTransfer;

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isTransfer
                            ? AppTheme.accentBlue.withValues(alpha: 0.15)
                            : AppTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isTransfer ? Icons.swap_horiz_rounded : Icons.arrow_downward_rounded,
                        color: isTransfer ? AppTheme.accentBlue : AppTheme.primaryGreen,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                CurrencyFormatter.formatCents(contrib.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isTransfer ? 'Transfer' : 'Earmark',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTheme.primaryText : AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM dd, yyyy').format(contrib.contributionDate) +
                                (contrib.notes != null ? ' • ${contrib.notes}' : ''),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => AddContributionSheet.show(
                        context,
                        goal: goal,
                        contributionToEdit: contrib,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentCoral),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDeleteContribution(context, contrib, goal.name),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
