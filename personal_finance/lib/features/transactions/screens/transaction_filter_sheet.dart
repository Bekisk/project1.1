import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';

/// Modal sheet for multi-dimensional filtering: Transaction Type, Date Presets & Custom Dates,
/// Account, Category, and Amount Range with AND/OR logic.
class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const TransactionFilterSheet(),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TransactionType? _selectedType;
  late DateRangePreset _datePreset;
  late DateTime? _customStart;
  late DateTime? _customEnd;
  late String? _selectedAccountId;
  late String? _selectedCategoryId;
  late final TextEditingController _minAmountController;
  late final TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    final current = context.read<TransactionsProvider>().filter;
    _selectedType = current.type;
    _datePreset = current.datePreset;
    _customStart = current.customStartDate;
    _customEnd = current.customEndDate;
    _selectedAccountId = current.accountId;
    _selectedCategoryId = current.categoryId;

    _minAmountController = TextEditingController(
      text: current.minAmountCents != null
          ? (current.minAmountCents! / 100).toStringAsFixed(0)
          : '',
    );
    _maxAmountController = TextEditingController(
      text: current.maxAmountCents != null
          ? (current.maxAmountCents! / 100).toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
    );

    if (picked != null) {
      setState(() {
        _datePreset = DateRangePreset.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
  }

  void _applyFilters() {
    final minVal = double.tryParse(_minAmountController.text.trim());
    final maxVal = double.tryParse(_maxAmountController.text.trim());

    final minCents = minVal != null && minVal > 0
        ? (minVal * 100).round()
        : null;
    final maxCents = maxVal != null && maxVal > 0
        ? (maxVal * 100).round()
        : null;

    if (minCents != null && maxCents != null && minCents > maxCents) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum amount cannot exceed maximum amount.'),
        ),
      );
      return;
    }

    final current = context.read<TransactionsProvider>().filter;
    final updated = current.copyWith(
      type: _selectedType,
      clearType: _selectedType == null,
      datePreset: _datePreset,
      customStartDate: _customStart,
      customEndDate: _customEnd,
      clearCustomDates: _datePreset != DateRangePreset.custom,
      accountId: _selectedAccountId,
      clearAccountId: _selectedAccountId == null,
      categoryId: _selectedCategoryId,
      clearCategoryId: _selectedCategoryId == null,
      minAmountCents: minCents,
      clearMinAmount: minCents == null,
      maxAmountCents: maxCents,
      clearMaxAmount: maxCents == null,
    );

    context.read<TransactionsProvider>().setFilter(updated);
    Navigator.of(context).pop();
  }

  void _resetFilters() {
    context.read<TransactionsProvider>().resetFilters();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<TransactionsProvider>();
    final mediaQuery = MediaQuery.of(context);

    final matchingCategories = _selectedType == null
        ? provider.categories
        : provider.categories.where((c) {
            if (_selectedType == TransactionType.income)
              return c.transactionType == 'income';
            if (_selectedType == TransactionType.expense)
              return c.transactionType == 'expense';
            return false;
          }).toList();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardCharcoal : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.borderPrimary : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.disabledGray : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Transactions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scrollable Filter Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Transaction Type
                  _buildSectionTitle(context, 'Transaction Type', isDark),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: 'All Types',
                        isSelected: _selectedType == null,
                        onSelected: () => setState(() => _selectedType = null),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Expense',
                        isSelected: _selectedType == TransactionType.expense,
                        onSelected: () => setState(
                          () => _selectedType = TransactionType.expense,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Income',
                        isSelected: _selectedType == TransactionType.income,
                        onSelected: () => setState(
                          () => _selectedType = TransactionType.income,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Transfer',
                        isSelected: _selectedType == TransactionType.transfer,
                        onSelected: () => setState(
                          () => _selectedType = TransactionType.transfer,
                        ),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Date Range
                  _buildSectionTitle(context, 'Date Range', isDark),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: 'This Month',
                        isSelected: _datePreset == DateRangePreset.thisMonth,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.thisMonth,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Today',
                        isSelected: _datePreset == DateRangePreset.today,
                        onSelected: () =>
                            setState(() => _datePreset = DateRangePreset.today),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Yesterday',
                        isSelected: _datePreset == DateRangePreset.yesterday,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.yesterday,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'This Week',
                        isSelected: _datePreset == DateRangePreset.thisWeek,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.thisWeek,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Last Month',
                        isSelected: _datePreset == DateRangePreset.lastMonth,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.lastMonth,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'Last 30 Days',
                        isSelected: _datePreset == DateRangePreset.last30Days,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.last30Days,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label: 'All Time',
                        isSelected: _datePreset == DateRangePreset.allTime,
                        onSelected: () => setState(
                          () => _datePreset = DateRangePreset.allTime,
                        ),
                        isDark: isDark,
                      ),
                      _buildChoiceChip(
                        label:
                            _datePreset == DateRangePreset.custom &&
                                _customStart != null &&
                                _customEnd != null
                            ? '${DateFormat('MM/dd').format(_customStart!)} - ${DateFormat('MM/dd').format(_customEnd!)}'
                            : 'Custom Range...',
                        isSelected: _datePreset == DateRangePreset.custom,
                        onSelected: _pickCustomRange,
                        isDark: isDark,
                        icon: Icons.calendar_month_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Account Filter
                  _buildSectionTitle(
                    context,
                    'Account (Source or Destination)',
                    isDark,
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Accounts'),
                      ),
                      ...provider.accounts.map(
                        (acc) => DropdownMenuItem(
                          value: acc.id,
                          child: Text(acc.name),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedAccountId = val),
                  ),
                  const SizedBox(height: 18),

                  // 4. Category Filter (Disabled for transfers)
                  if (_selectedType != TransactionType.transfer) ...[
                    _buildSectionTitle(context, 'Category', isDark),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...matchingCategories.map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 5. Amount Range
                  _buildSectionTitle(context, 'Amount Range (ETB)', isDark),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Min Amount',
                            prefixText: 'ብር ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxAmountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Max Amount',
                            prefixText: 'ብር ',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _applyFilters,
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? AppTheme.primaryGreen
                    : AppTheme.primaryNavy,
                foregroundColor: isDark ? AppTheme.deepNavy : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Apply Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark
              ? AppTheme.textSecondaryDark
              : AppTheme.textSecondaryLight,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
    IconData? icon,
  }) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.primaryGreen,
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: isDark ? AppTheme.pureWhite : AppTheme.primaryNavy,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (isDark ? AppTheme.pureBlack : Colors.white)
            : (isDark ? AppTheme.secondaryGray : AppTheme.textSecondaryLight),
      ),
      backgroundColor: isDark ? AppTheme.cardCharcoal : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(
        color: isDark
            ? (isSelected ? Colors.transparent : AppTheme.borderPrimary)
            : Colors.transparent,
      ),
    );
  }
}
