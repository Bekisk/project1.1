import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/debts/models/debt.dart';
import 'package:personal_finance/features/debts/providers/debts_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddEditDebtDialog extends StatefulWidget {
  final Debt? debtToEdit;
  final List<Account> accounts;

  const AddEditDebtDialog({super.key, this.debtToEdit, required this.accounts});

  static Future<void> show(
    BuildContext context, {
    Debt? debtToEdit,
    required List<Account> accounts,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) =>
          AddEditDebtDialog(debtToEdit: debtToEdit, accounts: accounts),
    );
  }

  @override
  State<AddEditDebtDialog> createState() => _AddEditDebtDialogState();
}

class _AddEditDebtDialogState extends State<AddEditDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _personCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _notesCtrl;
  late DebtType _type;
  DateTime? _dueDate;
  String? _selectedWalletId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.debtToEdit;
    _personCtrl = TextEditingController(text: d?.personName ?? '');
    _amountCtrl = TextEditingController(
      text: d != null ? (d.totalAmount / 100.0).toStringAsFixed(2) : '',
    );
    _notesCtrl = TextEditingController(text: d?.notes ?? '');
    _type = d?.type ?? DebtType.owesMe;
    _dueDate = d?.dueDate;
    _selectedWalletId =
        d?.linkedWalletId ??
        (widget.accounts.isNotEmpty ? widget.accounts.first.id : null);
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  Text(
                    widget.debtToEdit == null ? 'New Debt / IOU' : 'Edit Debt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Type Selector: Lent (OWES_ME) vs Borrowed (I_OWE)
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('They Owe Me (Lent)')),
                      selected: _type == DebtType.owesMe,
                      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                      side: BorderSide(
                        color: _type == DebtType.owesMe
                            ? AppTheme.primaryGreen
                            : Colors.transparent,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = DebtType.owesMe);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('I Owe (Borrowed)')),
                      selected: _type == DebtType.iOwe,
                      selectedColor: AppTheme.expenseRed.withOpacity(0.2),
                      side: BorderSide(
                        color: _type == DebtType.iOwe
                            ? AppTheme.expenseRed
                            : Colors.transparent,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = DebtType.iOwe);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Person Name
              Text(
                'Person Name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _personCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Dawit, Bethlehem, Abebe',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Enter person name'
                    : null,
              ),
              const SizedBox(height: 14),

              // Amount
              Text(
                'Total Amount (ETB)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputTextInputTypeDouble(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                validator: (val) {
                  final parsed = double.tryParse(val ?? '');
                  if (parsed == null || parsed <= 0)
                    return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Linked Wallet
              Text(
                'Linked Account / Wallet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedWalletId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: widget.accounts.map((a) {
                  return DropdownMenuItem(value: a.id, child: Text(a.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWalletId = val);
                },
              ),
              const SizedBox(height: 14),

              // Due Date Selector
              Text(
                'Due Date (Optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? now.add(const Duration(days: 14)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dueDate != null
                            ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                            : 'No Due Date Set',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveDebt,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.debtToEdit == null
                              ? 'Create IOU Record'
                              : 'Save Changes',
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

  Future<void> _saveDebt() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final totalCents = (double.parse(_amountCtrl.text.trim()) * 100).round();

      if (widget.debtToEdit == null) {
        final newDebt = Debt(
          id: const Uuid().v4(),
          personName: _personCtrl.text.trim(),
          type: _type,
          totalAmount: totalCents,
          settledAmount: 0,
          dueDate: _dueDate,
          startDate: now,
          linkedWalletId: _selectedWalletId,
          status: DebtStatus.unpaid,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await context.read<DebtsProvider>().addDebt(newDebt);
      } else {
        final updated = widget.debtToEdit!.copyWith(
          personName: _personCtrl.text.trim(),
          type: _type,
          totalAmount: totalCents,
          dueDate: _dueDate,
          linkedWalletId: _selectedWalletId,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          updatedAt: now,
        );
        await context.read<DebtsProvider>().updateDebt(updated);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Text(
              'Debt record saved successfully',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving debt: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class TextInputTextInputTypeDouble extends TextInputType {
  const TextInputTextInputTypeDouble({super.signed, super.decimal})
    : super.numberWithOptions();
}
