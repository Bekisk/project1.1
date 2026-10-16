import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/features/sms_parser/screens/sms_review_queue_screen.dart';
import 'package:personal_finance/features/sms_parser/services/bank_sms_tracker_controller.dart';
import 'package:personal_finance/features/sms_parser/widgets/sms_scanner_dialog.dart';
import 'package:personal_finance/core/database/database_helper.dart';

class BankSmsIntegrationScreen extends StatefulWidget {
  const BankSmsIntegrationScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BankSmsIntegrationScreen()));
  }

  @override
  State<BankSmsIntegrationScreen> createState() =>
      _BankSmsIntegrationScreenState();
}

enum IntegrationStatus {
  monitoringEnabled,
  readyToConnect,
  permissionRequired,
  permissionDenied,
  monitoringPaused,
}

class _BankSmsIntegrationScreenState extends State<BankSmsIntegrationScreen> {
  final _controller = BankSmsTrackerController.instance;

  bool _isLoading = true;
  bool _isTrackingEnabled = true;
  bool _isAutoRecordHighConfidence = false;
  bool _isNotifyEnabled = true;
  bool _hasPermission = false;
  int _pendingReviewCount = 0;
  int _totalImportedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final hasPerm = await _controller.checkSmsPermission();
    final tracking = await _controller.isTrackingEnabled();
    final autoRecord = await _controller.isAutoRecordHighConfidenceEnabled();
    final notify = await _controller.isNotifyEnabled();

    final db = await DatabaseHelper.instance.database;
    final pendingRows = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sms_import_logs WHERE status = 'pendingReview'",
    );
    final totalRows = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sms_import_logs",
    );

    _hasPermission = hasPerm;
    _isTrackingEnabled = tracking;
    _isAutoRecordHighConfidence = autoRecord;
    _isNotifyEnabled = notify;
    _pendingReviewCount = (pendingRows.first['count'] as int?) ?? 0;
    _totalImportedCount = (totalRows.first['count'] as int?) ?? 0;

    setState(() => _isLoading = false);
  }

  IntegrationStatus get _currentStatus {
    if (!_hasPermission) return IntegrationStatus.permissionRequired;
    if (!_isTrackingEnabled) return IntegrationStatus.monitoringPaused;
    if (_controller.isListening) return IntegrationStatus.monitoringEnabled;
    return IntegrationStatus.readyToConnect;
  }

  Future<void> _requestPermission() async {
    final granted = await _controller.requestSmsPermission();
    setState(() => _hasPermission = granted);
    if (granted) {
      await _controller.startMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('SMS permission granted. Monitoring enabled!'),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.expenseRed,
            content: Text(
              'SMS permission was denied. You can still use Manual Import.',
            ),
          ),
        );
      }
    }
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('Privacy & Security'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '100% On-Device Processing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Your SMS messages never leave your phone. The app operates completely offline — no messages or financial records are uploaded to external servers or AI APIs.',
              ),
              SizedBox(height: 12),
              Text(
                'Only Financial Alerts Are Processed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Personal chats, OTP verification codes, marketing texts, and unrelated messages are completely ignored and rejected.',
              ),
              SizedBox(height: 12),
              Text(
                'No Sensitive Storage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Raw messages are discarded or truncated to short previews for review only. Passwords, PINs, and full account numbers are never retained.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank SMS Integration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            onPressed: _showPrivacyDialog,
            tooltip: 'Privacy Policy',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Integration Status Banner
                  _buildStatusCard(isDark),
                  const SizedBox(height: 20),

                  // 2. Review Queue / Quick Access
                  if (_pendingReviewCount > 0) ...[
                    GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SmsReviewQueueScreen(),
                          ),
                        );
                        _loadState();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withOpacity(
                            isDark ? 0.2 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.accentAmber.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.pending_actions_rounded,
                              color: AppTheme.accentAmber,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$_pendingReviewCount Transactions Need Review',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tap to verify accounts, categories, and confirm records',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.accentAmber,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. Main Controls
                  const Text(
                    'AUTOMATIC TRACKING CONTROLS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FintechCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 14,
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Enable SMS Transaction Tracking',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Detect incoming bank alerts when received',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isTrackingEnabled,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) async {
                            await _controller.setTrackingEnabled(val);
                            setState(() => _isTrackingEnabled = val);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Auto-Record High Confidence',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Automatically record exact bank alerts; ask for confirmation otherwise',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isAutoRecordHighConfidence,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) async {
                            await _controller.setAutoRecordHighConfidence(val);
                            setState(() => _isAutoRecordHighConfidence = val);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Detection Notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Show a local alert when a transaction is detected',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isNotifyEnabled,
                          activeColor: AppTheme.primaryGreen,
                          onChanged: (val) async {
                            await _controller.setNotifyEnabled(val);
                            setState(() => _isNotifyEnabled = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Quick Action Tools
                  const Text(
                    'TOOLS & FALLBACKS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FintechCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 14,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.paste_rounded,
                            color: AppTheme.primaryGreen,
                          ),
                          title: const Text(
                            'Manual SMS Import / Paste',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Paste bank SMS text if auto-detection is not permitted',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => SmsScannerDialog.show(context),
                        ),
                        Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.history_rounded,
                            color: AppTheme.transferBlue,
                          ),
                          title: const Text(
                            'Review Queue & Import History',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$_totalImportedCount total messages parsed',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SmsReviewQueueScreen(),
                              ),
                            );
                            _loadState();
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.account_balance_rounded,
                            color: AppTheme.accentPurple,
                          ),
                          title: const Text(
                            'Supported Banks & Formats',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'CBE, Telebirr, Awash, Abyssinia, Dashen',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                          ),
                          onTap: () => _showSupportedBanksSheet(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Safe Notice Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_rounded,
                          size: 20,
                          color: AppTheme.transferBlue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Financial Integrity: Bank SMS detection only records financial activity locally inside this app. It never connects to, authenticates with, or initiates transfers from your real bank accounts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    Color statusColor;
    String statusTitle;
    String statusDesc;
    IconData statusIcon;

    switch (_currentStatus) {
      case IntegrationStatus.monitoringEnabled:
        statusColor = AppTheme.primaryGreen;
        statusTitle = 'Monitoring Enabled';
        statusDesc = 'Active — listening for incoming bank transaction alerts';
        statusIcon = Icons.check_circle_rounded;
        break;
      case IntegrationStatus.readyToConnect:
        statusColor = AppTheme.transferBlue;
        statusTitle = 'Ready to Connect';
        statusDesc = 'Permission granted. Turn on tracking to start.';
        statusIcon = Icons.radio_button_checked_rounded;
        break;
      case IntegrationStatus.permissionRequired:
        statusColor = AppTheme.accentAmber;
        statusTitle = 'Permission Required';
        statusDesc =
            'SMS read permission is needed to recognize incoming alerts.';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case IntegrationStatus.permissionDenied:
        statusColor = AppTheme.expenseRed;
        statusTitle = 'Permission Denied';
        statusDesc = 'SMS permission was denied. Use Manual Import fallback.';
        statusIcon = Icons.block_rounded;
        break;
      case IntegrationStatus.monitoringPaused:
        statusColor = Colors.grey;
        statusTitle = 'Monitoring Paused';
        statusDesc = 'Automatic tracking is toggled off in settings.';
        statusIcon = Icons.pause_circle_rounded;
        break;
    }

    return FintechCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_hasPermission) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _requestPermission,
                icon: const Icon(Icons.security_rounded, size: 18),
                label: const Text('Grant SMS Permission'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: AppTheme.deepNavy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSupportedBanksSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Supported Bank SMS Formats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBankRow(
              'Commercial Bank of Ethiopia (CBE)',
              'Debits, Credits, CBE Birr, ATM, Fee charges',
            ),
            _buildBankRow(
              'Telebirr',
              'Transfers, Merchant payments, Cash In/Out, Ref IDs',
            ),
            _buildBankRow(
              'Awash Bank',
              'Account debits, deposits, reason/merchant extraction',
            ),
            _buildBankRow(
              'Bank of Abyssinia',
              'Transactional transfer alerts & balance reports',
            ),
            _buildBankRow(
              'Dashen Bank (Amole)',
              'Payment confirmations & account notices',
            ),
            const SizedBox(height: 12),
            const Text(
              'Other formats will fall back safely to our generic parser or review queue.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankRow(String bank, String details) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  details,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
