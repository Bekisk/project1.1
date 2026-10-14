import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/formatting/currency_formatter.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/savings_goals/models/goal_contribution.dart';
import 'package:personal_finance/features/savings_goals/models/savings_goal.dart';
import 'package:personal_finance/features/savings_goals/providers/savings_goals_provider.dart';
import 'package:personal_finance/features/savings_goals/services/savings_calculation_service.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';
import 'package:provider/provider.dart';

class AddContributionSheet extends StatefulWidget {
  final SavingsGoal goal;
  final GoalContribution? contributionToEdit;

  const AddContributionSheet({
    super.key,
    required this.goal,
    this.contributionToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    required SavingsGoal goal,
    GoalContribution? contributionToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddContributionSheet(
        goal: goal,
        contributionToEdit: contributionToEdit,
      ),
    );
  }

  @override
  State<AddContributionSheet> createState() => _AddContributionSheetState();
}

class _AddContributionSheetState extends State<AddContributionSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  late ContributionMode _selectedMode;
  String? _selectedSourceAccountId;
  String? _selectedDestinationAccountId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.contributionToEdit;
    _amountController = TextEditingController(
      text: edit != null ? (edit.amount / 100.0).toStringAsFixed(2) : '',
    );
    _notesController = TextEditingController(text: edit?.notes ?? '');
    _selectedDate = edit?.contributionDate ?? DateTime.now();
    _selectedMode = edit?.mode ?? ContributionMode.manual;
    _selectedSourceAccountId = edit?.sourceAccountId;
    _selectedDestinationAccountId = edit?.destinationAccountId ?? widget.goal.linkedAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitContribution() async {
    if (_isSaving) return; // Prevent duplicate taps
    if (!_formKey.currentState!.validate()) return;

    final parsed = double.tryParse(_amountController.text.trim()) ?? 0;
    final amountCents = (parsed * 100).round();
    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution amount must be greater than zero')),
      );
      return;
    }

    if (_selectedMode == ContributionMode.accountTransfer) {
      if (_selectedSourceAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a source account')),
        );
        return;
      }
      if (_selectedDestinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a destination savings account')),
        );
        return;
      }
      if (_selectedSourceAccountId == _selectedDestinationAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source and destination accounts must be different')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final goalsProvider = context.read<SavingsGoalsProvider>();

    try {
      final isEdit = widget.contributionToEdit != null;
      if (isEdit) {
        final success = await goalsProvider.editContribution(
          contribution: widget.contributionToEdit!,
          newAmount: amountCents,
          newDate: _selectedDate,
          newNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (mounted) {
          if (success) {
            context.read<DashboardProvider>().loadDashboardData();
            context.read<TransactionsProvider>().loadTransactions();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contribution updated successfully!'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          } else {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update contribution')),
            );
          }
        }
      } else {
        // New contribution
        final existingContribs = goalsProvider.getContributionsForGoal(widget.goal.id);
        final priorSaved = SavingsCalculationService.calculateTotalSaved(existingContribs);
        final newTotal = priorSaved + amountCents;
        final willComplete = newTotal >= widget.goal.targetAmount && priorSaved < widget.goal.targetAmount;

        final res = await goalsProvider.addContribution(
          goalId: widget.goal.id,
          amount: amountCents,
          contributionDate: _selectedDate,
          mode: _selectedMode,
          sourceAccountId: _selectedSourceAccountId,
          destinationAccountId: _selectedDestinationAccountId,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

        if (mounted) {
          if (res != null) {
            context.read<DashboardProvider>().loadDashboardData();
            context.read<TransactionsProvider>().loadTransactions();
            Navigator.pop(context);

            if (willComplete) {
              _showCelebrationDialog(context, newTotal);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Added ${CurrencyFormatter.formatCents(amountCents)} to ${widget.goal.name}!',
                  ),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
            }
          } else {
            setState(() => _isSaving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save contribution')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCelebrationDialog(BuildContext context, int totalSaved) {
    final theme = Theme.of(context);
    final excess = totalSaved - widget.goal.targetAmount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: AppTheme.accentAmber, size: 28),
            SizedBox(width: 8),
            Text('Goal Reached! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Congratulations! You have reached your target for "${widget.goal.name}".',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Total Saved: ${CurrencyFormatter.formatCents(totalSaved)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (excess > 0)
              Text(
                'Over-target surplus: ${CurrencyFormatter.formatCents(excess)}',
                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<SavingsGoalsProvider>();
    final accounts = provider.accounts;

    final summary = provider.getSummaryForGoal(widget.goal);
    final isEdit = widget.contributionToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Contribution' : 'Add Contribution',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          widget.goal.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Goal progress preview banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Saved', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          CurrencyFormatter.formatCents(summary.totalSaved),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text('Target', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          CurrencyFormatter.formatCents(summary.targetAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Remaining', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          CurrencyFormatter.formatCents(summary.remainingAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.accentCoral,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount input
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Contribution Amount (ETB) *',
                  hintText: '500.00',
                  prefixIcon: const Icon(Icons.attach_money_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter contribution amount';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Must be greater than zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Mode selector (Only for new contribution)
              if (!isEdit) ...[
                Text('Contribution Accounting Method', style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<ContributionMode>(
                  segments: const [
                    ButtonSegment(
                      value: ContributionMode.manual,
                      label: Text('Manual Earmark'),
                      icon: Icon(Icons.bookmark_added_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ContributionMode.accountTransfer,
                      label: Text('Account Transfer'),
                      icon: Icon(Icons.swap_horiz_rounded, size: 16),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (set) => setState(() => _selectedMode = set.first),
                ),
                const SizedBox(height: 6),
                Text(
                  _selectedMode == ContributionMode.manual
                      ? '• Merely records savings progress without debiting any account balances.'
                      : '• Moves real money between accounts via an internal transfer. Does NOT create an expense.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 14),

                // Account Transfer fields
                if (_selectedMode == ContributionMode.accountTransfer) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSourceAccountId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Source Account (Debited)',
                      prefixIcon: const Icon(Icons.account_balance_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Text('${acc.name} (${acc.currencyCode})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedSourceAccountId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDestinationAccountId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Destination Account (Credited)',
                      prefixIcon: const Icon(Icons.savings_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Text('${acc.name} (${acc.currencyCode})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDestinationAccountId = val),
                  ),
                  const SizedBox(height: 14),
                ],
              ],

              // Contribution Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text('Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change'),
                ),
                onTap: _pickDate,
              ),
              const Divider(),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  hintText: 'e.g. Monthly salary savings allocation',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submitContribution,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                    foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isEdit ? 'Update Contribution' : 'Add Contribution',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
