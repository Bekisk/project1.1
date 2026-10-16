import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/notifications/services/notification_service.dart';
import 'package:personal_finance/features/sms_parser/models/sms_import_log.dart';
import 'package:personal_finance/features/sms_parser/services/sms_parser_service.dart';

class BankSmsTrackerController {
  static final BankSmsTrackerController instance = BankSmsTrackerController._();
  BankSmsTrackerController._();

  static const MethodChannel _channel = MethodChannel(
    'com.beki.personal_finance/sms_tracker',
  );

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Global callback for when an SMS is processed to refresh UI screens
  VoidCallback? onTransactionProcessed;

  /// Initializes platform channel handler and starts monitoring if enabled
  Future<void> initialize() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSmsReceived') {
        try {
          final Map<dynamic, dynamic>? data =
              call.arguments as Map<dynamic, dynamic>?;
          if (data != null) {
            final sender = data['sender'] as String? ?? 'Unknown';
            final body = data['body'] as String? ?? '';
            await handleIncomingSms(body, sender: sender);
          }
        } catch (e) {
          debugPrint('Error handling incoming native SMS: $e');
        }
      }
    });

    final enabled = await isTrackingEnabled();
    if (enabled) {
      final hasPermission = await checkSmsPermission();
      if (hasPermission) {
        await startMonitoring();
      }
    }
  }

  /// Processes an incoming SMS string, parses it, records it or puts in review,
  /// and shows a notification if appropriate.
  Future<SyncResult> handleIncomingSms(String text, {String? sender}) async {
    debugPrint(
      'SMS Tracker: Received SMS from ${sender ?? "unknown"}. Length: ${text.length}',
    );
    final result = await SmsParserService.instance.processAndReconcileSms(
      text,
      senderShortCode: sender,
    );
    debugPrint(
      'SMS Tracker: Reconciliation status=${result.status.name}, type=${result.log.transactionType}',
    );

    final shouldNotify = await isNotifyEnabled();
    if (shouldNotify) {
      if (result.status == SmsImportStatus.autoRecorded &&
          result.transaction != null) {
        final tx = result.transaction!;
        final amountFormatted = 'ETB ${(tx.amount / 100.0).toStringAsFixed(2)}';
        final isIncome = tx.type.name == 'income';
        final bankName = result.log.sender.isNotEmpty
            ? result.log.sender
            : 'Bank';
        final title = isIncome
            ? '$bankName: $amountFormatted received'
            : '$bankName: $amountFormatted debited';
        final body = isIncome
            ? '$amountFormatted credited to your account. ${tx.description}'
            : '$amountFormatted deducted. ${tx.description}';

        try {
          await NotificationService.instance.showBankTransactionNotification(
            title: title,
            body: body,
            payload: 'transaction_${tx.id}',
          );
          debugPrint('SMS Tracker: Transaction notification issued.');
        } catch (e) {
          debugPrint(
            'SMS Tracker: Notification failed (possibly permission denied): $e',
          );
        }
      } else if (result.status == SmsImportStatus.pendingReview) {
        final amountFormatted =
            'ETB ${(result.log.amountCents / 100.0).toStringAsFixed(2)}';
        final bankName = result.log.sender.isNotEmpty
            ? result.log.sender
            : 'Bank';
        try {
          await NotificationService.instance.showBankTransactionNotification(
            title: '$bankName alert needs review',
            body:
                '$amountFormatted alert detected from $bankName. Tap to confirm.',
            payload: 'review_queue',
          );
          debugPrint('SMS Tracker: Review notification issued.');
        } catch (e) {
          debugPrint('SMS Tracker: Review notification failed: $e');
        }
      } else {
        debugPrint(
          'SMS Tracker: Notification suppressed for status: ${result.status.name}',
        );
      }
    } else {
      debugPrint('SMS Tracker: Notifications disabled in settings.');
    }

    onTransactionProcessed?.call();
    return result;
  }

  /// Checks RECEIVE_SMS permission status from Android
  Future<bool> checkSmsPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'checkSmsPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests RECEIVE_SMS permission
  Future<bool> requestSmsPermission() async {
    try {
      final bool? granted = await _channel.invokeMethod<bool>(
        'requestSmsPermission',
      );
      if (granted == true) {
        await startMonitoring();
      }
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Registers native SMS broadcast receiver
  Future<bool> startMonitoring() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'registerSmsReceiver',
      );
      _isListening = success ?? false;
      return _isListening;
    } catch (_) {
      _isListening = false;
      return false;
    }
  }

  /// Unregisters native SMS broadcast receiver
  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('unregisterSmsReceiver');
      _isListening = false;
    } catch (_) {}
  }

  // --- Settings Persistence ---

  Future<bool> isTrackingEnabled() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sms_tracker_settings',
      where: "key = 'tracking_enabled'",
      limit: 1,
    );
    return rows.isEmpty || rows.first['value'] == '1';
  }

  Future<void> setTrackingEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sms_tracker_settings', {
      'key': 'tracking_enabled',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (enabled) {
      final hasPerm = await checkSmsPermission();
      if (hasPerm) await startMonitoring();
    } else {
      await stopMonitoring();
    }
  }

  Future<bool> isAutoRecordHighConfidenceEnabled() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sms_tracker_settings',
      where: "key = 'auto_record_high_confidence'",
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> setAutoRecordHighConfidence(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sms_tracker_settings', {
      'key': 'auto_record_high_confidence',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isNotifyEnabled() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sms_tracker_settings',
      where: "key = 'notify_on_detection'",
      limit: 1,
    );
    return rows.isEmpty || rows.first['value'] == '1';
  }

  Future<void> setNotifyEnabled(bool enabled) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sms_tracker_settings', {
      'key': 'notify_on_detection',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
