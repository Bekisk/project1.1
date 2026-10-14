import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/notifications/services/notification_service.dart';

enum AppCurrency {
  etb('ETB', 'ብር', 'Ethiopian Birr'),
  usd('USD', '\$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound');

  final String code;
  final String symbol;
  final String label;

  const AppCurrency(this.code, this.symbol, this.label);
}

enum AppDateFormat {
  standard('MMM d, y', 'Oct 12, 2026'),
  slash('dd/MM/yyyy', '12/10/2026'),
  iso('yyyy-MM-dd', '2026-10-12'),
  full('MMMM d, y', 'October 12, 2026');

  final String pattern;
  final String sample;

  const AppDateFormat(this.pattern, this.sample);
}

class AppSettingsProvider extends ChangeNotifier {
  AppCurrency _currency = AppCurrency.etb;
  AppDateFormat _dateFormat = AppDateFormat.standard;
  String _defaultTransactionType = 'expense'; // 'expense', 'income', 'transfer'
  String _dashboardPeriod = 'this_month'; // 'this_month', 'last_month', 'this_year', 'all'
  bool _confirmDestructiveActions = true;
  bool _budgetAlertsEnabled = true;
  bool _savingsMilestoneAlertsEnabled = true;
  bool _isAmharicSuffix = false;

  // Daily Financial Summary Notification Settings
  bool _dailySummaryEnabled = false;
  int _dailySummaryHour = 20; // 8:00 PM default
  int _dailySummaryMinute = 0;
  bool _notificationPermissionGranted = true;

  AppCurrency get currency => _currency;
  AppDateFormat get dateFormat => _dateFormat;
  String get defaultTransactionType => _defaultTransactionType;
  String get dashboardPeriod => _dashboardPeriod;
  bool get confirmDestructiveActions => _confirmDestructiveActions;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  bool get savingsMilestoneAlertsEnabled => _savingsMilestoneAlertsEnabled;
  bool get isAmharicSuffix => _isAmharicSuffix;

  bool get dailySummaryEnabled => _dailySummaryEnabled;
  int get dailySummaryHour => _dailySummaryHour;
  int get dailySummaryMinute => _dailySummaryMinute;
  bool get notificationPermissionGranted => _notificationPermissionGranted;

  TimeOfDay get dailySummaryTime => TimeOfDay(hour: _dailySummaryHour, minute: _dailySummaryMinute);

  Future<void> loadSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final map = {for (final r in rows) r['key'] as String: r['value'] as String};

      if (map.containsKey('currency_code')) {
        _currency = AppCurrency.values.firstWhere(
          (c) => c.code == map['currency_code'],
          orElse: () => AppCurrency.etb,
        );
      }

      if (map.containsKey('date_format_pattern')) {
        _dateFormat = AppDateFormat.values.firstWhere(
          (d) => d.pattern == map['date_format_pattern'],
          orElse: () => AppDateFormat.standard,
        );
      }

      if (map.containsKey('default_transaction_type')) {
        _defaultTransactionType = map['default_transaction_type']!;
      }

      if (map.containsKey('dashboard_period')) {
        _dashboardPeriod = map['dashboard_period']!;
      }

      if (map.containsKey('confirm_destructive_actions')) {
        _confirmDestructiveActions = map['confirm_destructive_actions'] == '1';
      }

      if (map.containsKey('budget_alerts_enabled')) {
        _budgetAlertsEnabled = map['budget_alerts_enabled'] == '1';
      }

      if (map.containsKey('savings_milestone_alerts_enabled')) {
        _savingsMilestoneAlertsEnabled = map['savings_milestone_alerts_enabled'] == '1';
      }

      if (map.containsKey('is_amharic_suffix')) {
        _isAmharicSuffix = map['is_amharic_suffix'] == '1';
      }

      if (map.containsKey('daily_summary_enabled')) {
        _dailySummaryEnabled = map['daily_summary_enabled'] == '1';
      }

      if (map.containsKey('daily_summary_hour')) {
        _dailySummaryHour = int.tryParse(map['daily_summary_hour']!) ?? 20;
      }

      if (map.containsKey('daily_summary_minute')) {
        _dailySummaryMinute = int.tryParse(map['daily_summary_minute']!) ?? 0;
      }

      // Check notification permission state
      _notificationPermissionGranted = await NotificationService.instance.checkPermission();

      // If enabled and permission is granted, ensure schedule is active
      if (_dailySummaryEnabled && _notificationPermissionGranted) {
        try {
          await NotificationService.instance.scheduleDailySummary(
            hour: _dailySummaryHour,
            minute: _dailySummaryMinute,
          );
        } catch (e) {
          debugPrint('Error restoring daily summary schedule: $e');
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading app settings: $e');
    }
  }

  Future<void> setCurrency(AppCurrency currency) async {
    _currency = currency;
    notifyListeners();
    await _saveSetting('currency_code', currency.code);
  }

  Future<void> setDateFormat(AppDateFormat format) async {
    _dateFormat = format;
    notifyListeners();
    await _saveSetting('date_format_pattern', format.pattern);
  }

  Future<void> setDefaultTransactionType(String type) async {
    _defaultTransactionType = type;
    notifyListeners();
    await _saveSetting('default_transaction_type', type);
  }

  Future<void> setDashboardPeriod(String period) async {
    _dashboardPeriod = period;
    notifyListeners();
    await _saveSetting('dashboard_period', period);
  }

  Future<void> setConfirmDestructiveActions(bool enabled) async {
    _confirmDestructiveActions = enabled;
    notifyListeners();
    await _saveSetting('confirm_destructive_actions', enabled ? '1' : '0');
  }

  Future<void> setBudgetAlertsEnabled(bool enabled) async {
    _budgetAlertsEnabled = enabled;
    notifyListeners();
    await _saveSetting('budget_alerts_enabled', enabled ? '1' : '0');
  }

  Future<void> setSavingsMilestoneAlertsEnabled(bool enabled) async {
    _savingsMilestoneAlertsEnabled = enabled;
    notifyListeners();
    await _saveSetting('savings_milestone_alerts_enabled', enabled ? '1' : '0');
  }

  Future<void> setAmharicSuffix(bool enabled) async {
    _isAmharicSuffix = enabled;
    notifyListeners();
    await _saveSetting('is_amharic_suffix', enabled ? '1' : '0');
  }

  /// Toggles daily summary notification state and schedules/cancels notifications
  Future<bool> setDailySummaryEnabled(bool enabled) async {
    if (enabled) {
      // 1. Check or request Android notification permission
      bool granted = await NotificationService.instance.checkPermission();
      if (!granted) {
        granted = await NotificationService.instance.requestPermission();
      }
      _notificationPermissionGranted = granted;

      if (!granted) {
        // Permission was denied, cannot schedule
        _dailySummaryEnabled = false;
        notifyListeners();
        await _saveSetting('daily_summary_enabled', '0');
        return false;
      }

      _dailySummaryEnabled = true;
      notifyListeners();
      await _saveSetting('daily_summary_enabled', '1');

      // Schedule at the chosen time
      try {
        await NotificationService.instance.scheduleDailySummary(
          hour: _dailySummaryHour,
          minute: _dailySummaryMinute,
        );
      } catch (e) {
        debugPrint('Error scheduling daily summary: $e');
      }
      return true;
    } else {
      _dailySummaryEnabled = false;
      notifyListeners();
      await _saveSetting('daily_summary_enabled', '0');

      // Cancel the scheduled notification
      await NotificationService.instance.cancelDailySummary();
      return true;
    }
  }

  /// Updates the daily summary time (e.g. 8:00 PM -> 7:00 PM), cancels the previous schedule, and reschedules if enabled
  Future<void> setDailySummaryTime(TimeOfDay time) async {
    _dailySummaryHour = time.hour;
    _dailySummaryMinute = time.minute;
    notifyListeners();

    await _saveSetting('daily_summary_hour', time.hour.toString());
    await _saveSetting('daily_summary_minute', time.minute.toString());

    if (_dailySummaryEnabled && _notificationPermissionGranted) {
      try {
        await NotificationService.instance.scheduleDailySummary(
          hour: _dailySummaryHour,
          minute: _dailySummaryMinute,
        );
      } catch (e) {
        debugPrint('Error rescheduling daily summary at new time: $e');
      }
    }
  }

  /// Sends a test notification immediately for verification
  Future<void> testDailyNotification() async {
    await NotificationService.instance.sendImmediateTestNotification();
  }

  /// Refreshes permission status
  Future<void> checkNotificationPermission() async {
    _notificationPermissionGranted = await NotificationService.instance.checkPermission();
    notifyListeners();
  }

  Future<void> resetPreferencesToDefaults() async {
    _currency = AppCurrency.etb;
    _dateFormat = AppDateFormat.standard;
    _defaultTransactionType = 'expense';
    _dashboardPeriod = 'this_month';
    _confirmDestructiveActions = true;
    _budgetAlertsEnabled = true;
    _savingsMilestoneAlertsEnabled = true;
    _isAmharicSuffix = false;
    _dailySummaryEnabled = false;
    _dailySummaryHour = 20;
    _dailySummaryMinute = 0;
    notifyListeners();

    await NotificationService.instance.cancelDailySummary();

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'app_settings',
        where: "key != 'theme_mode'", // Keep theme or clear
      );
    } catch (e) {
      debugPrint('Error resetting preferences: $e');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }
}
