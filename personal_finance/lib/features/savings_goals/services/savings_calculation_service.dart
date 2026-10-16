import 'dart:math' as math;

import '../models/savings_goal.dart';
import '../models/goal_contribution.dart';

class GoalMilestone {
  final int percentage; // 10, 25, 50, 75, 100
  final int requiredAmount; // in cents
  final bool isReached;
  final DateTime? reachedAt;

  GoalMilestone({
    required this.percentage,
    required this.requiredAmount,
    required this.isReached,
    this.reachedAt,
  });
}

class SavingsPlanResult {
  final int remainingAmount; // in cents
  final int remainingPeriods;
  final int requiredPeriodicAmount; // in cents
  final bool isOverdue;
  final String statusDescription;

  SavingsPlanResult({
    required this.remainingAmount,
    required this.remainingPeriods,
    required this.requiredPeriodicAmount,
    required this.isOverdue,
    required this.statusDescription,
  });
}

class ProjectedCompletionResult {
  final DateTime? projectedDate;
  final String method; // 'plan', 'historical_rate', 'insufficient_data'
  final String description;

  ProjectedCompletionResult({
    this.projectedDate,
    required this.method,
    required this.description,
  });
}

class GoalProgressSummary {
  final SavingsGoal goal;
  final int totalSaved; // in cents
  final int targetAmount; // in cents
  final int remainingAmount; // in cents: max(target - totalSaved, 0)
  final int excessAmount; // in cents: max(totalSaved - target, 0)
  final double progressPercent; // actual percentage, can exceed 100.0
  final double visualClampedProgress; // 0.0 to 1.0 for progress bar
  final bool isCompleted;
  final List<GoalMilestone> milestones;
  final SavingsPlanResult? planResult;
  final ProjectedCompletionResult projection;

  GoalProgressSummary({
    required this.goal,
    required this.totalSaved,
    required this.targetAmount,
    required this.remainingAmount,
    required this.excessAmount,
    required this.progressPercent,
    required this.visualClampedProgress,
    required this.isCompleted,
    required this.milestones,
    this.planResult,
    required this.projection,
  });
}

class OverallSavingsSummary {
  final int totalActiveTarget; // in cents
  final int totalActiveSaved; // in cents
  final int totalActiveRemaining; // in cents
  final double overallProgressPercent;
  final int activeGoalsCount;
  final int completedGoalsCount;
  final int pausedGoalsCount;
  final int archivedGoalsCount;

  OverallSavingsSummary({
    required this.totalActiveTarget,
    required this.totalActiveSaved,
    required this.totalActiveRemaining,
    required this.overallProgressPercent,
    required this.activeGoalsCount,
    required this.completedGoalsCount,
    required this.pausedGoalsCount,
    required this.archivedGoalsCount,
  });
}

class SavingsCalculationService {
  /// Standard milestone percentages
  static const List<int> standardMilestones = [10, 25, 50, 75, 100];

  /// Calculates the total saved amount from contributions in cents
  static int calculateTotalSaved(List<GoalContribution> contributions) {
    int sum = 0;
    for (final c in contributions) {
      sum += c.amount;
    }
    return sum;
  }

  /// Calculates the progress percentage: (saved / target) * 100
  /// Handled accurately without division by zero and rounded to 4 decimal places.
  static double calculateProgressPercentage(int totalSaved, int targetAmount) {
    if (targetAmount <= 0) return 0.0;
    final raw = (totalSaved / targetAmount) * 100.0;
    return double.parse(raw.toStringAsFixed(4));
  }

  /// Calculates remaining amount: max(target - saved, 0)
  static int calculateRemainingAmount(int totalSaved, int targetAmount) {
    return math.max(targetAmount - totalSaved, 0);
  }

  /// Calculates excess amount: max(saved - target, 0)
  static int calculateExcessAmount(int totalSaved, int targetAmount) {
    return math.max(totalSaved - targetAmount, 0);
  }

  /// Evaluates milestones (10%, 25%, 50%, 75%, 100%) against target and contribution history.
  /// Identifies the earliest contribution date when the threshold was achieved.
  static List<GoalMilestone> calculateMilestones({
    required int targetAmount,
    required List<GoalContribution> contributions,
  }) {
    if (targetAmount <= 0) return [];

    // Sort contributions chronologically to find exact milestone achievement dates
    final sortedContribs = List<GoalContribution>.from(contributions)
      ..sort((a, b) => a.contributionDate.compareTo(b.contributionDate));

    return standardMilestones.map((pct) {
      final requiredAmount = (targetAmount * (pct / 100.0)).round();

      int runningTotal = 0;
      DateTime? reachedAt;
      bool isReached = false;

      for (final c in sortedContribs) {
        runningTotal += c.amount;
        if (runningTotal >= requiredAmount && !isReached) {
          isReached = true;
          reachedAt = c.contributionDate;
          break;
        }
      }

      return GoalMilestone(
        percentage: pct,
        requiredAmount: requiredAmount,
        isReached: isReached,
        reachedAt: reachedAt,
      );
    }).toList();
  }

  /// Calculates recommended periodic contribution to reach target by targetDate
  static SavingsPlanResult? calculateSavingsPlan({
    required int targetAmount,
    required int totalSaved,
    required DateTime? targetDate,
    required ContributionPlanFrequency? frequency,
    DateTime? referenceDate,
  }) {
    if (targetDate == null || frequency == null) return null;

    final now = referenceDate ?? DateTime.now();
    final remainingAmount = calculateRemainingAmount(totalSaved, targetAmount);

    if (now.isAfter(targetDate)) {
      return SavingsPlanResult(
        remainingAmount: remainingAmount,
        remainingPeriods: 0,
        requiredPeriodicAmount: remainingAmount,
        isOverdue: remainingAmount > 0,
        statusDescription: remainingAmount > 0
            ? 'Goal target date has passed'
            : 'Goal completed',
      );
    }

    int periods = 0;
    if (frequency == ContributionPlanFrequency.weekly) {
      final daysDiff = targetDate.difference(now).inDays;
      periods = math.max((daysDiff / 7).ceil(), 1);
    } else if (frequency == ContributionPlanFrequency.monthly) {
      // Calendar month difference
      final yearDiff = targetDate.year - now.year;
      final monthDiff = (yearDiff * 12) + (targetDate.month - now.month);
      // If the target day is ahead or same in the month, count monthDiff, otherwise adjust
      periods = math.max(monthDiff, 1);
      if (targetDate.day > now.day && monthDiff == 0) {
        periods = 1;
      }
    } else {
      final daysDiff = targetDate.difference(now).inDays;
      periods = math.max(daysDiff, 1);
    }

    final requiredPeriodic = (remainingAmount / periods).ceil();

    return SavingsPlanResult(
      remainingAmount: remainingAmount,
      remainingPeriods: periods,
      requiredPeriodicAmount: requiredPeriodic,
      isOverdue: false,
      statusDescription: '$periods ${frequency.name} periods remaining',
    );
  }

  /// Projects estimated completion date based on plan or historical contribution rate
  static ProjectedCompletionResult projectCompletionDate({
    required int targetAmount,
    required int totalSaved,
    required List<GoalContribution> contributions,
    required SavingsGoal goal,
    DateTime? referenceDate,
  }) {
    final remaining = calculateRemainingAmount(totalSaved, targetAmount);
    if (remaining <= 0) {
      return ProjectedCompletionResult(
        projectedDate: goal.completedAt ?? DateTime.now(),
        method: 'completed',
        description: 'Goal already achieved',
      );
    }

    final now = referenceDate ?? DateTime.now();

    // 1. If configured planned amount is valid and positive
    if (goal.plannedPeriodicAmount != null &&
        goal.plannedPeriodicAmount! > 0 &&
        goal.planFrequency != null) {
      final periodic = goal.plannedPeriodicAmount!;
      final periodsNeeded = (remaining / periodic).ceil();
      DateTime projected;
      if (goal.planFrequency == ContributionPlanFrequency.weekly) {
        projected = now.add(Duration(days: periodsNeeded * 7));
      } else {
        // Monthly
        final targetMonth = now.month + periodsNeeded;
        final targetYear = now.year + ((targetMonth - 1) ~/ 12);
        final normalizedMonth = ((targetMonth - 1) % 12) + 1;
        projected = DateTime(
          targetYear,
          normalizedMonth,
          math.min(now.day, 28),
        );
      }
      return ProjectedCompletionResult(
        projectedDate: projected,
        method: 'plan',
        description: 'Estimated based on your ${goal.planFrequency!.name} plan',
      );
    }

    // 2. Historical contribution rate (lookback over actual contributions)
    if (contributions.length >= 2) {
      final sorted = List<GoalContribution>.from(contributions)
        ..sort((a, b) => a.contributionDate.compareTo(b.contributionDate));
      final firstDate = sorted.first.contributionDate;
      final daysSpan = math.max(now.difference(firstDate).inDays, 1);

      if (daysSpan >= 7 && totalSaved > 0) {
        final dailyRate = totalSaved / daysSpan; // cents per day
        if (dailyRate > 0) {
          final daysNeeded = (remaining / dailyRate).ceil();
          // Cap projection to reasonable limit (e.g. 50 years max)
          if (daysNeeded < 365 * 50) {
            final projected = now.add(Duration(days: daysNeeded));
            return ProjectedCompletionResult(
              projectedDate: projected,
              method: 'historical_rate',
              description: 'Projected from your past saving pace',
            );
          }
        }
      }
    }

    return ProjectedCompletionResult(
      projectedDate: null,
      method: 'insufficient_data',
      description: 'Add regular contributions or a savings plan for estimates',
    );
  }

  /// Computes full summary for a specific goal
  static GoalProgressSummary calculateGoalSummary({
    required SavingsGoal goal,
    required List<GoalContribution> contributions,
    DateTime? referenceDate,
  }) {
    final totalSaved = calculateTotalSaved(contributions);
    final targetAmount = goal.targetAmount;
    final remainingAmount = calculateRemainingAmount(totalSaved, targetAmount);
    final excessAmount = calculateExcessAmount(totalSaved, targetAmount);
    final progressPercent = calculateProgressPercentage(
      totalSaved,
      targetAmount,
    );
    final visualClamped = (progressPercent / 100.0).clamp(0.0, 1.0);
    final isCompleted = totalSaved >= targetAmount && targetAmount > 0;

    final milestones = calculateMilestones(
      targetAmount: targetAmount,
      contributions: contributions,
    );

    final planResult = calculateSavingsPlan(
      targetAmount: targetAmount,
      totalSaved: totalSaved,
      targetDate: goal.targetDate,
      frequency: goal.planFrequency,
      referenceDate: referenceDate,
    );

    final projection = projectCompletionDate(
      targetAmount: targetAmount,
      totalSaved: totalSaved,
      contributions: contributions,
      goal: goal,
      referenceDate: referenceDate,
    );

    return GoalProgressSummary(
      goal: goal,
      totalSaved: totalSaved,
      targetAmount: targetAmount,
      remainingAmount: remainingAmount,
      excessAmount: excessAmount,
      progressPercent: progressPercent,
      visualClampedProgress: visualClamped,
      isCompleted: isCompleted,
      milestones: milestones,
      planResult: planResult,
      projection: projection,
    );
  }

  /// Computes overall aggregate summary across all goals
  static OverallSavingsSummary calculateOverallSummary(
    List<SavingsGoal> allGoals,
    Map<String, List<GoalContribution>> contributionsByGoal,
  ) {
    int totalActiveTarget = 0;
    int totalActiveSaved = 0;
    int totalActiveRemaining = 0;
    int activeCount = 0;
    int completedCount = 0;
    int pausedCount = 0;
    int archivedCount = 0;

    for (final goal in allGoals) {
      final contribs = contributionsByGoal[goal.id] ?? [];
      final saved = calculateTotalSaved(contribs);

      switch (goal.status) {
        case GoalStatus.active:
          activeCount++;
          totalActiveTarget += goal.targetAmount;
          totalActiveSaved += saved;
          totalActiveRemaining += calculateRemainingAmount(
            saved,
            goal.targetAmount,
          );
          break;
        case GoalStatus.completed:
          completedCount++;
          break;
        case GoalStatus.paused:
          pausedCount++;
          break;
        case GoalStatus.archived:
          archivedCount++;
          break;
      }
    }

    final double overallProgress = totalActiveTarget > 0
        ? (totalActiveSaved / totalActiveTarget) * 100.0
        : 0.0;

    return OverallSavingsSummary(
      totalActiveTarget: totalActiveTarget,
      totalActiveSaved: totalActiveSaved,
      totalActiveRemaining: totalActiveRemaining,
      overallProgressPercent: overallProgress,
      activeGoalsCount: activeCount,
      completedGoalsCount: completedCount,
      pausedGoalsCount: pausedCount,
      archivedGoalsCount: archivedCount,
    );
  }
}
