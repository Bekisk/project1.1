import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'core/formatting/currency_formatter.dart';
import 'core/widgets/floating_glass_nav_bar.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/settings/screens/more_menu_screen.dart';
import 'features/transactions/screens/add_transaction_sheet.dart';
import 'features/transactions/providers/transactions_provider.dart';
import 'features/transactions/screens/transactions_screen.dart';
import 'features/budgets/providers/budgets_provider.dart';
import 'features/budgets/screens/budgets_screen.dart';
import 'features/savings_goals/providers/savings_goals_provider.dart';
import 'features/savings_goals/screens/savings_goals_screen.dart';
import 'features/settings/providers/app_settings_provider.dart';

import 'features/notifications/screens/daily_summary_screen.dart';
import 'features/notifications/services/notification_service.dart';
import 'features/profile/providers/user_profile_provider.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/security/providers/app_lock_provider.dart';
import 'features/security/screens/lock_screen.dart';
import 'features/security/screens/setup_pin_screen.dart';

import 'package:personal_finance/features/debts/providers/debts_provider.dart';
import 'package:personal_finance/features/recurring/providers/recurring_provider.dart';
import 'package:personal_finance/features/sms_parser/screens/sms_review_queue_screen.dart';
import 'package:personal_finance/features/sms_parser/services/bank_sms_tracker_controller.dart';
import 'package:personal_finance/features/transactions/screens/transaction_review_assistant_screen.dart';
import 'package:personal_finance/features/transactions/services/transaction_review_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Android Edge-to-Edge System UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  try {
    await NotificationService.instance.initialize();
    NotificationService.onNotificationTap = (payload) {
      final context = appNavigatorKey.currentContext;

      // If the lock provider is available and the app is locked,
      // store the payload for delivery after unlock.
      if (context != null) {
        final lockProvider = Provider.of<AppLockProvider>(
          context,
          listen: false,
        );
        if (!lockProvider.isUnlocked) {
          lockProvider.setPendingNotificationPayload(payload);
          return;
        }
      }

      if (payload == 'daily_summary_screen') {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const DailySummaryScreen()),
        );
      } else if (payload == 'review_queue') {
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const SmsReviewQueueScreen()),
        );
      }
    };

    // Initialize native SMS monitoring if enabled
    await BankSmsTrackerController.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing services in main: $e');
  }

  runApp(const MyFinanceApp());
}

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider()..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => UserProfileProvider()..loadProfile(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider()..loadDashboardData(),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionsProvider()..loadTransactions(),
        ),
        ChangeNotifierProvider(
          create: (_) => BudgetsProvider()..loadBudgetData(),
        ),
        ChangeNotifierProvider(
          create: (_) => SavingsGoalsProvider()..loadGoalsData(),
        ),
        ChangeNotifierProvider(create: (_) => DebtsProvider()..loadDebts()),
        ChangeNotifierProvider(
          create: (_) => RecurringProvider()
            ..loadSchedules()
            ..processDueRecurringTransactions(),
        ),
        ChangeNotifierProvider(create: (_) => AppLockProvider()..init()),
      ],
      child: Consumer2<ThemeProvider, AppSettingsProvider>(
        builder: (context, themeProvider, settingsProvider, child) {
          CurrencyFormatter.setCurrencySymbol(settingsProvider.currency.symbol);
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'My Finance',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppRootRouter(),
          );
        },
      ),
    );
  }
}

class AppRootRouter extends StatefulWidget {
  const AppRootRouter({super.key});

  @override
  State<AppRootRouter> createState() => _AppRootRouterState();
}

class _AppRootRouterState extends State<AppRootRouter> {
  bool _reviewFlowDismissedThisSession = false;
  int _pendingReviewCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPendingReviews();
  }

  Future<void> _checkPendingReviews() async {
    try {
      final count = await TransactionReviewService.instance
          .getPendingReviewCount();
      if (mounted) {
        setState(() {
          _pendingReviewCount = count;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<UserProfileProvider>();
    final lockProvider = context.watch<AppLockProvider>();

    // While the lock provider initializes, show a splash
    if (!lockProvider.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If no PIN is configured yet, redirect to setup
    if (!lockProvider.isLockConfigured) {
      return const SetupPinScreen();
    }

    // If the app is locked (background timeout or just launched),
    // show the lock screen
    if (!lockProvider.isUnlocked) {
      // Reset review dismissal so after unlock it can prompt if new transactions exist
      _reviewFlowDismissedThisSession = false;
      return const LockScreen();
    }

    if (profileProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If genuinely new user (onboarding not completed AND no profile AND no existing financial records)
    // or onboarding explicitly not completed:
    final isNewUserWithoutOnboarding =
        !profileProvider.isOnboardingCompleted &&
        (!profileProvider.hasExistingFinancialData ||
            !profileProvider.hasProfile);

    if (isNewUserWithoutOnboarding) {
      return OnboardingScreen(
        onOnboardingComplete: () {
          // Onboarding completed, provider is already updated; this triggers re-render
        },
      );
    }

    // Check review assistant queue after unlock:
    if (!_reviewFlowDismissedThisSession && _pendingReviewCount > 0) {
      return TransactionReviewAssistantScreen(
        onComplete: () {
          setState(() {
            _reviewFlowDismissedThisSession = true;
            _pendingReviewCount = 0;
          });
          // Refresh transactions and dashboard
          context.read<TransactionsProvider>().loadTransactions();
          context.read<DashboardProvider>().loadDashboardData();
        },
      );
    }

    return const MainNavigationShell();
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openAddTransactionSheet(BuildContext context) {
    AddTransactionSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNavigateToTransactions: () => _onTabSelected(1),
        onNavigateToGoals: () => _onTabSelected(3),
        onNavigateToBudgets: () => _onTabSelected(2),
        onAddTransaction: () => _openAddTransactionSheet(context),
        onNavigateToSettings: () => _onTabSelected(4),
      ),
      const TransactionsScreen(),
      const BudgetsScreen(),
      const SavingsGoalsScreen(),
      const MoreMenuScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: FloatingGlassNavBar(
        currentIndex: _currentIndex,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}
