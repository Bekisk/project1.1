import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/debts/models/debt.dart';
import 'package:personal_finance/features/debts/providers/debts_provider.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';

class SettleDebtDialog extends StatefulWidget {
  final Debt debt;
  final List<Account> accounts;

  const SettleDebtDialog({
    super.key,
    required this.debt,
    required this.accounts,
  });

  static Future<void> show(
    BuildContext context, {
    required Debt debt,
    required List<Account> accounts,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => SettleDebtDialog(
        debt: debt,
        accounts: accounts,
      ),
    );
  }

  @override
  State<SettleDebtDialog> createState() => _SettleDebtDialogState();
}

class _SettleDebtDialogState extends State<SettleDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  String? _selectedWalletId;
  DateTime _settlementDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: (widget.debt.remainingAmount / 100.0).toStringAsFixed(2),
    );
    _noteCtrl = TextEditingController(
      text: widget.debt.type == DebtType.owesMe
          ? 'Settlement received from ${widget.debt.personName}'
          : 'Settlement paid to ${widget.debt.personName}',
    );
    _selectedWalletId = widget.debt.linkedWalletId ?? (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReceiving = widget.debt.type == DebtType.owesMe;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (isReceiving ? AppTheme.primaryGreen : AppTheme.expenseRed).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isReceiving ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isReceiving ? AppTheme.primaryGreen : AppTheme.expenseRed,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isReceiving ? 'Record Repayment' : 'Pay Off Debt',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Debt overview card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.debt.personName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          isReceiving ? 'Owes You' : 'You Owe',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isReceiving ? AppTheme.primaryGreen : AppTheme.expenseRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remaining Balance: ${CurrencyFormatter.formatCents(widget.debt.remainingAmount)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Repayment Amount
              Text(
                'Settlement Amount (ETB)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter a valid amount';
                  if ((parsed * 100).round() > widget.debt.remainingAmount) {
                    return 'Cannot settle more than remaining amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Target Account / Wallet to balance Net Worth
              Text(
                'Target Account / Wallet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: widget.accounts.map((a) {
                  return DropdownMenuItem(value: a.id, child: Text(a.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWalletId = val);
                },
              ),
              const SizedBox(height: 6),
              Text(
                isReceiving
                    ? 'Will automatically record an Income entry into this wallet.'
                    : 'Will automatically record an Expense entry from this wallet.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 14),

              // Settlement Date
              Text(
                'Settlement Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _settlementDate,
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _settlementDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(_settlementDate),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReceiving ? AppTheme.primaryGreen : AppTheme.expenseRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _settle,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          isReceiving ? 'Confirm & Receive Funds' : 'Confirm & Settle Payment',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _settle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final settleCents = (double.parse(_amountCtrl.text.trim()) * 100).round();
      final success = await context.read<DebtsProvider>().settleDebt(
            debt: widget.debt,
            settleAmountCents: settleCents,
            walletId: _selectedWalletId,
            settlementDate: _settlementDate,
            note: _noteCtrl.text.trim(),
          );

      if (success && mounted) {
        // Refresh transactions and dashboard providers
        context.read<TransactionsProvider>().loadTransactions();
        context.read<DashboardProvider>().loadDashboardData();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text(
              'Settled ${CurrencyFormatter.formatCents(settleCents)}! Linked wallet updated.',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error settling debt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
