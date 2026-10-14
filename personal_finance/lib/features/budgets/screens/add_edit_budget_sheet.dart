import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/features/budgets/models/budget.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/categories/models/category.dart';

/// Modal bottom sheet for creating or editing category, overall, or custom-period budgets
class AddEditBudgetSheet extends StatefulWidget {
  final Budget? budgetToEdit;
  final String? initialName;
  final String? initialCategoryName;
  final int? initialAmount;
  final BudgetFrequency? initialFrequency;

  const AddEditBudgetSheet({
    super.key,
    this.budgetToEdit,
    this.initialName,
    this.initialCategoryName,
    this.initialAmount,
    this.initialFrequency,
  });

  static Future<void> show(
    BuildContext context, {
    Budget? budgetToEdit,
    String? initialName,
    String? initialCategoryName,
    int? initialAmount,
    BudgetFrequency? initialFrequency,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditBudgetSheet(
        budgetToEdit: budgetToEdit,
        initialName: initialName,
        initialCategoryName: initialCategoryName,
        initialAmount: initialAmount,
        initialFrequency: initialFrequency,
      ),
    );
  }

  @override
  State<AddEditBudgetSheet> createState() => _AddEditBudgetSheetState();
}

class _AddEditBudgetSheetState extends State<AddEditBudgetSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late BudgetType _budgetType;
  late BudgetFrequency _frequency;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  late DateTime _startDate;
  late DateTime _endDate;
  double _warningThreshold = 0.8;

  bool _isSubmitting = false;
  bool get _isEditing => widget.budgetToEdit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.budgetToEdit;

    _budgetType = edit?.budgetType ?? BudgetType.category;
    _frequency = edit?.frequency ?? widget.initialFrequency ?? BudgetFrequency.monthly;
    _selectedCategoryId = edit?.categoryId;
    _selectedAccountId = edit?.accountId;
    _warningThreshold = edit?.warningThreshold ?? 0.8;

    _nameController = TextEditingController(text: edit?.name ?? widget.initialName ?? '');
    _amountController = TextEditingController(
      text: edit != null
          ? (edit.amount / 100).toStringAsFixed(0)
          : (widget.initialAmount != null
              ? (widget.initialAmount! / 100).toStringAsFixed(0)
              : ''),
    );
    _notesController = TextEditingController(text: edit?.notes ?? '');

    final now = DateTime.now();
    _startDate = edit?.periodStart.toLocal() ?? DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    _endDate = edit?.periodEnd.toLocal() ?? nextMonth.subtract(const Duration(milliseconds: 1));

    // Auto-select template category or first expense category if category budget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = context.read<BudgetsProvider>().categories;
      final List<Category> expenseCats =
          categories.where((Category c) => c.transactionType == 'expense').toList();
      if (_budgetType == BudgetType.category && _selectedCategoryId == null && expenseCats.isNotEmpty) {
        setState(() {
          if (widget.initialCategoryName != null) {
            final matched = expenseCats.where((c) =>
                c.name.toLowerCase().contains(widget.initialCategoryName!.toLowerCase()));
            _selectedCategoryId = matched.isNotEmpty ? matched.first.id : expenseCats.first.id;
          } else {
            _selectedCategoryId = expenseCats.first.id;
          }
          if (_nameController.text.trim().isEmpty) {
            final selected = expenseCats.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => expenseCats.first);
            _nameController.text = '${selected.name} Budget';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFrequencyChanged(BudgetFrequency freq) {
    setState(() {
      _frequency = freq;
      final now = DateTime.now();
      switch (freq) {
        case BudgetFrequency.weekly:
          final weekday = now.weekday;
          _startDate = DateTime(now.year, now.month, now.day - (weekday - 1));
          _endDate = DateTime(_startDate.year, _startDate.month, _startDate.day + 6, 23, 59, 59, 999);
          break;
        case BudgetFrequency.monthly:
          _startDate = DateTime(now.year, now.month, 1);
          final nextM = now.month == 12 ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
          _endDate = nextM.subtract(const Duration(milliseconds: 1));
          break;
        case BudgetFrequency.yearly:
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
          break;
        case BudgetFrequency.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999);
        _frequency = BudgetFrequency.custom;
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (_budgetType == BudgetType.category && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense category for this budget.')),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be earlier than start date.')),
      );
      return;
    }

    final double entered = double.tryParse(_amountController.text.trim()) ?? 0;
    final int amountCents = (entered * 100).round();

    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Budget limit must be greater than zero.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      const uuid = Uuid();
      final now = DateTime.now();

      final budgetId = _isEditing ? widget.budgetToEdit!.id : uuid.v4();
      final createdAt = _isEditing ? widget.budgetToEdit!.createdAt : now;

      final budget = Budget(
        id: budgetId,
        name: _nameController.text.trim().isEmpty ? 'Budget' : _nameController.text.trim(),
        budgetType: _budgetType,
        categoryId: _budgetType == BudgetType.category ? _selectedCategoryId : null,
        amount: amountCents,
        periodStart: _startDate,
        periodEnd: _endDate,
        frequency: _frequency,
        accountId: _selectedAccountId,
        warningThreshold: _warningThreshold,
        isArchived: false,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: createdAt,
        updatedAt: now,
      );

      final success = await context.read<BudgetsProvider>().saveBudget(budget, isEditing: _isEditing);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(_isEditing ? 'Budget updated successfully!' : 'Budget created successfully!'),
                ],
              ),
            ),
          );
        } else {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save budget.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<BudgetsProvider>();
    final mediaQuery = MediaQuery.of(context);

    final List<Category> expenseCategories =
        provider.categories.where((Category c) => c.transactionType == 'expense').toList();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Budget' : 'New Spending Budget',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Budget Type Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _buildTypeTab('Category', BudgetType.category, isDark),
                          _buildTypeTab('Overall', BudgetType.overall, isDark),
                          _buildTypeTab('Custom', BudgetType.customPeriod, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Budget Limit Amount
                    Text(
                      'Budget Limit (ETB)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: !_isEditing,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text('ብር', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        hintText: '0.00',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter budget amount';
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) return 'Must be greater than zero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Budget Name
                    Text(
                      'Budget Name',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Monthly Groceries, Dining Out',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Category Selection (for Category Budgets)
                    if (_budgetType == BudgetType.category) ...[
                      Text(
                        'Expense Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: expenseCategories.map((Category c) {
                          return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCategoryId = val;
                            if (val != null) {
                              final match = expenseCategories.firstWhere((c) => c.id == val);
                              if (_nameController.text.trim().isEmpty ||
                                  expenseCategories.any((c) => '${c.name} Budget' == _nameController.text.trim())) {
                                _nameController.text = '${match.name} Budget';
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Frequency & Period
                    Text(
                      'Frequency & Recurring Period',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildFreqChip('Monthly', BudgetFrequency.monthly, isDark),
                        const SizedBox(width: 8),
                        _buildFreqChip('Weekly', BudgetFrequency.weekly, isDark),
                        const SizedBox(width: 8),
                        _buildFreqChip('Yearly', BudgetFrequency.yearly, isDark),
                        const SizedBox(width: 8),
                        _buildFreqChip('Custom', BudgetFrequency.custom, isDark, onTapOverride: _pickCustomDates),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Active Range Details
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (_frequency == BudgetFrequency.custom)
                            TextButton(
                              onPressed: _pickCustomDates,
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                              child: const Text('Change'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Warning Alert Threshold Slider
                    Text(
                      'Warning Alert Threshold (${(_warningThreshold * 100).toInt()}%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    Slider(
                      value: _warningThreshold,
                      min: 0.5,
                      max: 1.0,
                      divisions: 5,
                      activeColor: AppTheme.primaryGreen,
                      label: '${(_warningThreshold * 100).toInt()}%',
                      onChanged: (val) => setState(() => _warningThreshold = val),
                    ),
                    const SizedBox(height: 12),

                    // Notes (Optional)
                    Text(
                      'Notes & Strategy (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'e.g. Keep groceries within limit this month'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? AppTheme.primaryGreen : AppTheme.primaryNavy,
                  foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Update Budget' : 'Save Budget',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(String label, BudgetType type, bool isDark) {
    final isSelected = _budgetType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _budgetType = type;
            if (type == BudgetType.customPeriod) {
              _frequency = BudgetFrequency.custom;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppTheme.primaryNavy)
                    : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFreqChip(String label, BudgetFrequency freq, bool isDark, {VoidCallback? onTapOverride}) {
    final isSelected = _frequency == freq;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (onTapOverride != null) {
            onTapOverride();
          } else {
            _onFrequencyChanged(freq);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryGreen.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryGreen
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryGreen
                    : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
