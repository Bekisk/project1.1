import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/core/database/database_helper.dart';
import 'package:personal_finance/core/widgets/category_icon_badge.dart';
import 'package:personal_finance/features/accounts/models/account.dart';
import 'package:personal_finance/features/categories/models/category.dart';
import 'package:personal_finance/features/budgets/providers/budgets_provider.dart';
import 'package:personal_finance/features/dashboard/providers/dashboard_provider.dart';
import 'package:personal_finance/features/profile/providers/user_profile_provider.dart';
import 'package:personal_finance/features/transactions/models/financial_transaction.dart';
import 'package:personal_finance/features/transactions/providers/transactions_provider.dart';

/// Premium modal sheet for adding and editing Income, Expense, or Transfer
class AddTransactionSheet extends StatefulWidget {
  final TransactionType initialType;
  final FinancialTransaction? transactionToEdit;

  const AddTransactionSheet({
    super.key,
    this.initialType = TransactionType.expense,
    this.transactionToEdit,
  });

  static Future<void> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.expense,
    FinancialTransaction? transactionToEdit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionSheet(
        initialType: transactionToEdit?.type ?? initialType,
        transactionToEdit: transactionToEdit,
      ),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _selectedType;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _selectedCategoryId;

  List<Account> _accounts = [];
  List<Category> _categories = [];
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    final editTx = widget.transactionToEdit;
    _selectedType = editTx?.type ?? widget.initialType;

    _amountController = TextEditingController(
      text: editTx != null ? (editTx.amount / 100).toStringAsFixed(2) : '',
    );
    _descriptionController = TextEditingController(text: editTx?.description ?? '');
    _notesController = TextEditingController(text: editTx?.notes ?? '');

    _selectedDate = editTx != null ? editTx.transactionDate.toLocal() : DateTime.now();
    if (editTx != null) {
      _selectedTime = TimeOfDay.fromDateTime(editTx.transactionDate.toLocal());
      _selectedAccountId = editTx.accountId;
      _selectedDestinationAccountId = editTx.destinationAccountId;
      _selectedCategoryId = editTx.categoryId;
    }

    _loadDependencies();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final accMaps = await db.query('accounts', where: 'is_archived = 0');
      final accounts = accMaps.map((e) => Account.fromMap(e)).toList();

      final catMaps = await db.query('categories', where: 'is_archived = 0');
      final categories = catMaps.map((e) => Category.fromMap(e)).toList();

      if (mounted) {
        setState(() {
          _accounts = accounts;
          _categories = categories;

          if (!_isEditing) {
            final mainAccId = context.read<UserProfileProvider>().mainAccountId;
            if (mainAccId != null && _accounts.any((a) => a.id == mainAccId)) {
              _selectedAccountId = mainAccId;
            } else if (_accounts.isNotEmpty && _selectedAccountId == null) {
              _selectedAccountId = _accounts.first.id;
            }

            if (_accounts.length > 1) {
              _selectedDestinationAccountId = _accounts.firstWhere((a) => a.id != _selectedAccountId).id;
            }
            _filterCategoriesForType();
          } else {
            // When editing, verify account exists in list
            if (_selectedAccountId == null && _accounts.isNotEmpty) {
              _selectedAccountId = _accounts.first.id;
            }
          }

          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _filterCategoriesForType() {
    final typeStr = _selectedType == TransactionType.income ? 'income' : 'expense';
    final matching = _categories.where((c) => c.transactionType == typeStr).toList();
    if (matching.isNotEmpty) {
      if (_selectedCategoryId == null || !matching.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = matching.first.id;
      }
    } else {
      _selectedCategoryId = null;
    }
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return; // Prevent duplicate submissions
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account.')),
      );
      return;
    }

    if (_selectedType == TransactionType.transfer) {
      if (_selectedDestinationAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a destination account for the transfer.')),
        );
        return;
      }
      if (_selectedAccountId == _selectedDestinationAccountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source and destination accounts must be different.')),
        );
        return;
      }
    }

    final double enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final int amountCents = (enteredAmount * 100).round();

    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = await DatabaseHelper.instance.database;
      const uuid = Uuid();
      final now = DateTime.now();

      final combinedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final transactionId = _isEditing ? widget.transactionToEdit!.id : uuid.v4();
      final createdAt = _isEditing ? widget.transactionToEdit!.createdAt : now;

      final updatedTx = FinancialTransaction(
        id: transactionId,
        accountId: _selectedAccountId!,
        destinationAccountId: _selectedType == TransactionType.transfer
            ? _selectedDestinationAccountId
            : null,
        type: _selectedType,
        amount: amountCents,
        categoryId: _selectedType == TransactionType.transfer ? null : _selectedCategoryId,
        description: _descriptionController.text.trim().isEmpty
            ? (_selectedType == TransactionType.transfer
                ? 'Account Transfer'
                : (_categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => _categories.first).name))
            : _descriptionController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        transactionDate: combinedDateTime,
        createdAt: createdAt,
        updatedAt: now,
      );

      if (_isEditing) {
        await db.update(
          'transactions',
          updatedTx.toMap(),
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      } else {
        await db.insert('transactions', updatedTx.toMap());
      }

      if (mounted) {
        // Refresh dashboard, transaction, and budget providers immediately
        context.read<DashboardProvider>().loadDashboardData();
        context.read<TransactionsProvider>().loadTransactions();
        context.read<BudgetsProvider>().loadBudgetData();

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
                Text(
                  _isEditing
                      ? '${_selectedType.name.toUpperCase()} updated successfully!'
                      : '${_selectedType.name.toUpperCase()} recorded successfully!',
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving transaction: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    final matchingCategories = _categories
        .where((c) => c.transactionType == (_selectedType == TransactionType.income ? 'income' : 'expense'))
        .toList();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardCharcoal : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppTheme.borderPrimary : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: _isLoadingData
          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.disabledGray : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEditing ? 'Edit Transaction' : 'New Transaction',
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

                    // Segmented Type Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.borderPrimary : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildTypeTab(
                            title: 'Expense',
                            type: TransactionType.expense,
                            activeColor: AppTheme.expenseRed,
                          ),
                          _buildTypeTab(
                            title: 'Income',
                            type: TransactionType.income,
                            activeColor: AppTheme.incomeGreen,
                          ),
                          _buildTypeTab(
                            title: 'Transfer',
                            type: TransactionType.transfer,
                            activeColor: AppTheme.transferBlue,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Amount Input
                    Text(
                      'Amount (ETB)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: !_isEditing,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            'ብር',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        hintText: '0.00',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter amount';
                        final num = double.tryParse(val.trim());
                        if (num == null || num <= 0) return 'Enter a valid amount';
                        return null;
                      },
                    ),
                    // Frequent Preset Chips
                    if (_selectedType != TransactionType.transfer) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Frequent Presets',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                          Text(
                            '1-tap auto-fill',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('Cafeteria Lunch', 'Food', isDark),
                            const SizedBox(width: 8),
                            _buildPresetChip('Taxi/Ride', 'Transport', isDark),
                            const SizedBox(width: 8),
                            _buildPresetChip('Groceries', 'Food', isDark),
                            const SizedBox(width: 8),
                            _buildPresetChip('Airtime Top-up', 'Bills', isDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Description / Title
                    Text(
                      'Description',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Cafeteria Lunch, Taxi/Ride, Groceries',
                        prefixIcon: Icon(Icons.edit_note_rounded),
                      ),
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Enter transaction description';
                        }
                        // Enforce minimum 3 alphanumeric characters
                        final alphanumericCount = RegExp(r'[a-zA-Z0-9\u1200-\u137F]').allMatches(trimmed).length;
                        if (alphanumericCount < 3) {
                          return 'Must contain at least 3 letters or numbers';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category Selector (if not transfer)
                    if (_selectedType != TransactionType.transfer) ...[
                      Text(
                        'Category',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: matchingCategories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (ctx, idx) {
                            final cat = matchingCategories[idx];
                            final isSelected = cat.id == _selectedCategoryId;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedCategoryId = cat.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppTheme.pureWhite.withValues(alpha: 0.15) : AppTheme.primaryGreen.withValues(alpha: 0.15))
                                      : (isDark ? AppTheme.elevatedCharcoal : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? AppTheme.pureWhite : AppTheme.primaryGreen)
                                        : (isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CategoryIconBadge(
                                      iconKey: cat.iconKey,
                                      colorKey: cat.colorKey,
                                      size: 32,
                                      iconSize: 16,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cat.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? Colors.white : AppTheme.primaryNavy)
                                            : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Account Selection & Date in a 2-Column Row
                    Row(
                      children: [
                        // Account
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedType == TransactionType.transfer ? 'From Account' : 'Account',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedAccountId,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: _accounts.map((acc) {
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Text(
                                      acc.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedAccountId = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date Picker Button
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_selectedType == TransactionType.transfer) ...[
                      const SizedBox(height: 14),
                      Text(
                        'To Destination Account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDestinationAccountId,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _accounts.map((acc) {
                          return DropdownMenuItem(
                            value: acc.id,
                            child: Text(
                              acc.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedDestinationAccountId = val),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Time Picker & Notes
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.inputCharcoal : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark ? AppTheme.borderPrimary : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        _selectedTime.format(context),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    Text(
                      'Notes (Optional)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Additional details or merchant note...',
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == TransactionType.expense
                              ? AppTheme.primaryNavy
                              : AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                                    _isEditing
                                        ? 'Update ${_selectedType.name.toUpperCase()}'
                                        : 'Save ${_selectedType.name.toUpperCase()}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeTab({
    required String title,
    required TransactionType type,
    required Color activeColor,
  }) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _filterCategoriesForType();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppTheme.elevatedCharcoal : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected && isDark
                ? Border.all(color: AppTheme.borderPrimary, width: 1)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDark ? AppTheme.secondaryGray : AppTheme.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String title, String categoryHint, bool isDark) {
    return ActionChip(
      onPressed: () {
        setState(() {
          _descriptionController.text = title;
          if (_categories.isNotEmpty) {
            final match = _categories.where((c) =>
                c.transactionType == 'expense' &&
                c.name.toLowerCase().contains(categoryHint.toLowerCase()));
            if (match.isNotEmpty) {
              _selectedCategoryId = match.first.id;
            }
          }
        });
      },
      avatar: Icon(Icons.flash_on_rounded, size: 14, color: isDark ? AppTheme.pureWhite : AppTheme.primaryNavy),
      label: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.pureWhite : AppTheme.textDark,
        ),
      ),
      backgroundColor: isDark ? AppTheme.elevatedCharcoal : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark ? AppTheme.borderPrimary : const Color(0xFFCBD5E1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
