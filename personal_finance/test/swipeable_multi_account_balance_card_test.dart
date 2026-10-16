import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/dashboard/widgets/swipeable_multi_account_balance_card.dart';

void main() {
  group('Swipeable Multi-Account Balance Card Tests', () {
    final now = DateTime.now();

    final mainAccount = Account(
      id: 'acc_main_1',
      name: 'Commercial Bank of Ethiopia',
      accountType: 'bank',
      openingBalance: 2315700, // 23,157.00 ETB
      createdAt: now,
      updatedAt: now,
    );

    final savingsAccount = Account(
      id: 'acc_savings_2',
      name: 'Awash Bank Savings',
      accountType: 'savings',
      openingBalance: 8000000, // 80,000.00 ETB
      createdAt: now,
      updatedAt: now,
    );

    final walletAccount = Account(
      id: 'acc_wallet_3',
      name: 'Telebirr Wallet',
      accountType: 'mobile_money',
      openingBalance: 125000, // 1,250.00 ETB
      createdAt: now,
      updatedAt: now,
    );

    final balances = {
      'acc_main_1': 2315700,
      'acc_savings_2': 8000000,
      'acc_wallet_3': 125000,
    };

    testWidgets(
      'Scenario A: Defaults to main account, displays real bank name and isolated balance (never combined)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMultiAccountBalanceCard(
                accounts: [mainAccount, savingsAccount, walletAccount],
                accountBalances: balances,
                mainAccountId: 'acc_main_1',
                designatedSavingsAccountId: 'acc_savings_2',
                isDark: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify real bank name appears
        expect(find.text('Commercial Bank of Ethiopia'), findsWidgets);

        // 2. Verify "SLIMBank" is NOT present anywhere
        expect(find.text('SLIMBank'), findsNothing);

        // 3. Verify MAIN badge is displayed
        expect(find.text('MAIN'), findsWidgets);

        // 4. Verify main account balance format appears and combined balance (104,407) does NOT appear
        expect(find.textContaining('23,157'), findsWidgets);
        expect(find.textContaining('104,407'), findsNothing);
        expect(find.textContaining('103,157'), findsNothing);
      },
    );

    testWidgets(
      'Scenario B & C: Swiping horizontally transitions to savings account and returns on reverse swipe',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMultiAccountBalanceCard(
                accounts: [mainAccount, savingsAccount, walletAccount],
                accountBalances: balances,
                mainAccountId: 'acc_main_1',
                designatedSavingsAccountId: 'acc_savings_2',
                isDark: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially at main account
        expect(find.text('Commercial Bank of Ethiopia'), findsWidgets);

        // Fling right to left to switch to savings account
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();

        // Verify savings account data is displayed
        expect(find.text('Awash Bank Savings'), findsWidgets);
        expect(find.text('SAVINGS'), findsWidgets);
        expect(find.textContaining('80,000'), findsWidgets);

        // Fling left to right to switch back to main account
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();

        // Verify return to main account
        expect(find.text('Commercial Bank of Ethiopia'), findsWidgets);
        expect(find.text('MAIN'), findsWidgets);
        expect(find.textContaining('23,157'), findsWidgets);
      },
    );

    testWidgets(
      'Scenario D: Balance visibility toggle hides amount across cards and preserves privacy',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMultiAccountBalanceCard(
                accounts: [mainAccount, savingsAccount],
                accountBalances: balances,
                mainAccountId: 'acc_main_1',
                designatedSavingsAccountId: 'acc_savings_2',
                isDark: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially visible
        expect(find.textContaining('23,157'), findsWidgets);

        // Tap visibility toggle icon
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();

        // Balance is masked with dots
        expect(find.text('••••••••'), findsOneWidget);
        expect(find.textContaining('23,157'), findsNothing);

        // Fling to savings while masked
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();

        // Savings balance must remain masked
        expect(find.text('••••••••'), findsOneWidget);
        expect(find.textContaining('80,000'), findsNothing);

        // Fling back to main account while masked
        await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();

        expect(find.text('••••••••'), findsOneWidget);

        // Tap unmask icon to restore visibility
        await tester.tap(find.byIcon(Icons.visibility_off_outlined));
        await tester.pumpAndSettle();

        expect(find.textContaining('23,157'), findsWidgets);
      },
    );

    testWidgets(
      'Scenario G: Single account displays gracefully without breaking',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SwipeableMultiAccountBalanceCard(
                accounts: [mainAccount],
                accountBalances: balances,
                mainAccountId: 'acc_main_1',
                isDark: true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Commercial Bank of Ethiopia'), findsWidgets);
        expect(find.textContaining('23,157'), findsWidgets);
        expect(find.text('MAIN'), findsWidgets);
      },
    );
  });
}
