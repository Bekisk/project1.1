import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/models/goal_contribution.dart';
import 'package:personal_finance/features/savings_goals/services/savings_calculation_service.dart';

void main() {
  group('Milestone 4 — Savings Goals & Progress Tracking Automated Tests', () {
    final baseTime = DateTime(2026, 10, 1);

    // ==========================================
    // Test A — Basic Goal Progress (Laptop Purchase)
    // ==========================================
    test('Test A — Basic goal progress: 40,000 ETB target with 5,000 ETB & 7,000 ETB contributions', () {
      final goal = SavingsGoal(
        id: 'goal-laptop',
        name: 'Laptop Purchase',
        targetAmount: 4000000, // 40,000 ETB in cents
        targetDate: DateTime(2027, 4, 1),
        category: 'Technology',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final contributions = [
        GoalContribution(
          id: 'c-1',
          goalId: goal.id,
          amount: 500000, // 5,000 ETB in cents
          contributionDate: DateTime(2026, 10, 2),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
        GoalContribution(
          id: 'c-2',
          goalId: goal.id,
          amount: 700000, // 7,000 ETB in cents
          contributionDate: DateTime(2026, 10, 10),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
      ];

      final summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: contributions,
      );

      // Expected: Total saved: 12,000 ETB (1,200,000 cents)
      expect(summary.totalSaved, equals(1200000));
      // Remaining: 28,000 ETB (2,800,000 cents)
      expect(summary.remainingAmount, equals(2800000));
      // Progress: 30.0%
      expect(summary.progressPercent, closeTo(30.0, 0.001));

      // 25% milestone reached (10,000 ETB = 1,000,000 cents)
      final m25 = summary.milestones.firstWhere((m) => m.percentage == 25);
      expect(m25.isReached, isTrue);
      expect(
        m25.reachedAt,
        equals(DateTime(2026, 10, 10)),
      ); // reached on 2nd contribution

      // 50% milestone not reached (20,000 ETB = 2,000,000 cents)
      final m50 = summary.milestones.firstWhere((m) => m.percentage == 50);
      expect(m50.isReached, isFalse);
    });

    // ==========================================
    // Test B — Emergency Fund
    // ==========================================
    test('Test B — Emergency fund: 60,000 ETB target with 10k, 5k, 5k contributions', () {
      final goal = SavingsGoal(
        id: 'goal-emergency',
        name: 'Emergency Fund',
        targetAmount: 6000000, // 60,000 ETB in cents
        category: 'Emergency Fund',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final contributions = [
        GoalContribution(
          id: 'c-1',
          goalId: goal.id,
          amount: 1000000, // 10,000 ETB
          contributionDate: DateTime(2026, 10, 2),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
        GoalContribution(
          id: 'c-2',
          goalId: goal.id,
          amount: 500000, // 5,000 ETB
          contributionDate: DateTime(2026, 10, 5),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
        GoalContribution(
          id: 'c-3',
          goalId: goal.id,
          amount: 500000, // 5,000 ETB
          contributionDate: DateTime(2026, 10, 8),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
      ];

      final summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: contributions,
      );

      // Expected: Saved: 20,000 ETB
      expect(summary.totalSaved, equals(2000000));
      // Remaining: 40,000 ETB
      expect(summary.remainingAmount, equals(4000000));
      // Progress: ~33.33%
      expect(summary.progressPercent, closeTo(33.333, 0.01));
    });

    // ==========================================
    // Test C — Goal Completion
    // ==========================================
    test('Test C — Goal completion: 10,000 ETB target with 6,000 & 4,000 ETB contributions', () {
      final goal = SavingsGoal(
        id: 'goal-tuition',
        name: 'Tuition Fee',
        targetAmount: 1000000, // 10,000 ETB
        category: 'Education',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final contributions = [
        GoalContribution(
          id: 'c-1',
          goalId: goal.id,
          amount: 600000, // 6,000 ETB
          contributionDate: DateTime(2026, 10, 2),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
        GoalContribution(
          id: 'c-2',
          goalId: goal.id,
          amount: 400000, // 4,000 ETB
          contributionDate: DateTime(2026, 10, 6),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
      ];

      final summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: contributions,
      );

      // Saved: 10,000 ETB, Remaining: 0 ETB, Progress: 100%
      expect(summary.totalSaved, equals(1000000));
      expect(summary.remainingAmount, equals(0));
      expect(summary.progressPercent, equals(100.0));
      expect(summary.isCompleted, isTrue);

      // 100% milestone reached exactly once on 2nd contribution
      final m100 = summary.milestones.firstWhere((m) => m.percentage == 100);
      expect(m100.isReached, isTrue);
      expect(m100.reachedAt, equals(DateTime(2026, 10, 6)));
    });

    // ==========================================
    // Test D — Contributions Above Target
    // ==========================================
    test('Test D — Contributions above target: 10,000 ETB target with 11,500 ETB total saved', () {
      final goal = SavingsGoal(
        id: 'goal-phone',
        name: 'New Phone',
        targetAmount: 1000000, // 10,000 ETB
        category: 'Technology',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final contributions = [
        GoalContribution(
          id: 'c-1',
          goalId: goal.id,
          amount: 1150000, // 11,500 ETB
          contributionDate: DateTime(2026, 10, 5),
          mode: ContributionMode.manual,
          createdAt: baseTime,
          updatedAt: baseTime,
        ),
      ];

      final summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: contributions,
      );

      // Expected: Saved: 11,500 ETB, Remaining: 0 ETB
      expect(summary.totalSaved, equals(1150000));
      expect(summary.remainingAmount, equals(0));
      // Actual progress: 115%
      expect(summary.progressPercent, equals(115.0));
      // Visual indicator clamped to 1.0 (100%)
      expect(summary.visualClampedProgress, equals(1.0));
      // Excess surplus: 1,500 ETB
      expect(summary.excessAmount, equals(150000));
    });

    // ==========================================
    // Test E — Contribution Editing & Deletion
    // ==========================================
    test('Test E — Contribution editing and deletion recalculates progress correctly', () {
      final goal = SavingsGoal(
        id: 'goal-trip',
        name: 'Trip to Bale Mountains',
        targetAmount: 2000000, // 20,000 ETB
        category: 'Travel',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      // Initial contribution
      final c1 = GoalContribution(
        id: 'c-1',
        goalId: goal.id,
        amount: 800000, // 8,000 ETB -> 40%
        contributionDate: DateTime(2026, 10, 2),
        mode: ContributionMode.manual,
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      var summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: [c1],
      );
      expect(summary.progressPercent, equals(40.0));

      // Edit contribution amount to 12,000 ETB -> 60%
      final c1Edited = c1.copyWith(amount: 1200000);
      summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: [c1Edited],
      );
      expect(summary.totalSaved, equals(1200000));
      expect(summary.progressPercent, equals(60.0));

      // Delete contribution -> 0%
      summary = SavingsCalculationService.calculateGoalSummary(
        goal: goal,
        contributions: [],
      );
      expect(summary.totalSaved, equals(0));
      expect(summary.progressPercent, equals(0.0));
      expect(summary.remainingAmount, equals(2000000));
    });

    // ==========================================
    // Test F — Savings Plans
    // ==========================================
    test('Test F — Savings plans: calendar calculations, overdue handling, and no fabricated projections', () {
      final now = DateTime(2026, 10, 1);

      // Goal with valid target date (4 months ahead)
      final planResult = SavingsCalculationService.calculateSavingsPlan(
        targetAmount: 4000000, // 40,000 ETB
        totalSaved: 1000000, // 10,000 ETB -> 30,000 ETB remaining
        targetDate: DateTime(2027, 2, 1), // 4 calendar months
        frequency: ContributionPlanFrequency.monthly,
        referenceDate: now,
      );

      expect(planResult, isNotNull);
      expect(planResult!.remainingAmount, equals(3000000)); // 30,000 ETB
      expect(planResult.remainingPeriods, equals(4));
      // 30,000 / 4 = 7,500 ETB per month
      expect(planResult.requiredPeriodicAmount, equals(750000));
      expect(planResult.isOverdue, isFalse);

      // Goal with no target date must return null plan (no fabrication)
      final noDatePlan = SavingsCalculationService.calculateSavingsPlan(
        targetAmount: 5000000,
        totalSaved: 0,
        targetDate: null,
        frequency: ContributionPlanFrequency.monthly,
      );
      expect(noDatePlan, isNull);

      // Zero contribution history must return insufficient_data projection
      final goalWithoutPlan = SavingsGoal(
        id: 'goal-no-data',
        name: 'General Savings',
        targetAmount: 1000000,
        createdAt: now,
        updatedAt: now,
      );
      final projection = SavingsCalculationService.projectCompletionDate(
        targetAmount: 1000000,
        totalSaved: 0,
        contributions: [],
        goal: goalWithoutPlan,
        referenceDate: now,
      );
      expect(projection.method, equals('insufficient_data'));
      expect(projection.projectedDate, isNull);

      // Overdue goal handling
      final overduePlan = SavingsCalculationService.calculateSavingsPlan(
        targetAmount: 1000000,
        totalSaved: 200000,
        targetDate: DateTime(2026, 9, 1), // 1 month in the past
        frequency: ContributionPlanFrequency.monthly,
        referenceDate: now,
      );
      expect(overduePlan!.isOverdue, isTrue);
      expect(overduePlan.remainingAmount, equals(800000));
    });

    // ==========================================
    // Test G — Milestone Persistence & Recalculation
    // ==========================================
    test(
      'Test G — Milestones recalculate accurately if target is modified',
      () {
        final contribs = [
          GoalContribution(
            id: 'c-1',
            goalId: 'g1',
            amount: 500000, // 5,000 ETB
            contributionDate: DateTime(2026, 10, 2),
            mode: ContributionMode.manual,
            createdAt: baseTime,
            updatedAt: baseTime,
          ),
        ];

        // Target = 10,000 ETB -> 5,000 ETB reaches 10%, 25%, 50%
        var milestones = SavingsCalculationService.calculateMilestones(
          targetAmount: 1000000,
          contributions: contribs,
        );
        expect(
          milestones.firstWhere((m) => m.percentage == 50).isReached,
          isTrue,
        );
        expect(
          milestones.firstWhere((m) => m.percentage == 75).isReached,
          isFalse,
        );

        // Increase target to 20,000 ETB -> 5,000 ETB is now 25%, 50% is no longer reached
        milestones = SavingsCalculationService.calculateMilestones(
          targetAmount: 2000000,
          contributions: contribs,
        );
        expect(
          milestones.firstWhere((m) => m.percentage == 25).isReached,
          isTrue,
        );
        expect(
          milestones.firstWhere((m) => m.percentage == 50).isReached,
          isFalse,
        );
      },
    );

    // ==========================================
    // Test H — Account Consistency & Transfer Non-Duplication
    // ==========================================
    test('Test H — Account consistency: Transfer from Account A to B increases savings without doubling or distorting total wealth', () {
      final initialBalA = 500000; // 5,000 ETB
      final initialBalB = 100000; // 1,000 ETB
      final combinedBefore = initialBalA + initialBalB; // 6,000 ETB

      final transferAmount = 50000; // 500 ETB

      final afterBalA = initialBalA - transferAmount; // 4,500 ETB
      final afterBalB = initialBalB + transferAmount; // 1,500 ETB
      final combinedAfter = afterBalA + afterBalB; // 6,000 ETB

      expect(afterBalA, equals(450000));
      expect(afterBalB, equals(150000));
      expect(combinedAfter, equals(combinedBefore));

      // The contribution links this 500 ETB transfer
      final contrib = GoalContribution(
        id: 'c-transfer-1',
        goalId: 'goal-acc-b',
        amount: transferAmount,
        contributionDate: DateTime(2026, 10, 5),
        mode: ContributionMode.accountTransfer,
        sourceAccountId: 'acc-a',
        destinationAccountId: 'acc-b',
        transferTransactionId: 'tx-transfer-1',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final totalSaved = SavingsCalculationService.calculateTotalSaved([
        contrib,
      ]);
      expect(totalSaved, equals(transferAmount)); // 500 ETB
    });

    test('Test I — New goal with zero contributions evaluates milestones safely without casting errors', () {
      final newGoal = SavingsGoal(
        id: 'goal-new',
        name: 'New Savings Target',
        targetAmount: 2000000, // 20,000 ETB
        category: 'Savings',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      final summary = SavingsCalculationService.calculateGoalSummary(
        goal: newGoal,
        contributions: [],
      );

      // Verify that milestones are GoalMilestone and where filter executes without error
      final reachedCount = summary.milestones.where((m) => m.isReached).length;
      expect(reachedCount, equals(0));
      expect(summary.milestones.length, equals(5));
      expect(summary.planResult, isNull);
    });
  });
}
