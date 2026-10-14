import 'package:flutter/material.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/parsed_sms_transaction.dart';

class SmsQuickConfirmSheet extends StatefulWidget {
  final ParsedSmsTransaction parsedSms;
  final VoidCallback? onConfirmed;

  const SmsQuickConfirmSheet({
    super.key,
    required this.parsedSms,
    this.onConfirmed,
  });

  static Future<void> show(
    BuildContext context, {
    required ParsedSmsTransaction parsedSms,
    VoidCallback? onConfirmed,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmsQuickConfirmSheet(
        parsedSms: parsedSms,
        onConfirmed: onConfirmed,
      ),
    );
  }

  @override
  State<SmsQuickConfirmSheet> createState() => _SmsQuickConfirmSheetState();
}

class _SmsQuickConfirmSheetState extends State<SmsQuickConfirmSheet> {
  late TextEditingController _descController;
  late TextEditingController _amountController;
  String? _selectedAccountId;
  String? _selectedCategoryId;
  late TransactionType _type;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(
      text: widget.parsedSms.buildFactualDescription(),
    );
    _amountController = TextEditingController(
      text: widget.parsedSms.amountInEtb.toStringAsFixed(2),
    );
    _type = widget.parsedSms.isMoneyIn
        ? TransactionType.income
        : TransactionType.expense;
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final txProvider = context.watch<TransactionsProvider>();
    final accounts = txProvider.accounts;
    final categories = txProvider.categories.where((c) {
      if (_type == TransactionType.expense) {
        return c.transactionType == 'expense';
      } else {
        return c.transactionType == 'income';
      }
    }).toList();

    // Default select first account if not set
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      // Try to match by account name or provider
      final providerName = widget.parsedSms.provider == EthiopianBankProvider.cbe
          ? 'cbe'
          : widget.parsedSms.provider == EthiopianBankProvider.telebirr
              ? 'telebirr'
              : widget.parsedSms.provider == EthiopianBankProvider.awash
                  ? 'awash'
                  : '';
      final matched = accounts.firstWhere(
        (a) => a.name.toLowerCase().contains(providerName) || a.accountType.toLowerCase().contains(providerName),
        orElse: () => accounts.first,
      );
      _selectedAccountId = matched.id;
    }

    // Default select first category if not set
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Provider Badge & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sms_rounded, size: 16, color: AppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      widget.parsedSms.providerDisplayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Detected ${_type == TransactionType.expense ? "Expense" : "Income"}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Confirm details to record automatically into your ledger.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 18),

          // Amount Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardCharcoal : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.borderPrimary : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _type == TransactionType.expense
                      ? AppTheme.expenseRed.withOpacity(0.2)
                      : AppTheme.incomeGreen.withOpacity(0.2),
                  child: Icon(
                    _type == TransactionType.expense ? Icons.arrow_upward : Icons.arrow_downward,
                    color: _type == TransactionType.expense ? AppTheme.expenseRed : AppTheme.incomeGreen,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount (ETB)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(widget.parsedSms.amountCents),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _type == TransactionType.expense ? AppTheme.expenseRed : AppTheme.incomeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Description input
          Text(
            'Description / Merchant',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Account Selector
          Text(
            'Target Account / Wallet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            dropdownColor: isDark ? AppTheme.elevatedCharcoal : Colors.white,
            items: accounts.map((a) {
              return DropdownMenuItem(
                value: a.id,
                child: Text(a.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedAccountId = val);
            },
          ),
          const SizedBox(height: 14),

          // Category Selector
          Text(
            'Category',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCategoryId,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            dropdownColor: isDark ? AppTheme.elevatedCharcoal : Colors.white,
            items: categories.map((c) {
              return DropdownMenuItem(
                value: c.id,
                child: Text(c.name),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCategoryId = val);
            },
          ),
          const SizedBox(height: 22),

          // Confirm Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleRoundedCorners(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _confirmAndSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text(
                      'Confirm & Log Transaction',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _confirmAndSave() async {
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final tx = FinancialTransaction(
        id: const Uuid().v4(),
        accountId: _selectedAccountId!,
        destinationAccountId: null,
        type: _type,
        amount: widget.parsedSms.amountCents,
        categoryId: _selectedCategoryId,
        description: _descController.text.trim().isEmpty
            ? (widget.parsedSms.partyOrMerchant ?? 'Bank Transaction')
            : _descController.text.trim(),
        notes: 'Auto-parsed from ${widget.parsedSms.providerDisplayName}. Ref: ${widget.parsedSms.referenceNumber ?? "N/A"}',
        transactionDate: widget.parsedSms.transactionDate ?? now,
        createdAt: now,
        updatedAt: now,
      );

      final success = await context.read<TransactionsProvider>().insertTransaction(tx);
      if (success && mounted) {
        context.read<DashboardProvider>().loadDashboardData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text(
              'Successfully logged ${CurrencyFormatter.formatCents(tx.amount)} via SMS!',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
        widget.onConfirmed?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class RoundedRectangleRoundedCorners extends RoundedRectangleBorder {
  const RoundedRectangleRoundedCorners({super.borderRadius});
}
