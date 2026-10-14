import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/notifications/models/daily_financial_summary.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';

/// Service responsible for managing local notifications, permissions, and scheduling.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const int dailySummaryNotificationId = 7001;
  static const int testNotificationId = 7002;
  static const int transactionAlertNotificationBaseId = 8000;
  static const String channelId = 'daily_financial_summary';
  static const String channelName = 'Daily Financial Summary';
  static const String channelDescription =
      'Daily evening notifications summarizing your recorded expenses, income, and cashflow.';

  static const String txAlertChannelId = 'bank_transaction_alerts';
  static const String txAlertChannelName = 'Bank Transaction Alerts';
  static const String txAlertChannelDescription =
      'Real-time alerts when bank SMS transactions are detected and recorded.';

  /// Global callback for notification taps
  static void Function(String? payload)? onNotificationTap;

  /// Initializes timezone data and Flutter Local Notifications plugin
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final localName = tz.local.name;
      debugPrint('NotificationService: local timezone initialized as $localName');
    } catch (e) {
      debugPrint('NotificationService: Error initializing timezones: $e');
    }

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped with payload: ${response.payload}');
        onNotificationTap?.call(response.payload);
      },
    );

    // Create high-priority notification channels for Android 8.0+
    const dailyChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const txAlertChannel = AndroidNotificationChannel(
      txAlertChannelId,
      txAlertChannelName,
      description: txAlertChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    final androidImplementation = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(dailyChannel);
      await androidImplementation.createNotificationChannel(txAlertChannel);
    }

    _initialized = true;
  }

  /// Sends a notification when a bank SMS transaction is recognized or needs review
  Future<void> showBankTransactionNotification({
    required String title,
    required String body,
    String? payload,
    int? notificationId,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      txAlertChannelId,
      txAlertChannelName,
      channelDescription: txAlertChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    final details = NotificationDetails(android: androidDetails);
    final id = notificationId ?? (transactionAlertNotificationBaseId + (DateTime.now().millisecondsSinceEpoch % 1000));

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Checks if POST_NOTIFICATIONS permission is granted on Android
  Future<bool> checkPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final areEnabled = await android.areNotificationsEnabled();
    return areEnabled ?? true;
  }

  /// Requests notification permission on Android 13+ (API 33+)
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Calculates the next TZDateTime for the given hour and minute in device local time
  tz.TZDateTime calculateNextScheduledTime(int hour, int minute, [tz.Location? location]) {
    final loc = location ?? tz.local;
    final now = tz.TZDateTime.now(loc);
    var scheduledDate = tz.TZDateTime(
      loc,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Fetches transactions directly from SQLite database and computes the daily summary
  Future<DailyFinancialSummary> getTodaySummary() async {
    final now = DateTime.now();
    final startOfDayIso = DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
    final endOfDayIso = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'transactions',
        where: 'transaction_date >= ? AND transaction_date <= ?',
        whereArgs: [startOfDayIso, endOfDayIso],
      );

      final transactions = rows.map((r) => FinancialTransaction.fromMap(r)).toList();
      return DailyFinancialSummary.fromTransactions(
        targetDate: now,
        allTransactions: transactions,
      );
    } catch (e) {
      debugPrint('NotificationService: Error loading transactions for summary: $e');
      return DailyFinancialSummary(
        date: now,
        totalExpenseCents: 0,
        totalIncomeCents: 0,
        netCashFlowCents: 0,
        expenseTransactionCount: 0,
        incomeTransactionCount: 0,
        eligibleTransactions: const [],
        hasActivity: false,
      );
    }
  }

  /// Schedules the recurring daily notification at the selected hour and minute
  Future<void> scheduleDailySummary({
    required int hour,
    required int minute,
  }) async {
    await initialize();

    // 1. Cancel any existing schedule with our stable notification ID to prevent duplicates
    await cancelDailySummary();

    // 2. Fetch current day's actual financial summary
    final summary = await getTodaySummary();
    final bodyText = summary.toNotificationBody();
    final expandedText = summary.toExpandedBigText();

    final scheduledTzTime = calculateNextScheduledTime(hour, minute);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      styleInformation: BigTextStyleInformation(
        expandedText,
        contentTitle: 'Your Daily Money Summary',
        summaryText: '${summary.expenseTransactionCount} transactions',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id: dailySummaryNotificationId,
        title: 'Your Daily Money Summary',
        body: bodyText,
        scheduledDate: scheduledTzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time, // Repeats daily at specified hour:minute
        payload: 'daily_summary_screen',
      );
      debugPrint('NotificationService: Daily summary scheduled successfully for $scheduledTzTime');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling daily summary: $e');
      rethrow;
    }
  }

  /// Sends an immediate test notification with real data for user verification
  Future<void> sendImmediateTestNotification() async {
    await initialize();

    final summary = await getTodaySummary();
    final bodyText = summary.toNotificationBody();
    final expandedText = summary.toExpandedBigText();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      styleInformation: BigTextStyleInformation(
        expandedText,
        contentTitle: 'Your Daily Money Summary (Test)',
        summaryText: '${summary.expenseTransactionCount} transactions today',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      id: testNotificationId,
      title: 'Your Daily Money Summary (Test)',
      body: bodyText,
      notificationDetails: details,
      payload: 'daily_summary_screen',
    );
  }

  /// Cancels the scheduled daily summary notification
  Future<void> cancelDailySummary() async {
    await initialize();
    await _plugin.cancel(id: dailySummaryNotificationId);
    debugPrint('NotificationService: Daily summary schedule cancelled.');
  }
}
