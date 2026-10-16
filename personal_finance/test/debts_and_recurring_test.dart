import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/debts/models/debt.dart';
import 'package:personal_finance/features/recurring/models/recurring_schedule.dart';

void main() {
  group('FEATURE 3: Peer-to-Peer Debt & IOU Tracker Tests', () {
    test('Remaining amount and progress percentage calculate correctly', () {
      final now = DateTime.now();
      final debt = Debt(
        id: 'debt-1',
        personName: 'Dawit',
        type: DebtType.owesMe,
        totalAmount: 100000, // 1000.00 ETB
        settledAmount: 40000, // 400.00 ETB
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(debt.remainingAmount, 60000); // 600.00 ETB remaining
      expect(debt.progressPercentage, 0.4);
      expect(debt.isSettled, isFalse);
    });

    test('Full settlement flags debt as settled', () {
      final now = DateTime.now();
      final debt = Debt(
        id: 'debt-2',
        personName: 'Bethlehem',
        type: DebtType.iOwe,
        totalAmount: 50000,
        settledAmount: 50000,
        status: DebtStatus.settled,
        startDate: now,
        createdAt: now,
        updatedAt: now,
      );

      expect(debt.remainingAmount, 0);
      expect(debt.progressPercentage, 1.0);
      expect(debt.isSettled, isTrue);
    });
  });

  group('FEATURE 4: Recurring Expenses & Subscription Tests', () {
    test(
      'Monthly commitment computes normalized fixed costs across frequencies',
      () {
        final now = DateTime.now();
        final weeklyGym = RecurringSchedule(
          id: 'rec-1',
          name: 'Personal Trainer',
          amount: 25000, // 250.00 ETB / week
          accountId: 'acc-1',
          frequency: RecurringFrequency.weekly,
          startDate: now,
          nextOccurrence: now.add(const Duration(days: 7)),
          createdAt: now,
          updatedAt: now,
        );

        final monthlyNet = RecurringSchedule(
          id: 'rec-2',
          name: 'Fiber Internet',
          amount: 150000, // 1500.00 ETB / month
          accountId: 'acc-1',
          frequency: RecurringFrequency.monthly,
          startDate: now,
          nextOccurrence: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now,
        );

        final yearlyHosting = RecurringSchedule(
          id: 'rec-3',
          name: 'Domain & Hosting',
          amount: 120000, // 1200.00 ETB / year -> 100.00 ETB / month
          accountId: 'acc-1',
          frequency: RecurringFrequency.yearly,
          startDate: now,
          nextOccurrence: now.add(const Duration(days: 365)),
          createdAt: now,
          updatedAt: now,
        );

        expect(monthlyNet.monthlyCostCents, 150000);
        expect(yearlyHosting.monthlyCostCents, 10000);
        // Weekly: (25000 * 52 / 12) = 108333 cents
        expect(weeklyGym.monthlyCostCents, (25000 * 52 / 12).round());

        final total =
            weeklyGym.monthlyCostCents +
            monthlyNet.monthlyCostCents +
            yearlyHosting.monthlyCostCents;
        expect(total, 150000 + 10000 + (25000 * 52 / 12).round());
      },
    );
  });
}
