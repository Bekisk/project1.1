import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/core/widgets/fintech_card.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/sms_parser/models/sms_import_log.dart';
import 'package:personal_finance/features/sms_parser/services/sms_parser_service.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';

class SmsReviewQueueScreen extends StatefulWidget {
  const SmsReviewQueueScreen({super.key});

  static void navigate(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SmsReviewQueueScreen()));
  }

  @override
  State<SmsReviewQueueScreen> createState() => _SmsReviewQueueScreenState();
}

class _SmsReviewQueueScreenState extends State<SmsReviewQueueScreen> {
  bool _isLoading = true;
  List<SmsImportLog> _pendingLogs = [];
  List<Account> _accounts = [];
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    final logRows = await db.query(
      'sms_import_logs',
      where: "status = 'pendingReview'",
      orderBy: 'created_at DESC',
    );
    _pendingLogs = logRows.map((r) => SmsImportLog.fromMap(r)).toList();

    final accRows = await db.query('accounts', where: 'is_archived = 0');
    _accounts = accRows.map((r) => Account.fromMap(r)).toList();

    final catRows = await db.query('categories', where: 'is_archived = 0');
    _categories = catRows.map((r) => Category.fromMap(r)).toList();

    setState(() => _isLoading = false);
  }

  Future<void> _confirmItem(SmsImportLog log) async {
    String selectedAccountId =
        log.matchedAccountId ??
        (_accounts.isNotEmpty ? _accounts.first.id : '');
    String? selectedCategoryId;
    final isIncome =
        log.transactionType.contains('incoming') ||
        log.transactionType.contains('deposit') ||
        log.transactionType.contains('interest');

    final relevantCategories = _categories
        .where((c) => c.transactionType == (isIncome ? 'income' : 'expense'))
        .toList();

    final TextEditingController descController = TextEditingController(
      text: log.rawPreview.isNotEmpty
          ? log.rawPreview
          : '${log.sender} Transaction',
    );
    final TextEditingController merchantController = TextEditingController();

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardCharcoal : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark ? AppTheme.borderPrimary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.disabledGray
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Confirm & Record Transaction',
                      style: Theme.of(modalCtx).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify the details extracted from ${log.sender}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount badge
                    FintechCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIncome
                                    ? 'Incoming / Credit'
                                    : 'Outgoing / Debit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isIncome
                                      ? AppTheme.incomeGreen
                                      : AppTheme.expenseRed,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.formatCents(log.amountCents),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Confidence: ${log.confidence.toUpperCase()}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account selector
                    const Text(
                      'Assign to Account',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _accounts.any((a) => a.id == selectedAccountId)
                          ? selectedAccountId
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.inputCharcoal
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      items: _accounts.map((acc) {
                        return DropdownMenuItem(
                          value: acc.id,
                          child: Text('${acc.name} (${acc.currencyCode})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedAccountId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category selector
                    const Text(
                      'Category (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedCategoryId,
                      hint: const Text('Select a category'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.inputCharcoal
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Uncategorized'),
                        ),
                        ...relevantCategories.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setModalState(() => selectedCategoryId = val),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    const Text(
                      'Description / Purpose',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        hintText: 'What was this transaction for?',
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.inputCharcoal
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Remember rule
                    TextField(
                      controller: merchantController,
                      decoration: InputDecoration(
                        labelText: 'Remember category rule for this merchant (optional)',
                        hintText: 'e.g. TotalEnergies, Cafe, Supermarket',
                        filled: true,
                        fillColor: isDark
                            ? AppTheme.inputCharcoal
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppTheme.borderPrimary
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(modalCtx).pop(true),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Save to Transactions'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.deepNavy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final savedTx = await SmsParserService.instance.confirmPendingImport(
        log: log,
        accountId: selectedAccountId,
        categoryId: selectedCategoryId,
        customDescription: descController.text.trim().isNotEmpty
            ? descController.text.trim()
            : null,
        merchantToLearn: merchantController.text.trim().isNotEmpty
            ? merchantController.text.trim()
            : null,
      );

      if (savedTx != null && mounted) {
        context.read<TransactionsProvider>().loadTransactions();
        context.read<DashboardProvider>().loadDashboardData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text('Transaction successfully recorded!'),
          ),
        );
        _loadQueue();
      }
    }
  }

  Future<void> _ignoreItem(SmsImportLog log) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'sms_import_logs',
      {'status': SmsImportStatus.ignored.name},
      where: 'id = ?',
      whereArgs: [log.id],
    );
    _loadQueue();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message marked as ignored.')),
      );
    }
  }

  Future<void> _deleteItem(SmsImportLog log) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sms_import_logs', where: 'id = ?', whereArgs: [log.id]);
    _loadQueue();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Review Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadQueue,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingLogs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 54,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All Caught Up!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No bank SMS alerts currently pending confirmation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingLogs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final log = _pendingLogs[index];
                final isIncome =
                    log.transactionType.contains('incoming') ||
                    log.transactionType.contains('deposit');

                return FintechCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (isIncome
                                              ? AppTheme.incomeGreen
                                              : AppTheme.expenseRed)
                                          .withOpacity(isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  size: 18,
                                  color: isIncome
                                      ? AppTheme.incomeGreen
                                      : AppTheme.expenseRed,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.sender,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy • hh:mm a')
                                        .format(log.createdAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.formatCents(log.amountCents),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isIncome
                                  ? AppTheme.incomeGreen
                                  : AppTheme.expenseRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reason for review
                      if (log.reviewReason != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: AppTheme.accentAmber,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log.reviewReason!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentAmber,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Raw message preview
                      Text(
                        log.rawPreview,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action Buttons
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => _ignoreItem(log),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Ignore'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            onPressed: () => _deleteItem(log),
                            tooltip: 'Delete Log',
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () => _confirmItem(log),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Confirm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: AppTheme.deepNavy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
